import AppKit
import KumquatCore
import PDFKit

/// `Kumquat --corpus <manifest.json> <files folder> <output folder> <results.jsonl>` converts every corpus file
/// to its targets through the same wheel operations people use, and logs one JSON line per conversion.
///
/// scripts/corpus-validate.py then checks each output with outside tools (ffprobe, SSIM/PSNR, qpdf, veraPDF,
/// LibreOffice). Results are appended as they happen, and a conversion that was started but never finished
/// is logged as a crash on the next run, so scripts/corpus.sh can restart after a crash and carry on.
enum CorpusRunner {
    struct Item: Decodable {
        let id: String
        let category: String
        var url: String?
        var expected: String?
        var targets: [String]?
    }

    static let timeout: TimeInterval = 240

    static func run(arguments: [String]) -> Never {
        guard arguments.count >= 4 else {
            print("usage: Kumquat --corpus <manifest.json> <files folder> <output folder> <results.jsonl>")
            exit(2)
        }
        let manifest = URL(fileURLWithPath: arguments[0])
        let files = URL(fileURLWithPath: arguments[1], isDirectory: true)
        let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
        let log = URL(fileURLWithPath: arguments[3])
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        var items: [Item] = []
        do {
            items = try JSONDecoder().decode([Item].self, from: Data(contentsOf: manifest))
        } catch {
            print("Couldn't read \(manifest.path): \(error)")
            exit(2)
        }
        items += Generated.make(in: files, from: items)

        let ffmpeg = ProcessInfo.processInfo.environment["KUMQUAT_FFMPEG"].map(URL.init(fileURLWithPath:)) ?? FFmpegEngine.locate()
        let context = OperationContext(outputDirectory: output, ffmpeg: ffmpeg)
        let journal = Journal(log)

        for item in items {
            guard let source = file(for: item, in: files) else {
                journal.write(["id": item.id, "category": item.category, "status": "missing", "expected": item.expected ?? "convert"])
                continue
            }
            let offered = OperationCatalog.operations(for: [source], wheel: .convert, context: context)
                + OperationCatalog.operations(for: [source], wheel: .tools, context: context)
            let targets = item.targets ?? offered.filter { $0.wheel == .convert }.map { String($0.id.dropFirst("convert.".count)) }
            for target in targets {
                let key = "\(item.id) → \(target)"
                if journal.finished.contains(key) { continue }
                var line: [String: Any] = [
                    "id": item.id, "category": item.category, "target": target, "source": source.path,
                    "expected": item.expected ?? "convert",
                ]
                if journal.started.contains(key) {
                    // Started on an earlier run that never logged an end: that run crashed or was killed here.
                    line["status"] = "crash"
                    journal.write(line, key: key)
                    continue
                }
                guard let operation = offered.first(where: { $0.id == "convert.\(target)" || $0.id == "tools.\(target)" }) else {
                    line["status"] = "not-offered"
                    // A target this machine's FFmpeg can't write says nothing about Kumquat: the bundled FFmpeg has it.
                    // Nor does a Keynote, Pages or Numbers target on a Mac without that app.
                    if let format = FileFormat(rawValue: target) {
                        if let ffmpeg, let encoder = FFmpegEngine.missingEncoder(for: format, ffmpeg: ffmpeg) {
                            line["unavailable"] = "this FFmpeg has no \(encoder) encoder"
                        } else if [.key, .pages, .numbers].contains(format), let original = FileFormat.detect(source),
                                  !OfficeEngine.canConvert(original, to: format) {
                            line["unavailable"] = "no app on this Mac writes \(format.displayName)"
                        }
                    }
                    journal.write(line, key: key)
                    continue
                }
                journal.start(key)
                let started = Date()
                let folder = output.appendingPathComponent(item.id, isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                var itemContext = context
                itemContext.outputDirectory = folder
                // If the conversion blocks the main thread, the run loop below never gets to check the time.
                // A watchdog on another thread then logs the hang and ends the run; corpus.sh starts the next one.
                var hung = line
                hung["operation"] = operation.id
                hung["status"] = "timeout"
                hung["error"] = "Blocked the main thread for more than \(Int(timeout + 30)) s."
                let hangLine = hung
                let watchdog = DispatchWorkItem {
                    journal.write(hangLine, key: key)
                    exit(3)
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout + 30, execute: watchdog)
                let result = perform(operation, on: source, context: itemContext)
                watchdog.cancel()
                line["operation"] = operation.id
                line["ms"] = Int(Date().timeIntervalSince(started) * 1000)
                switch result {
                case .success(let outcome):
                    line["outputs"] = outcome.outputs.map(\.path)
                    if outcome.outputs.isEmpty {
                        line["status"] = "error"
                        line["error"] = outcome.failures.joined(separator: "; ")
                    } else {
                        line["status"] = "ok"
                    }
                case .failure(let error):
                    line["status"] = error is TimeoutError ? "timeout" : "error"
                    line["error"] = error.localizedDescription
                }
                journal.write(line, key: key)
            }
        }
        exit(0)
    }

    /// `Kumquat --convert <file> <target,target…> <output folder>`: conversions of one file, for checking results by hand.
    static func convert(arguments: [String]) -> Never {
        guard arguments.count >= 3 else {
            print("usage: Kumquat --convert <file> <target,target…> <output folder>")
            exit(2)
        }
        let source = URL(fileURLWithPath: arguments[0])
        let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
        try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let ffmpeg = ProcessInfo.processInfo.environment["KUMQUAT_FFMPEG"].map(URL.init(fileURLWithPath:)) ?? FFmpegEngine.locate()
        let context = OperationContext(outputDirectory: output, ffmpeg: ffmpeg)
        let offered = OperationCatalog.operations(for: [source], wheel: .convert, context: context)
        var failed = false
        for target in arguments[1].split(separator: ",").map(String.init) {
            guard let operation = offered.first(where: { $0.id == "convert.\(target)" }) else {
                print("\(target)\tnot offered")
                failed = true
                continue
            }
            let started = Date()
            let result = perform(operation, on: source, context: context)
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            switch result {
            case .success(let outcome):
                print("\(target)\t\(ms) ms\t" + (outcome.outputs.map(\.path) + outcome.failures).joined(separator: "; "))
                if outcome.outputs.isEmpty { failed = true }
            case .failure(let error):
                print("\(target)\t\(ms) ms\terror: \(error.localizedDescription)")
                failed = true
            }
        }
        exit(failed ? 1 : 0)
    }

    private struct TimeoutError: LocalizedError {
        var errorDescription: String? { "Took longer than \(Int(CorpusRunner.timeout)) s." }
    }

    /// Runs an operation with a time limit, keeping the main run loop turning for engines that need it.
    private static func perform(_ operation: FileOperation, on url: URL, context: OperationContext) -> Result<OperationOutcome, Error> {
        let box = Box()
        let task = Task.detached {
            do { box.set(.success(try await operation.perform([url], context))) } catch { box.set(.failure(error)) }
        }
        let deadline = Date().addingTimeInterval(timeout)
        while box.value == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        if let value = box.value { return value }
        task.cancel()
        return .failure(TimeoutError())
    }

    /// The file for an item: named by its id, then its extension or, for the generated names, a space.
    private static func file(for item: Item, in folder: URL) -> URL? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names
            .first { $0 == item.id || $0.hasPrefix(item.id + ".") || $0.hasPrefix(item.id + " ") }
            .map { folder.appendingPathComponent($0) }
    }

    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Result<OperationOutcome, Error>?
        var value: Result<OperationOutcome, Error>? { lock.lock(); defer { lock.unlock() }; return stored }
        func set(_ result: Result<OperationOutcome, Error>) { lock.lock(); stored = result; lock.unlock() }
    }

    /// The results file: one JSON object per line, flushed as it goes.
    private final class Journal {
        let url: URL
        private(set) var started = Set<String>()
        private(set) var finished = Set<String>()

        init(_ url: URL) {
            self.url = url
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                for line in text.split(separator: "\n") {
                    guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                          let key = object["key"] as? String else { continue }
                    if object["status"] as? String == "started" { started.insert(key) } else { finished.insert(key) }
                }
            } else {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
        }

        func start(_ key: String) {
            write(["key": key, "status": "started"])
            started.insert(key)
        }

        func write(_ object: [String: Any], key: String? = nil) {
            var object = object
            if let key {
                object["key"] = key
                finished.insert(key)
            }
            guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
                  let handle = try? FileHandle(forWritingTo: url) else { return }
            handle.seekToEndOfFile()
            handle.write(data + Data("\n".utf8))
            try? handle.synchronize()
            try? handle.close()
            let status = object["status"] as? String ?? ""
            if status != "started" { print("\(status)\t\(key ?? object["id"] as? String ?? "")") }
        }
    }
}

