import Foundation

/// Broad family a file belongs to. Decides which wheel options are offered.
public enum FileCategory: String, Sendable, CaseIterable {
    case image, video, audio, pdf, document, ebook, presentation, spreadsheet, subtitle, archive, folder, other

    public var displayName: String {
        switch self {
        case .image: "Image"
        case .video: "Video"
        case .audio: "Audio"
        case .pdf: "PDF"
        case .document: "Document"
        case .ebook: "E-book"
        case .presentation: "Slides"
        case .spreadsheet: "Spreadsheet"
        case .subtitle: "Subtitles"
        case .archive: "Archive"
        case .folder: "Folder"
        case .other: "File"
        }
    }
}

/// Every format the app knows how to read, write, or both.
public enum FileFormat: String, Sendable, CaseIterable {
    // Images
    case jpeg, png, heic, tiff, gif, bmp, webp, avif, svg, psd
    // Video
    case mp4, mov, m4v, mkv, webm, avi, wmv, flv
    // Audio
    case mp3, m4a, aac, wav, aiff, flac, caf, ogg, opus, wma
    // PDF
    case pdf
    // Documents
    case docx, doc, rtf, rtfd, odt, txt, html, markdown, pages, textClipping
    // E-books
    case epub
    // Slides
    case pptx, ppt, key, odp
    // Spreadsheets & data
    case csv, tsv, xlsx, json, xls, ods, numbers
    // Subtitles
    case srt, vtt
    // Archives
    case zip, tar, tgz, gz, rar, sevenZip

    public var extensions: [String] {
        switch self {
        case .jpeg: ["jpg", "jpeg", "jpe"]
        case .png: ["png"]
        case .heic: ["heic", "heif", "hif"]
        case .tiff: ["tiff", "tif"]
        case .gif: ["gif"]
        case .bmp: ["bmp"]
        case .webp: ["webp"]
        case .avif: ["avif"]
        case .svg: ["svg"]
        case .psd: ["psd"]
        case .mp4: ["mp4"]
        case .mov: ["mov", "qt"]
        case .m4v: ["m4v"]
        case .mkv: ["mkv"]
        case .webm: ["webm"]
        case .avi: ["avi"]
        case .wmv: ["wmv"]
        case .flv: ["flv"]
        case .mp3: ["mp3"]
        case .m4a: ["m4a"]
        case .aac: ["aac"]
        case .wav: ["wav", "wave"]
        case .aiff: ["aiff", "aif", "aifc"]
        case .flac: ["flac"]
        case .caf: ["caf"]
        case .ogg: ["ogg", "oga"]
        case .opus: ["opus"]
        case .wma: ["wma"]
        case .pdf: ["pdf"]
        case .docx: ["docx"]
        case .doc: ["doc"]
        case .rtf: ["rtf"]
        case .rtfd: ["rtfd"]
        case .odt: ["odt"]
        case .txt: ["txt", "text"]
        case .html: ["html", "htm", "xhtml"]
        case .markdown: ["md", "markdown", "mdown", "mkd"]
        case .pages: ["pages"]
        case .textClipping: ["textclipping"]
        case .epub: ["epub"]
        case .pptx: ["pptx"]
        case .ppt: ["ppt", "pps", "ppsx"]
        case .key: ["key"]
        case .odp: ["odp"]
        case .xls: ["xls"]
        case .ods: ["ods"]
        case .numbers: ["numbers"]
        case .csv: ["csv"]
        case .tsv: ["tsv", "tab"]
        case .xlsx: ["xlsx"]
        case .json: ["json"]
        case .srt: ["srt"]
        case .vtt: ["vtt"]
        case .zip: ["zip"]
        case .tar: ["tar"]
        case .tgz: ["tgz"]
        case .gz: ["gz", "gzip"]
        case .rar: ["rar"]
        case .sevenZip: ["7z"]
        }
    }

    public var primaryExtension: String {
        self == .tgz ? "tar.gz" : extensions[0]
    }

    public var displayName: String {
        switch self {
        case .jpeg: "JPG"
        case .webp: "WebP"
        case .webm: "WebM"
        case .opus: "Opus"
        case .markdown: "Markdown"
        case .pages: "Pages"
        case .key: "Keynote"
        case .numbers: "Numbers"
        case .textClipping: "Clipping"
        case .tgz: "TAR.GZ"
        case .sevenZip: "7Z"
        default: rawValue.uppercased()
        }
    }

    public var category: FileCategory {
        switch self {
        case .jpeg, .png, .heic, .tiff, .gif, .bmp, .webp, .avif, .svg, .psd: .image
        case .mp4, .mov, .m4v, .mkv, .webm, .avi, .wmv, .flv: .video
        case .mp3, .m4a, .aac, .wav, .aiff, .flac, .caf, .ogg, .opus, .wma: .audio
        case .pdf: .pdf
        case .docx, .doc, .rtf, .rtfd, .odt, .txt, .html, .markdown, .pages, .textClipping: .document
        case .epub: .ebook
        case .pptx, .ppt, .key, .odp: .presentation
        case .csv, .tsv, .xlsx, .json, .xls, .ods, .numbers: .spreadsheet
        case .srt, .vtt: .subtitle
        case .zip, .tar, .tgz, .gz, .rar, .sevenZip: .archive
        }
    }

    /// Whether the encoded image can carry an alpha channel.
    public var supportsAlpha: Bool {
        switch self {
        case .jpeg, .bmp: false
        default: true
        }
    }

    private static let byExtension: [String: FileFormat] = {
        var map: [String: FileFormat] = [:]
        for format in FileFormat.allCases {
            for ext in format.extensions where map[ext] == nil {
                map[ext] = format
            }
        }
        return map
    }()

    public static func detect(_ url: URL) -> FileFormat? {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".tar.gz") { return .tgz }
        return byExtension[url.pathExtension.lowercased()]
    }
}

public extension URL {
    /// File name without its extension, treating `.tar.gz` as one extension.
    var baseName: String {
        let name = lastPathComponent
        if name.lowercased().hasSuffix(".tar.gz") {
            return String(name.dropLast(7))
        }
        return deletingPathExtension().lastPathComponent
    }

    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    /// Folders count as folders, except document packages such as `.rtfd`.
    var fileCategory: FileCategory {
        if let format = FileFormat.detect(self) { return format.category }
        return isDirectory ? .folder : .other
    }
}
