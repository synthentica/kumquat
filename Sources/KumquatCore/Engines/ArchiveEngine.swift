import Foundation

/// Archives through the tools built into macOS: ditto, zip, tar (libarchive, which also reads RAR and 7z) and gzip.
public enum ArchiveEngine {
    public enum Kind: Sendable {
        case zip, tarGz, tar
        /// A single file, gzipped on its own.
        case gzip

        var fileExtension: String {
            switch self {
            case .zip: "zip"
            case .tarGz: "tar.gz"
            case .tar: "tar"
            case .gzip: "gz"
            }
        }
    }

    public static func compress(_ urls: [URL], as kind: Kind, context: OperationContext) async throws -> URL {
        guard let first = urls.first else { throw OperationError.failed("Nothing to compress.") }
        let parent = first.deletingLastPathComponent()
        if kind == .gzip, urls.count > 1 || first.isDirectory { throw OperationError.failed("GZIP compresses one file at a time.") }
        let name = urls.count == 1 ? first.lastPathComponent : "Archive"
        let output = context.destination(for: first, name: name, extension: kind.fileExtension)
        let entries = urls.map { $0.deletingLastPathComponent() == parent ? $0.lastPathComponent : $0.path }
        do {
            switch kind {
            case .zip where urls.count == 1:
                try await Shell.run("/usr/bin/ditto", ["-c", "-k", "--keepParent", "--norsrc", "--noextattr", first.path, output.path])
            case .zip:
                try await Shell.run("/usr/bin/zip", ["-r", "-y", "-q", output.path] + entries + ["-x", "*.DS_Store"], in: parent)
            case .tarGz:
                try await Shell.run("/usr/bin/tar", ["-czf", output.path, "--exclude", ".DS_Store"] + entries, in: parent, environment: ["COPYFILE_DISABLE": "1"])
            case .tar:
                try await Shell.run("/usr/bin/tar", ["-cf", output.path, "--exclude", ".DS_Store"] + entries, in: parent, environment: ["COPYFILE_DISABLE": "1"])
            case .gzip:
                try await Shell.run("/usr/bin/gzip", ["-c", "-9", "-n", first.path], standardOutput: output)
            }
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        return output
    }

    /// Unpacks next to the archive. A single top-level item is placed directly, like Archive Utility does.
    public static func extract(_ url: URL, context: OperationContext) async throws -> URL {
        let fm = FileManager.default
        let folder = context.folderDestination(for: url)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            switch FileFormat.detect(url) {
            case .zip:
                try await Shell.run("/usr/bin/ditto", ["-x", "-k", url.path, folder.path])
            case .gz:
                try await Shell.run("/usr/bin/gzip", ["-dc", url.path], standardOutput: folder.appendingPathComponent(url.baseName))
            default:
                try await Shell.run("/usr/bin/tar", ["-xf", url.path, "-C", folder.path])
            }
        } catch {
            try? fm.removeItem(at: folder)
            throw error
        }
        let items = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent != "__MACOSX" && $0.lastPathComponent != ".DS_Store" } ?? []
        guard items.count == 1, let only = items.first else { return folder }
        let target = context.destination(for: url, name: only.deletingPathExtension().lastPathComponent, extension: only.pathExtension)
        try fm.moveItem(at: only, to: target)
        try? fm.removeItem(at: folder)
        return target
    }
}