/// Corpus files that can't be downloaded, made on the CI runner instead.
enum Generated {
    static func make(in folder: URL, from items: [CorpusRunner.Item]) -> [CorpusRunner.Item] {
        var made: [CorpusRunner.Item] = []
        let fm = FileManager.default
        func add(_ id: String, _ category: String, _ expected: String, _ targets: [String], _ build: (URL) throws -> Void, ext: String) {
            let url = folder.appendingPathComponent("\(id).\(ext)")
            if !fm.fileExists(atPath: url.path) {
                do { try build(url) } catch {
                    print("couldn't make \(id): \(error.localizedDescription)")
                    return
                }
            }
            made.append(CorpusRunner.Item(id: id, category: category, url: nil, expected: expected, targets: targets))
        }

        // A long document: 500 pages of text and shapes.
        // Shapes only, no text, so the text targets would rightly come out empty.
        add("gen-pdf-500-pages", "pdf", "convert", ["png", "jpeg"], { url in
            let made = try Fixtures.pdf(pages: 500, in: folder)
            try fm.moveItem(at: made, to: url)
        }, ext: "pdf")

        // A PDF that needs a password to open: Kumquat must say so, not hang or crash.
        add("gen-pdf-password", "pdf", "clean-error", ["png", "txt"], { url in
            let plain = try Fixtures.pdf(pages: 3, in: folder)
            defer { try? fm.removeItem(at: plain) }
            guard let document = PDFDocument(url: plain),
                  document.write(to: url, withOptions: [.userPasswordOption: "kumquat", .ownerPasswordOption: "kumquat-owner"])
            else { throw OperationError.failed("PDFKit couldn't encrypt the PDF.") }
        }, ext: "pdf")

        // A ZIP cut off halfway, as from an interrupted download.
        add("gen-zip-truncated", "archive", "clean-error", ["extract"], { url in
            let content = folder.appendingPathComponent("zip-content", isDirectory: true)
            try fm.createDirectory(at: content, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: content) }
            for index in 0..<20 {
                try Data((0..<40_000).map { UInt8(truncatingIfNeeded: $0 &* (index + 7)) })
                    .write(to: content.appendingPathComponent("part \(index).bin"))
            }
            let whole = folder.appendingPathComponent("whole.zip")
            defer { try? fm.removeItem(at: whole) }
            let ditto = Process()
            ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            ditto.arguments = ["-c", "-k", content.path, whole.path]
            try ditto.run()
            ditto.waitUntilExit()
            let data = try Data(contentsOf: whole)
            try data.prefix(data.count / 2).write(to: url)
        }, ext: "zip")

