import Foundation

/// The three radial menus, each opened by its own modifier key.
public enum Wheel: Int, CaseIterable, Sendable {
    case convert, tools, actions

    public var title: String {
        switch self {
        case .convert: "Convert"
        case .tools: "Tools"
        case .actions: "Actions"
        }
    }
}

/// Settings an operation needs while it runs.
public struct OperationContext: Sendable {
    /// Where results go. `nil` saves next to the original file.
    public var outputDirectory: URL?
    /// Lossy encoder quality, 0...1.
    public var imageQuality: Double
    /// FFmpeg binary, when one is installed. Unlocks extra formats.
    public var ffmpeg: URL?

    public init(outputDirectory: URL? = nil, imageQuality: Double = 0.85, ffmpeg: URL? = nil) {
        self.outputDirectory = outputDirectory
        self.imageQuality = imageQuality
        self.ffmpeg = ffmpeg
    }

    func directory(for input: URL) -> URL {
        outputDirectory ?? input.deletingLastPathComponent()
    }

    /// A fresh, unused file URL for the result of processing `input`.
    public func destination(for input: URL, name: String? = nil, extension ext: String, suffix: String? = nil) -> URL {
        var base = name ?? input.baseName
        if let suffix { base += " (\(suffix))" }
        return OutputNamer.shared.reserve(in: directory(for: input), base: base, extension: ext)
    }

    /// A fresh, unused folder URL (not yet created) for multi-file results.
    public func folderDestination(for input: URL, name: String? = nil, suffix: String? = nil) -> URL {
        var base = name ?? input.baseName
        if let suffix { base += " (\(suffix))" }
        return OutputNamer.shared.reserve(in: directory(for: input), base: base, extension: nil)
    }
}

/// Hands out unique output paths, also across operations running in parallel.
final class OutputNamer: @unchecked Sendable {
    static let shared = OutputNamer()
    private let lock = NSLock()
    private var reserved = Set<String>()

    func reserve(in directory: URL, base: String, extension ext: String?) -> URL {
        lock.lock()
        defer { lock.unlock() }
        func candidate(_ n: Int) -> URL {
            let name = n == 1 ? base : "\(base) \(n)"
            let url = directory.appendingPathComponent(name)
            guard let ext, !ext.isEmpty else { return url }
            return URL(fileURLWithPath: url.path + "." + ext)
        }
        var n = 1
        var url = candidate(n)
        while reserved.contains(url.path) || FileManager.default.fileExists(atPath: url.path) {
            n += 1
            url = candidate(n)
        }
        reserved.insert(url.path)
        if reserved.count > 512 { reserved.removeAll(keepingCapacity: true) }
        return url
    }
}

public struct OperationOutcome: Sendable {
    public var outputs: [URL]
    public var failures: [String]
    /// Overrides the default "done" text shown to the user.
    public var message: String?
    /// The operation shows its own UI, so no toast is needed.
    public var silent: Bool

    public init(outputs: [URL] = [], failures: [String] = [], message: String? = nil, silent: Bool = false) {
        self.outputs = outputs
        self.failures = failures
        self.message = message
        self.silent = silent
    }
}

public enum OperationError: LocalizedError, Sendable {
    case unreadable(String)
    case unsupported(String)
    case failed(String)
    case toolFailed(name: String, message: String)
    case alreadyOptimal

    public var errorDescription: String? {
        switch self {
        case .unreadable(let name): "Couldn't read \(name)."
        case .unsupported(let what): "\(what) isn't supported."
        case .failed(let message): message
        case .toolFailed(let name, let message): message.isEmpty ? "\(name) failed." : "\(name): \(message)"
        case .alreadyOptimal: "Already as small as it gets."
        }
    }
}

/// One entry on a wheel.
public struct FileOperation: Identifiable, @unchecked Sendable {
    public let id: String
    /// Short label shown on the wheel, like "PNG" or "Compress".
    public let title: String
    /// Optional second line, like "Lossless".
    public let subtitle: String?
    /// SF Symbol name.
    public let symbol: String
    public let wheel: Wheel
    /// Shown while running, like "Converting to PNG".
    public let verb: String
    public let perform: @Sendable ([URL], OperationContext) async throws -> OperationOutcome

    public init(
        id: String, title: String, subtitle: String? = nil, symbol: String, wheel: Wheel, verb: String,
        perform: @escaping @Sendable ([URL], OperationContext) async throws -> OperationOutcome
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.wheel = wheel
        self.verb = verb
        self.perform = perform
    }

    /// An operation that turns each input into one output, running files in parallel.
    public static func perFile(
        id: String, title: String, subtitle: String? = nil, symbol: String, wheel: Wheel, verb: String,
        _ body: @escaping @Sendable (URL, OperationContext) async throws -> URL
    ) -> FileOperation {
        FileOperation(id: id, title: title, subtitle: subtitle, symbol: symbol, wheel: wheel, verb: verb) { urls, context in
            await Batch.run(urls) { try await body($0, context) }
        }
    }
}

enum Batch {
    static func run(_ urls: [URL], _ body: @escaping @Sendable (URL) async throws -> URL) async -> OperationOutcome {
        let limit = max(2, ProcessInfo.processInfo.activeProcessorCount)
        var outputs = [URL?](repeating: nil, count: urls.count)
        var failures: [String] = []
        await withTaskGroup(of: (Int, Result<URL, Error>).self) { group in
            var next = 0
            func enqueue() {
                guard next < urls.count else { return }
                let index = next
                let url = urls[index]
                next += 1
                group.addTask {
                    do { return (index, .success(try await body(url))) } catch { return (index, .failure(error)) }
                }
            }
            for _ in 0..<min(limit, urls.count) { enqueue() }
            while let item = await group.next() {
                let (index, result) = item
                switch result {
                case .success(let url): outputs[index] = url
                case .failure(let error):
                    failures.append("\(urls[index].lastPathComponent): \(error.localizedDescription)")
                }
                enqueue()
            }
        }
        return OperationOutcome(outputs: outputs.compactMap { $0 }, failures: failures)
    }
}

extension FileManager {
    func makeTemporaryDirectory() throws -> URL {
        let url = temporaryDirectory.appendingPathComponent("Kumquat-\(UUID().uuidString)", isDirectory: true)
        try createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func fileSize(_ url: URL) -> Int64 {
        (try? attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
    }
}

/// Keeps a "compressed" result only when it actually saved space.
func keepIfSmaller(_ output: URL, than input: URL) throws -> URL {
    let fm = FileManager.default
    if fm.fileSize(output) >= fm.fileSize(input) {
        try? fm.removeItem(at: output)
        throw OperationError.alreadyOptimal
    }
    return output
}
