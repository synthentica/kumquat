import AppKit
import AVFoundation
import PDFKit
import XCTest
@testable import KumquatCore

final class FormatTests: XCTestCase {
    func testDetection() {
        XCTAssertEqual(FileFormat.detect(URL(fileURLWithPath: "/a/photo.JPG")), .jpeg)
        XCTAssertEqual(FileFormat.detect(URL(fileURLWithPath: "/a/archive.tar.gz")), .tgz)
        XCTAssertEqual(URL(fileURLWithPath: "/a/archive.tar.gz").baseName, "archive")
        XCTAssertEqual(FileFormat.detect(URL(fileURLWithPath: "/a/notes.md")), .markdown)
        XCTAssertNil(FileFormat.detect(URL(fileURLWithPath: "/a/unknown.xyz")))
    }

    func testUniqueNames() throws {
        let dir = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let input = dir.appendingPathComponent("photo.jpg")
        try Data().write(to: dir.appendingPathComponent("photo.png"))
        let context = OperationContext()
        let first = context.destination(for: input, extension: "png")
        let second = context.destination(for: input, extension: "png")
        XCTAssertEqual(first.lastPathComponent, "photo 2.png")
        XCTAssertEqual(second.lastPathComponent, "photo 3.png")
    }

    func testCatalogOffersImageTargets() {
        let ops = OperationCatalog.operations(for: [URL(fileURLWithPath: "/tmp/a.heic")], wheel: .convert, context: OperationContext())
        let ids = ops.map(\.id)
        XCTAssertTrue(ids.contains("convert.png"))
        XCTAssertTrue(ids.contains("convert.jpeg"))
        XCTAssertFalse(ids.contains("convert.heic"))
        XCTAssertTrue(ids.contains("convert.pdf"))
    }
}

final class TextFormatTests: XCTestCase {
    func testCSVRoundTrip() {
        let rows = [["name", "note"], ["Ada", "said \"hi\", then left"], ["Bo", "line\nbreak"]]
        let text = CSV.write(rows)
        XCTAssertEqual(CSV.parse(text), rows)
        XCTAssertEqual(CSV.parse("a;b\r\n1;2\r\n", delimiter: ";"), [["a", "b"], ["1", "2"]])
        XCTAssertEqual(Spreadsheet.guessDelimiter("a;b;c\n1;2;3"), ";")
    }

    func testSubtitles() {
        let srt = """
        1
        00:00:01,000 --> 00:00:02,500
        Hello

        2
        00:01:02,250 --> 00:01:04,000
        <i>World</i>
        """
        let cues = Subtitles.parse(srt)
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[1].start, 62.25, accuracy: 0.001)
        let vtt = Subtitles.vtt(cues)
        XCTAssertTrue(vtt.hasPrefix("WEBVTT"))
        XCTAssertTrue(vtt.contains("00:01:02.250 --> 00:01:04.000"))
        XCTAssertEqual(Subtitles.parse(vtt), cues)
        XCTAssertEqual(Subtitles.plainText(cues), "Hello\nWorld\n")
    }

    func testMarkdownToXHTML() {
        let html = Markdown.xhtml(from: """
        # Title

        Some **bold** and *italic* with `code <x>` and [a link](https://example.com).

        - one
        - two

        | A | B |
        |---|---|
        | 1 | 2 |
        """)
        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<em>italic</em>"))
        XCTAssertTrue(html.contains("<code>code &lt;x&gt;</code>"))
        XCTAssertTrue(html.contains("<a href=\"https://example.com\">a link</a>"))
        XCTAssertTrue(html.contains("<ul>\n<li>one</li>\n<li>two</li>\n</ul>"))
        XCTAssertTrue(html.contains("<td>2</td>"))
    }

    func testMarkdownWriter() {
        let text = NSMutableAttributedString(string: "Heading\n", attributes: [.font: NSFont.boldSystemFont(ofSize: 24)])
        text.append(NSAttributedString(string: "Plain ", attributes: [.font: NSFont.systemFont(ofSize: 12)]))
        text.append(NSAttributedString(string: "strong", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]))
        text.append(NSAttributedString(string: " text.", attributes: [.font: NSFont.systemFont(ofSize: 12)]))
        XCTAssertEqual(MarkdownWriter.markdown(from: text), "# Heading\n\nPlain **strong** text.\n")
    }

    func testXLSXRoundTrip() async throws {
        let dir = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sheet.xlsx")
        let rows = [["City", "Zip", "Population"], ["Helsinki", "00100", "674500"], ["Åbo & Turku", "", "1.5"]]
        try await XLSX.write(rows, to: url)
        let back = try await XLSX.read(url)
        XCTAssertEqual(back, rows)
        XCTAssertEqual(XLSX.columnName(27), "AB")
        XCTAssertEqual(XLSX.columnIndex("AB12"), 27)
    }

    func testJSON() {
        let json = Spreadsheet.json([["a", "b"], ["1", "x\"y"]])
        XCTAssertTrue(json.contains("\"a\": 1"))
        XCTAssertTrue(json.contains("\"b\": \"x\\\"y\""))
    }
}

