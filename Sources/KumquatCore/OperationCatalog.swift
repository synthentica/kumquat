import Foundation

/// Decides which operations a set of files gets on each wheel.
public enum OperationCatalog {
    /// Answers once for every kind of file, off the main thread, so the lookups behind the wheel
    /// (installed apps, encoders, FFmpeg) are cached before the first drag instead of during it.
    public static func prewarm(context: OperationContext) {
        let samples = ["png", "mp4", "mkv", "mp3", "ogg", "pdf", "docx", "pages", "pptx", "key", "xlsx", "numbers", "srt", "zip"]
        for ext in samples {
            let url = URL(fileURLWithPath: "/kumquat-prewarm.\(ext)")
            for wheel in [Wheel.convert, .tools] { _ = operations(for: [url], wheel: wheel, context: context) }
        }
    }

    public static func operations(for urls: [URL], wheel: Wheel, context: OperationContext) -> [FileOperation] {
        guard !urls.isEmpty else { return [] }
        switch wheel {
        case .convert: return conversions(urls, context)
        case .tools: return tools(urls, context)
        case .actions: return []
        }
    }

    static func commonCategory(_ urls: [URL]) -> FileCategory? {
        let categories = Set(urls.map(\.fileCategory))
        return categories.count == 1 ? categories.first : nil
    }

    static let nativeVideo: Set<FileFormat> = [.mp4, .mov, .m4v]
    static let nativeAudio: Set<FileFormat> = [.mp3, .m4a, .aac, .wav, .aiff, .flac, .caf]

    // MARK: Convert wheel