        // Names with Finnish and Swedish letters and spaces, in decomposed form as macOS file systems keep them.
        for (category, ext) in [("image", "jpg"), ("video", "mov"), ("pdf", "pdf"), ("audio", "mp3")] {
            guard let original = items.first(where: { $0.category.hasPrefix(category) })
                .flatMap({ item in (try? fm.contentsOfDirectory(atPath: folder.path))?.first { $0.hasPrefix(item.id + ".") } })
            else { continue }
            let sourceExt = (original as NSString).pathExtension
            let id = "gen-name-\(category)"
            let name = "\(id) Kesä Åland – öljyä ja äyriäisiä".decomposedStringWithCanonicalMapping
            let url = folder.appendingPathComponent("\(name).\(sourceExt.isEmpty ? ext : sourceExt)")
            if !fm.fileExists(atPath: url.path) {
                try? fm.copyItem(at: folder.appendingPathComponent(original), to: url)
            }
            made.append(CorpusRunner.Item(id: id, category: category, url: nil, expected: "convert", targets: nil))
        }

        // An iCloud placeholder of the older kind (".name.icloud"): Kumquat should offer nothing rather than fail.
        // Real dataless placeholders need a signed-in iCloud Drive and can't be made on a CI runner.
        add("gen-icloud-stub", "other", "clean-error", ["png"], { url in
            let plist: [String: Any] = ["NSURLNameKey": "Holiday.heic", "NSURLFileSizeKey": 2_400_000, "NSURLFileResourceTypeKey": "NSURLFileResourceTypeRegular"]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
            try data.write(to: url)
        }, ext: "icloud")
        return made
    }
}