final class EngineTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = try FileManager.default.makeTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    var context: OperationContext { OperationContext(outputDirectory: dir) }

    func makePNG(width: Int = 40, height: Int = 20) throws -> URL {
        let ctx = ImageEngine.makeContext(width: width, height: height, alpha: true)!
        ctx.setFillColor(CGColor(red: 1, green: 0.5, blue: 0, alpha: 0.5))
        ctx.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        let url = dir.appendingPathComponent("image.png")
        try ImageEngine.write(ctx.makeImage()!, to: url, format: .png, quality: 1)
        return url
    }

    func pixelSize(_ url: URL) -> (Int, Int) {
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        return (image.width, image.height)
    }

    func testImageConversionsAndEdits() throws {
        let png = try makePNG()
        let jpeg = try ImageEngine.convert(png, to: .jpeg, context: context)
        XCTAssertEqual(CGImageSourceGetType(CGImageSourceCreateWithURL(jpeg as CFURL, nil)!) as String?, "public.jpeg")
        XCTAssertTrue(pixelSize(try ImageEngine.edit(png, .rotate(clockwise: true), context: context)) == (20, 40))
        XCTAssertTrue(pixelSize(try ImageEngine.edit(png, .scale(0.5), context: context)) == (20, 10))
        _ = try ImageEngine.edit(png, .grayscale, context: context)
        _ = try ImageEngine.edit(png, .flipHorizontal, context: context)
        if ImageEngine.canWrite(.heic) {
            _ = try ImageEngine.convert(png, to: .heic, context: context)
        }
    }

    func testImagesToPDFAndBack() throws {
        let png = try makePNG()
        let pdfURL = dir.appendingPathComponent("two.pdf")
        try ImageEngine.makePDF(from: [png, png], to: pdfURL)
        XCTAssertEqual(PDFDocument(url: pdfURL)?.pageCount, 2)

        let pages = try PDFEngine.renderPages(pdfURL, as: .png, dpi: 144, context: context)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: pages.path).count, 2)

        let split = try PDFEngine.split(pdfURL, context: context)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: split.path).count, 2)
        let merged = try PDFEngine.merge([pdfURL, pdfURL], context: context)
        XCTAssertEqual(PDFDocument(url: merged)?.pageCount, 4)
        let rotated = try PDFEngine.rotate(pdfURL, context: context)
        XCTAssertEqual(PDFDocument(url: rotated)?.page(at: 0)?.rotation, 90)
    }

    func makeWAV(seconds: Double = 0.5) throws -> URL {
        let url = dir.appendingPathComponent("tone.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let file = try AVAudioFile(forWriting: url, settings: AudioEngine.Encoding.wav.settings.merging([
            AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2,
        ]) { $1 }, commonFormat: .pcmFormatFloat32, interleaved: false)
        let frames = AVAudioFrameCount(44_100 * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for channel in 0..<2 {
            for frame in 0..<Int(frames) {
                buffer.floatChannelData![channel][frame] = Float(sin(Double(frame) * 2 * .pi * 440 / 44_100) * 0.4)
            }
        }
        try file.write(from: buffer)
        return url
    }

    func testAudioEncodings() async throws {
        let wav = try makeWAV()
        for encoding in [AudioEngine.Encoding.flac, .aiff, .alac, .aac(bitRate: 128_000)] {
            let output = try AudioEngine.encode(wav, encoding, context: context)
            let file = try AVAudioFile(forReading: output)
            XCTAssertGreaterThan(file.length, 10_000, "\(encoding)")
        }
        let mono = try AudioEngine.mono(wav, context: context)
        XCTAssertEqual(try AVAudioFile(forReading: mono).fileFormat.channelCount, 1)
        let m4a = try await AudioEngine.convert(wav, to: .m4a, context: context)
        XCTAssertGreaterThan(try AVAudioFile(forReading: m4a).length, 10_000)
    }

    func makeVideo() async throws -> URL {
        let url = dir.appendingPathComponent("clip.mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 160, AVVideoHeightKey: 120,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 160, kCVPixelBufferHeightKey as String: 120,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            CVPixelBufferLockBaseAddress(buffer!, [])
            memset(CVPixelBufferGetBaseAddress(buffer!), Int32(frame * 8), CVPixelBufferGetDataSize(buffer!))
            CVPixelBufferUnlockBaseAddress(buffer!, [])
            adaptor.append(buffer!, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, writer.error?.localizedDescription ?? "")
        return url
    }

    func testVideo() async throws {
        let mp4 = try await makeVideo()
        let mov = try await VideoEngine.convert(mp4, to: .mov, context: context)
        XCTAssertTrue(FileManager.default.fileExists(atPath: mov.path))
        let gif = try await VideoEngine.convert(mp4, to: .gif, context: context)
        XCTAssertGreaterThan(CGImageSourceGetCount(CGImageSourceCreateWithURL(gif as CFURL, nil)!), 5)
        let snapshot = try await VideoEngine.snapshot(mp4, context: context)
        XCTAssertTrue(pixelSize(snapshot) == (160, 120))
        let muted = try await VideoEngine.removeAudio(mp4, context: context)
        XCTAssertTrue(FileManager.default.fileExists(atPath: muted.path))
    }

    func testDocuments() async throws {
        let rtf = dir.appendingPathComponent("note.rtf")
        let text = NSMutableAttributedString(string: "Hello ", attributes: [.font: NSFont.systemFont(ofSize: 12)])
        text.append(NSAttributedString(string: "world", attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]))
        try DocumentEngine.data(text, .rtf).write(to: rtf)

        let docx = try await DocumentEngine.convert(rtf, to: .docx, context: context)
        let back = try await DocumentEngine.read(docx)
        XCTAssertTrue(back.string.contains("Hello world"))

        let markdown = try await DocumentEngine.convert(docx, to: .markdown, context: context)
        XCTAssertTrue(try String(contentsOf: markdown).contains("**world**"))

        let html = try await DocumentEngine.convert(markdown, to: .html, context: context)
        XCTAssertTrue(try String(contentsOf: html).contains("<strong>world</strong>"))

        let epub = try await DocumentEngine.convert(markdown, to: .epub, context: context)
        let book = try await DocumentEngine.read(epub)
        XCTAssertTrue(book.string.contains("Hello world"))
    }

    @MainActor
    func testPrintToPDF() async throws {
        _ = NSApplication.shared
        let txt = dir.appendingPathComponent("long.txt")
        try String(repeating: "A line of text that fills the page.\n", count: 120).write(to: txt, atomically: true, encoding: .utf8)
        let pdf = try await DocumentEngine.convert(txt, to: .pdf, context: context)
        let document = try XCTUnwrap(PDFDocument(url: pdf))
        XCTAssertGreaterThan(document.pageCount, 1)
        XCTAssertTrue(document.string?.contains("fills the page") ?? false)
    }

    func testArchives() async throws {
        let folder = dir.appendingPathComponent("Stuff")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "hi".write(to: folder.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        for kind in [ArchiveEngine.Kind.zip, .tarGz] {
            let archive = try await ArchiveEngine.compress([folder], as: kind, context: context)
            let extracted = try await ArchiveEngine.extract(archive, context: context)
            XCTAssertEqual(try String(contentsOf: extracted.appendingPathComponent("a.txt")), "hi")
        }
    }
}