    static func conversions(_ urls: [URL], _ context: OperationContext) -> [FileOperation] {
        guard let category = commonCategory(urls) else { return [] }
        let formats = Set(urls.compactMap(FileFormat.detect))
        let hasFFmpeg = context.ffmpeg != nil
        /// Hide a target only when every input already has that format.
        func isNew(_ format: FileFormat) -> Bool { formats != [format] }
        var ops: [FileOperation] = []

        switch category {
        case .image:
            for target in [FileFormat.png, .jpeg, .heic, .webp, .avif, .tiff, .gif, .bmp] where isNew(target) {
                if ImageEngine.canWrite(target) {
                    ops.append(convert(target) { try ImageEngine.convert($0, to: target, context: $1) })
                } else if target == .webp, hasFFmpeg {
                    ops.append(convert(target) { try await FFmpegEngine.convert($0, to: target, context: $1) })
                }
            }
            ops.append(convert(.pdf) { try ImageEngine.toPDF($0, context: $1) })

        case .video:
            if formats.isSubset(of: nativeVideo) {
                for target in [FileFormat.mp4, .mov] where isNew(target) {
                    ops.append(convert(target) { try await VideoEngine.convert($0, to: target, context: $1) })
                }
                ops.append(convert(.mp4, title: "HEVC", subtitle: "H.265", id: "convert.hevc") { try await VideoEngine.hevc($0, context: $1) })
                if hasFFmpeg {
                    ops.append(convert(.gif) { try await FFmpegEngine.convert($0, to: .gif, context: $1) })
                    ops.append(convert(.webm) { try await FFmpegEngine.convert($0, to: .webm, context: $1) })
                    for target in [FileFormat.mkv, .avi, .wmv] {
                        ops.append(convert(target) { try await FFmpegEngine.convert($0, to: target, context: $1) })
                    }
                    ops.append(convert(.mp3, subtitle: "Audio") { try await FFmpegEngine.convert($0, to: .mp3, context: $1) })
                } else {
                    ops.append(convert(.gif) { try await VideoEngine.convert($0, to: .gif, context: $1) })
                }
                ops.append(convert(.m4a, subtitle: "Audio") { try await VideoEngine.convert($0, to: .m4a, context: $1) })
            } else if hasFFmpeg {
                for target in [FileFormat.mp4, .mov, .webm, .mkv, .avi, .wmv, .gif] where isNew(target) {
                    ops.append(convert(target) { try await FFmpegEngine.convert($0, to: target, context: $1) })
                }
                ops.append(convert(.mp3, subtitle: "Audio") { try await FFmpegEngine.convert($0, to: .mp3, context: $1) })
                ops.append(convert(.m4a, subtitle: "Audio") { try await FFmpegEngine.convert($0, to: .m4a, context: $1) })
            }

        case .audio:
            let native = formats.isSubset(of: nativeAudio)
            for target in [FileFormat.m4a, .mp3, .wav, .aiff, .flac, .ogg, .opus, .wma] where isNew(target) {
                let subtitle: String? = target == .m4a ? "AAC" : nil
                if native, [.m4a, .wav, .aiff, .flac].contains(target) {
                    ops.append(convert(target, subtitle: subtitle) { try await AudioEngine.convert($0, to: target, context: $1) })
                } else if hasFFmpeg {
                    ops.append(convert(target, subtitle: subtitle) { try await FFmpegEngine.convert($0, to: target, context: $1) })
                }
            }
            if native {
                ops.append(convert(.m4a, title: "ALAC", subtitle: "Lossless", id: "convert.alac") {
                    try AudioEngine.encode($0, .alac, context: $1)
                })
            } else if hasFFmpeg {
                ops.append(convert(.m4a, title: "ALAC", subtitle: "Lossless", id: "convert.alac") {
                    try await FFmpegEngine.alac($0, context: $1)
                })
            }

        case .pdf:
            ops.append(convert(.png, subtitle: "300 DPI") { try PDFEngine.renderPages($0, as: .png, context: $1) })
            ops.append(convert(.jpeg, subtitle: "300 DPI") { try PDFEngine.renderPages($0, as: .jpeg, context: $1) })
            for target in [FileFormat.docx, .txt, .markdown, .rtf, .html, .epub] {
                ops.append(convert(target) { try await DocumentEngine.convert($0, to: target, context: $1) })
            }
            ops.append(convert(.pptx) { try await PPTX.fromPDF($0, context: $1) })
            ops.append(convert(.xlsx) { try await Spreadsheet.convert($0, to: .xlsx, context: $1) })
            if OfficeEngine.canConvert(.docx, to: .pages) {
                ops.append(convert(.pages) { try await DocumentEngine.convert($0, to: .pages, context: $1) })
            }

        case .document where formats == [.pages]:
            // Pages files only open in Pages (or LibreOffice), which export these directly.
            for target in [FileFormat.pdf, .docx, .epub, .txt] where OfficeEngine.canConvert(.pages, to: target) {
                ops.append(convert(target) { try await OfficeEngine.convert($0, to: target, context: $1) })
            }

        case .document, .ebook:
            guard !formats.contains(.pages) else { break }
            for target in [FileFormat.pdf, .docx, .markdown, .txt, .rtf, .odt, .html, .epub] where isNew(target) {
                ops.append(convert(target) { try await DocumentEngine.convert($0, to: target, context: $1) })
            }
            if OfficeEngine.canConvert(.docx, to: .pages) {
                ops.append(convert(.pages) { try await DocumentEngine.convert($0, to: .pages, context: $1) })
            }

        case .presentation:
            let sources = formats
            // PowerPoint files are drawn natively; the rest need Keynote or LibreOffice.
            let native = sources == [.pptx]
            func available(_ target: FileFormat) -> Bool {
                sources.allSatisfy { OfficeEngine.canConvert($0, to: target) }
            }
            if native {
                ops.append(convert(.pdf) { try await PPTXRenderer.toPDF($0, context: $1) })
                ops.append(convert(.png, subtitle: "Slides") { try await PPTXRenderer.slideImages($0, as: .png, context: $1) })
                ops.append(convert(.jpeg, subtitle: "Slides") { try await PPTXRenderer.slideImages($0, as: .jpeg, context: $1) })
            } else if available(.pdf) {
                ops.append(convert(.pdf) { try await OfficeEngine.convert($0, to: .pdf, context: $1) })
                ops.append(convert(.png, subtitle: "Slides") { try await OfficeEngine.slideImages($0, as: .png, context: $1) })
                ops.append(convert(.jpeg, subtitle: "Slides") { try await OfficeEngine.slideImages($0, as: .jpeg, context: $1) })
            }
            for target in [FileFormat.pptx, .key, .odp] where isNew(target) && available(target) {
                ops.append(convert(target) { try await OfficeEngine.convert($0, to: target, context: $1) })
            }

        case .spreadsheet:
            // Numbers files are read through Numbers or LibreOffice.
            let readable = !formats.contains(.numbers) || OfficeEngine.canConvert(.numbers, to: .xlsx)
            guard readable else { break }
            for target in [FileFormat.xlsx, .csv, .tsv, .json, .ods, .pdf, .markdown, .html] where isNew(target) {
                ops.append(convert(target) { try await Spreadsheet.convert($0, to: target, context: $1) })
            }
            if isNew(.numbers), OfficeEngine.canConvert(.xlsx, to: .numbers) {
                ops.append(convert(.numbers) { try await Spreadsheet.convert($0, to: .numbers, context: $1) })
            }

        case .subtitle:
            for target in [FileFormat.srt, .vtt, .txt] where isNew(target) {
                ops.append(convert(target) { try Subtitles.convert($0, to: target, context: $1) })
            }

        case .archive:
            ops.append(.perFile(id: "convert.extract", title: "Extract", symbol: "archivebox", wheel: .convert, verb: "Extracting") {
                try await ArchiveEngine.extract($0, context: $1)
            })

        case .folder:
            ops += archiveOperations(wheel: .convert)

        case .other:
            break
        }
        return ops
    }

