import AppKit
import Foundation

/// Office formats macOS can't read on its own (PowerPoint, Keynote, Pages, Numbers, XLS).
/// Uses LibreOffice when it's installed, otherwise drives Keynote, Pages or Numbers, which are free on every Mac.
public enum OfficeEngine {
    enum App: String {
        case keynote = "Keynote"
        case pages = "Pages"
        case numbers = "Numbers"

        var isInstalled: Bool { OfficeEngine.installedApps.contains(self) }

        /// The AppleScript export clause for a target: nil when the app can't write it,
        /// `.some(nil)` when it's the app's own format and is saved instead of exported.
        func exportClause(for target: FileFormat) -> String?? {
            switch (self, target) {
            case (.keynote, .key), (.pages, .pages), (.numbers, .numbers): return .some(nil)
            case (_, .pdf): return "PDF"
            case (.keynote, .pptx): return "Microsoft PowerPoint"
            case (.pages, .docx): return "Microsoft Word"
            case (.pages, .epub): return "EPUB"
            case (.pages, .txt): return "unformatted text"
            case (.numbers, .xlsx): return "Microsoft Excel"
            default: return nil
            }
        }

        func canWrite(_ target: FileFormat) -> Bool { exportClause(for: target) != nil }

        func canOpen(_ format: FileFormat) -> Bool {
            switch self {
            case .keynote: [.key, .pptx, .ppt].contains(format)
            case .pages: [.pages, .docx, .doc, .rtf, .txt].contains(format)
            case .numbers: [.numbers, .xlsx, .xls, .csv, .tsv].contains(format)
            }
        }
    }

    static let libreOfficePaths = [
        "/Applications/LibreOffice.app/Contents/MacOS/soffice",
        "/opt/homebrew/bin/soffice",
        "/usr/local/bin/soffice",
    ]

    /// Looked up once per launch, since the wheel asks while it opens.
    static let libreOffice: URL? = libreOfficePaths
        .first(where: FileManager.default.isExecutableFile(atPath:))
        .map(URL.init(fileURLWithPath:))

    static let installedApps: Set<App> = Set([App.keynote, .pages, .numbers].filter { app in
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iWork.\(app.rawValue)") != nil
    })

    static let iWorkFormats: Set<FileFormat> = [.key, .pages, .numbers]

    /// LibreOffice's name for each output format.
    static func libreOfficeFilter(_ target: FileFormat) -> String? {
        switch target {
        case .pdf: "pdf"
        case .pptx: "pptx"
        case .odp: "odp"
        case .docx: "docx"
        case .odt: "odt"
        case .xlsx: "xlsx"
        case .ods: "ods"
        case .epub: "epub"
        case .txt: "txt:Text (encoded):UTF8"
        default: nil
        }
    }

    enum Route {
        case libreOffice(URL)
        case app(App)
    }

    /// How a file can be turned into `target` on this Mac, if at all.
    static func route(from source: FileFormat, to target: FileFormat) -> Route? {
        let apps = [App.keynote, .pages, .numbers].filter { $0.canOpen(source) && $0.canWrite(target) && $0.isInstalled }
        let office = libreOffice.flatMap { libreOfficeFilter(target) != nil ? $0 : nil }
        // iWork files open best in their own app; everything else is quicker in headless LibreOffice.
        if iWorkFormats.contains(source), let app = apps.first { return .app(app) }
        if let office, !iWorkFormats.contains(target) { return .libreOffice(office) }
        return apps.first.map(Route.app)
    }

    public static func canConvert(_ source: FileFormat, to target: FileFormat) -> Bool {
        route(from: source, to: target) != nil
    }

    public static func convert(_ url: URL, to target: FileFormat, context: OperationContext) async throws -> URL {
        let output = context.destination(for: url, extension: target.primaryExtension)
        try await convert(url, to: target, output: output)
        return output
    }

    static func convert(_ url: URL, to target: FileFormat, output: URL) async throws {
        guard let source = FileFormat.detect(url), let route = route(from: source, to: target) else {
            throw OperationError.unsupported("\(target.displayName) without LibreOffice, Keynote, Pages or Numbers")
        }
        do {
            // One document at a time: the iWork apps work through a single scripting session,
            // and each LibreOffice run starts a whole office suite.
            try await Lane.office.run {
                switch route {
                case .libreOffice(let soffice):
                    try await runLibreOffice(soffice, input: url, target: target, output: output)
                case .app(let app):
                    try await runApp(app, input: url, target: target, output: output)
                }
            }
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        guard FileManager.default.fileExists(atPath: output.path) else {
            throw OperationError.failed("\(target.displayName) export didn't produce a file.")
        }
    }

    /// Converts into a hidden file next to `url` (where iWork apps are allowed to write), runs `body`, then removes it.
    static func withIntermediate<T>(_ url: URL, as target: FileFormat, _ body: (URL) async throws -> T) async throws -> T {
        let hidden = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.baseName)-kumquat-\(UUID().uuidString.prefix(8)).\(target.primaryExtension)")
        defer { try? FileManager.default.removeItem(at: hidden) }
        try await convert(url, to: target, output: hidden)
        return try await body(hidden)
    }

    private static func runLibreOffice(_ soffice: URL, input: URL, target: FileFormat, output: URL) async throws {
        guard let filter = libreOfficeFilter(target) else { throw OperationError.unsupported(target.displayName) }
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        // A private profile, so a LibreOffice window the user has open doesn't block the conversion.
        let profile = work.appendingPathComponent("profile", isDirectory: true)
        try await Shell.run(soffice.path, [
            "-env:UserInstallation=\(profile.absoluteString)",
            "--headless", "--norestore", "--nolockcheck",
            "--convert-to", filter, "--outdir", work.path, input.path,
        ])
        let produced = try FileManager.default.contentsOfDirectory(at: work, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent != "profile" }
        guard let produced else { throw OperationError.failed("LibreOffice didn't produce a file.") }
        try FileManager.default.moveItem(at: produced, to: output)
    }

    private static func runApp(_ app: App, input: URL, target: FileFormat, output: URL) async throws {
        guard let clause = app.exportClause(for: target) else { throw OperationError.unsupported(target.displayName) }
        let action = clause.map { "export theDocument to outputFile as \($0)" } ?? "save theDocument in outputFile"
        let script = """
        set inputFile to POSIX file "\(escaped(input.path))" as alias
        set outputFile to POSIX file "\(escaped(output.path))"
        set wasRunning to application "\(app.rawValue)" is running
        tell application "\(app.rawValue)"
            set theDocument to open inputFile
            \(action)
            close theDocument saving no
            if not wasRunning then quit
        end tell
        """
        try await Shell.run("/usr/bin/osascript", ["-e", script])
    }

    private static func escaped(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: Slides

    /// Every slide as an image, by way of a PDF.
    public static func slideImages(_ url: URL, as format: FileFormat, context: OperationContext) async throws -> URL {
        try await withIntermediate(url, as: .pdf) { pdf in
            try PDFEngine.renderPages(pdf, as: format, dpi: 200, naming: url, context: context)
        }
    }
}