    // MARK: Tools wheel

    static func tools(_ urls: [URL], _ context: OperationContext) -> [FileOperation] {
        var ops: [FileOperation] = []
        let many = urls.count > 1

        switch commonCategory(urls) {
        case .image:
            ops.append(tool("compress", "Compress", "arrow.down.right.and.arrow.up.left", "Compressing") { try ImageEngine.compress($0, context: $1) })
            ops.append(tool("half", "Half size", "square.resize.down", "Resizing") { try ImageEngine.edit($0, .scale(0.5), context: $1) })
            ops.append(tool("fit1920", "1920 px", "rectangle.arrowtriangle.2.inward", "Resizing") { try ImageEngine.edit($0, .fit(1920), context: $1) })
            ops.append(tool("rotate", "Rotate", "rotate.right", "Rotating") { try ImageEngine.edit($0, .rotate(clockwise: true), context: $1) })
            ops.append(tool("flip", "Flip", "arrow.left.and.right.righttriangle.left.righttriangle.right", "Flipping") {
                try ImageEngine.edit($0, .flipHorizontal, context: $1)
            })
            ops.append(tool("mono", "B&W", "circle.lefthalf.filled", "Desaturating") { try ImageEngine.edit($0, .grayscale, context: $1) })
            ops.append(tool("strip", "No EXIF", "location.slash", "Removing metadata") { try ImageEngine.edit($0, .stripMetadata, context: $1) })
            ops.append(tool("square", "Square", "square.dashed", "Cropping") { try ImageEngine.edit($0, .squareCrop, context: $1) })
            ops.append(tool("trim", "Trim edges", "crop", "Trimming") { try ImageEngine.edit($0, .trimEdges, context: $1) })
            ops.append(tool("round", "Round", "app", "Rounding corners") { try ImageEngine.edit($0, .roundCorners, context: $1) })
            if #available(macOS 14.0, *) {
                ops.append(tool("cutout", "Cutout", "person.crop.rectangle", "Removing background") {
                    try ImageEngine.edit($0, .removeBackground, context: $1)
                })
            }
            if many {
                ops.append(FileOperation(id: "tools.combinepdf", title: "One PDF", symbol: "doc.on.doc", wheel: .tools, verb: "Combining") { urls, context in
                    let output = context.destination(for: urls[0], name: "Combined", extension: "pdf")
                    try ImageEngine.makePDF(from: urls, to: output)
                    return OperationOutcome(outputs: [output])
                })
            }

        case .video where Set(urls.compactMap(FileFormat.detect)).isSubset(of: nativeVideo):
            ops.append(tool("compress", "Compress", "arrow.down.right.and.arrow.up.left", "Compressing") { try await VideoEngine.compress($0, context: $1) })
            ops.append(tool("720p", "720p", "tv", "Resizing") { try await VideoEngine.resize720($0, context: $1) })
            ops.append(tool("mute", "Mute", "speaker.slash", "Removing audio") { try await VideoEngine.removeAudio($0, context: $1) })
            ops.append(tool("snapshot", "Snapshot", "camera", "Capturing a frame") { try await VideoEngine.snapshot($0, context: $1) })
            ops.append(tool("rotate", "Rotate", "rotate.right", "Rotating") { try await VideoEngine.rotate($0, context: $1) })
            ops.append(tool("split", "Split", "scissors", "Splitting into 1-minute parts") { try await VideoEngine.split($0, context: $1) })
            ops.append(tool("speed", "2× speed", "hare", "Speeding up") { try await VideoEngine.speedUp($0, context: $1) })
            if many {
                ops.append(combine("merge", "Merge", "square.on.square", "Merging") { try await VideoEngine.merge($0, context: $1) })
            }

        case .audio where Set(urls.compactMap(FileFormat.detect)).isSubset(of: nativeAudio):
            ops.append(tool("compress", "Compress", "arrow.down.right.and.arrow.up.left", "Compressing") { try AudioEngine.compress($0, context: $1) })
            ops.append(tool("mono", "Mono", "speaker.wave.1", "Mixing to mono") { try AudioEngine.mono($0, context: $1) })
            ops.append(tool("normalize", "Normalize", "waveform.path.ecg", "Normalizing") { try AudioEngine.normalize($0, context: $1) })
            ops.append(tool("trim", "Trim silence", "speaker.zzz", "Trimming silence") { try AudioEngine.trimSilence($0, context: $1) })
            ops.append(tool("split", "Split", "scissors", "Splitting into 1-minute parts") { try AudioEngine.split($0, context: $1) })
            if many {
                ops.append(combine("merge", "Merge", "square.on.square", "Merging") { try await AudioEngine.merge($0, context: $1) })
            }

        case .pdf:
            ops.append(tool("compress", "Compress", "arrow.down.right.and.arrow.up.left", "Compressing") { try PDFEngine.compress($0, context: $1) })
            ops.append(tool("split", "Split", "scissors", "Splitting pages") { try PDFEngine.split($0, context: $1) })
            ops.append(tool("rotate", "Rotate", "rotate.right", "Rotating") { try PDFEngine.rotate($0, context: $1) })
            if many {
                ops.append(combine("merge", "Merge", "square.on.square", "Merging") { try PDFEngine.merge($0, context: $1) })
            }

        default:
            break
        }

        if commonCategory(urls) != .folder {
            ops += archiveOperations(wheel: .tools).prefix(1)
            if urls.count == 1, !urls[0].isDirectory {
                ops.append(tool("gzip", "GZIP", "doc.zipper", "Compressing") { url, context in
                    try await ArchiveEngine.compress([url], as: .gzip, context: context)
                })
            }
        }
        return ops
    }

    static func archiveOperations(wheel: Wheel) -> [FileOperation] {
        [
            (ArchiveEngine.Kind.zip, "ZIP"),
            (.tarGz, "TAR.GZ"),
            (.tar, "TAR"),
        ].map { kind, title in
            FileOperation(id: "\(wheel == .convert ? "convert" : "tools").\(title.lowercased())", title: title,
                          subtitle: wheel == .tools ? "Archive" : nil, symbol: "doc.zipper", wheel: wheel, verb: "Compressing") { urls, context in
                OperationOutcome(outputs: [try await ArchiveEngine.compress(urls, as: kind, context: context)])
            }
        }
    }

    // MARK: Builders

    static func convert(
        _ target: FileFormat, title: String? = nil, subtitle: String? = nil, id: String? = nil,
        _ body: @escaping @Sendable (URL, OperationContext) async throws -> URL
    ) -> FileOperation {
        let title = title ?? target.displayName
        return .perFile(
            id: id ?? "convert.\(target.rawValue)", title: title, subtitle: subtitle,
            symbol: target.category.symbol, wheel: .convert, verb: "Converting to \(title)", body
        )
    }

    static func tool(
        _ id: String, _ title: String, _ symbol: String, _ verb: String,
        _ body: @escaping @Sendable (URL, OperationContext) async throws -> URL
    ) -> FileOperation {
        .perFile(id: "tools.\(id)", title: title, symbol: symbol, wheel: .tools, verb: verb, body)
    }

    static func combine(
        _ id: String, _ title: String, _ symbol: String, _ verb: String,
        _ body: @escaping @Sendable ([URL], OperationContext) async throws -> URL
    ) -> FileOperation {
        FileOperation(id: "tools.\(id)", title: title, subtitle: "All files", symbol: symbol, wheel: .tools, verb: verb) { urls, context in
            OperationOutcome(outputs: [try await body(urls, context)])
        }
    }
}

public extension FileCategory {
    var symbol: String {
        switch self {
        case .image: "photo"
        case .video: "film"
        case .audio: "waveform"
        case .pdf: "doc.richtext"
        case .document: "doc.text"
        case .ebook: "book"
        case .presentation: "rectangle.on.rectangle"
        case .spreadsheet: "tablecells"
        case .subtitle: "captions.bubble"
        case .archive: "archivebox"
        case .folder: "folder"
        case .other: "doc"
        }
    }
}
