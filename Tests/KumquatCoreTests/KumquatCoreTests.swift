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
        XCTAssertEqual(URL(fileURLWithPath: "/a/deck.PPTX").fileCategory, .presentation)
        XCTAssertEqual(FileFormat.detect(URL(fileURLWithPath: "/a/Clip.textClipping")), .textClipping)
        XCTAssertEqual(URL(fileURLWithPath: "/a/budget.numbers").fileCategory, .spreadsheet)
        XCTAssertEqual(FileFormat.detect(URL(fileURLWithPath: "/a/star.avifs")), .avif)
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

    func testCatalogMatchesTangerine() {
        let context = OperationContext()
        let pdf = OperationCatalog.operations(for: [URL(fileURLWithPath: "/tmp/a.pdf")], wheel: .convert, context: context).map(\.id)
        XCTAssertTrue(pdf.contains("convert.pptx"))
        XCTAssertTrue(pdf.contains("convert.xlsx"))
        let sheet = OperationCatalog.operations(for: [URL(fileURLWithPath: "/tmp/a.csv")], wheel: .convert, context: context).map(\.id)
        XCTAssertTrue(sheet.contains("convert.ods"))
        let image = OperationCatalog.operations(for: [URL(fileURLWithPath: "/tmp/a.png")], wheel: .tools, context: context).map(\.id)
        for id in ["tools.square", "tools.trim", "tools.round", "tools.zip", "tools.gzip"] {
            XCTAssertTrue(image.contains(id), id)
        }
        let audio = OperationCatalog.operations(for: [URL(fileURLWithPath: "/tmp/a.wav")], wheel: .tools, context: context).map(\.id)
        for id in ["tools.normalize", "tools.trim", "tools.split"] {
            XCTAssertTrue(audio.contains(id), id)
        }
        let video = OperationCatalog.operations(for: [URL(fileURLWithPath: "/tmp/a.mov")], wheel: .tools, context: context).map(\.id)
        for id in ["tools.rotate", "tools.split", "tools.speed"] {
            XCTAssertTrue(video.contains(id), id)
        }
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

    func testODSRoundTrip() async throws {
        let dir = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sheet.ods")
        let rows = [["City", "Zip", "Population"], ["Helsinki", "00100", "674500"], ["Åbo & Turku", "", "1.5"]]
        try await ODS.write(rows, to: url)
        let back = try await ODS.read(url)
        XCTAssertEqual(back, rows)
    }

    /// Builds a tiny Excel 97 file: a Compound File with one Workbook stream of BIFF8 records.
    func makeXLS() -> Data {
        func le16(_ value: UInt16) -> [UInt8] { [UInt8(value & 0xFF), UInt8(value >> 8)] }
        func le32(_ value: UInt32) -> [UInt8] { le16(UInt16(value & 0xFFFF)) + le16(UInt16(value >> 16)) }
        func record(_ type: UInt16, _ body: [UInt8]) -> [UInt8] {
            le16(type) + le16(UInt16(body.count)) + body
        }
        func cell(_ row: UInt16, _ column: UInt16) -> [UInt8] { le16(row) + le16(column) + le16(0) }

        // "Helsinki" is split across the SST and a CONTINUE record, which repeats the flags byte.
        var strings: [UInt8] = le32(3) + le32(3)
        strings += le16(4)
        strings += [0]
        strings += Array("City".utf8)
        strings += le16(5)
        strings += [1]
        for unit in "Åbo!!".utf16 { strings += le16(unit) }
        strings += le16(8)
        strings += [0]
        strings += Array("Hels".utf8)
        let sst = record(0x00FC, strings)
        let continuation = record(0x003C, [UInt8(0)] + Array("inki".utf8))
        let bof = record(0x0809, le16(0x0600) + le16(0x0005) + [UInt8](repeating: 0, count: 12))
        let eof = record(0x000A, [])
        var globals = bof
        let sheetRecordIndex = globals.count
        let sheetName: [UInt8] = [0, 0, 5, 0] + Array("Sheet".utf8)
        globals += record(0x0085, le32(0) + sheetName)
        globals += sst + continuation + eof
        let sheetOffset = UInt32(globals.count)
        globals.replaceSubrange(sheetRecordIndex + 4..<sheetRecordIndex + 8, with: le32(sheetOffset))
        var number = 1.5.bitPattern
        let numberBytes = (0..<8).map { _ -> UInt8 in defer { number >>= 8 }; return UInt8(number & 0xFF) }
        var sheet = record(0x0809, le16(0x0600) + le16(0x0010) + [UInt8](repeating: 0, count: 12))
        sheet += record(0x00FD, cell(0, 0) + le32(0))
        sheet += record(0x00FD, cell(1, 0) + le32(2))
        sheet += record(0x00FD, cell(2, 0) + le32(1))
        sheet += record(0x027E, cell(1, 1) + le32(UInt32(674_500) << 2 | 0x02))
        sheet += record(0x0203, cell(2, 1) + numberBytes)
        sheet += eof
        var stream = globals + sheet
        stream += [UInt8](repeating: 0, count: max(0, 4_096 - stream.count))

        let sectors = (stream.count + 511) / 512
        stream += [UInt8](repeating: 0, count: sectors * 512 - stream.count)
        var header = [UInt8](repeating: 0, count: 512)
        header.replaceSubrange(0..<8, with: [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])
        func put(_ bytes: [UInt8], _ offset: Int) { header.replaceSubrange(offset..<offset + bytes.count, with: bytes) }
        put(le16(0x3E), 0x18); put(le16(3), 0x1A); put(le16(0xFFFE), 0x1C); put(le16(9), 0x1E); put(le16(6), 0x20)
        put(le32(1), 0x2C); put(le32(1), 0x30); put(le32(4_096), 0x38)
        put(le32(0xFFFF_FFFE), 0x3C); put(le32(0xFFFF_FFFE), 0x44)
        for index in 0..<109 { put(le32(index == 0 ? 0 : 0xFFFF_FFFF), 0x4C + index * 4) }
        // Sector 0 is the FAT, sector 1 the directory, then the workbook.
        var fat = le32(0xFFFF_FFFD) + le32(0xFFFF_FFFE)
        for index in 0..<sectors { fat += le32(index == sectors - 1 ? 0xFFFF_FFFE : UInt32(index + 3)) }
        fat += [UInt8](repeating: 0xFF, count: 512 - fat.count)
        func entry(_ name: String, type: UInt8, start: UInt32, size: UInt32) -> [UInt8] {
            var bytes = [UInt8](repeating: 0, count: 128)
            var units: [UInt8] = []
            for unit in name.utf16 { units += le16(unit) }
            units += [0, 0]
            bytes.replaceSubrange(0..<units.count, with: units)
            bytes.replaceSubrange(0x40..<0x42, with: le16(UInt16(units.count)))
            bytes[0x42] = type
            bytes.replaceSubrange(0x74..<0x78, with: le32(start))
            bytes.replaceSubrange(0x78..<0x7C, with: le32(size))
            return bytes
        }
        var directory = entry("Root Entry", type: 5, start: 0xFFFF_FFFE, size: 0)
            + entry("Workbook", type: 2, start: 2, size: UInt32(stream.count))
        directory += [UInt8](repeating: 0, count: 512 - directory.count)
        return Data(header + fat + directory + stream)
    }

    func testXLS() throws {
        let dir = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("old.xls")
        try makeXLS().write(to: url)
        XCTAssertEqual(try XLS.read(url), [["City", ""], ["Helsinki", "674500"], ["Åbo!!", "1.5"]])
        XCTAssertEqual(XLS.rk(UInt32(bitPattern: Int32(-12) << 2) | 0x03), -0.12, accuracy: 0.0001)
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

    func makeWAV(seconds: Double = 0.5, silence: Double = 0) throws -> URL {
        let url = dir.appendingPathComponent("tone \(seconds) \(silence).wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let file = try AVAudioFile(forWriting: url, settings: AudioEngine.Encoding.wav.settings.merging([
            AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2,
        ]) { $1 }, commonFormat: .pcmFormatFloat32, interleaved: false)
        let quiet = Int(44_100 * silence)
        let frames = AVAudioFrameCount(44_100 * seconds) + AVAudioFrameCount(quiet * 2)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for channel in 0..<2 {
            for frame in 0..<Int(frames) {
                let tone = frame >= quiet && frame < Int(frames) - quiet
                buffer.floatChannelData![channel][frame] = tone ? Float(sin(Double(frame) * 2 * .pi * 440 / 44_100) * 0.4) : 0
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

    func testAudioTools() throws {
        let wav = try makeWAV(seconds: 0.5, silence: 0.3)
        let original = try AVAudioFile(forReading: wav).length

        let normalized = try AudioEngine.normalize(wav, context: context)
        let file = try AVAudioFile(forReading: normalized)
        var peak: Float = 0
        try AudioEngine.forEachBuffer(of: file) { buffer, _ in
            for frame in 0..<Int(buffer.frameLength) { peak = max(peak, abs(buffer.floatChannelData![0][frame])) }
        }
        XCTAssertEqual(peak, 0.98, accuracy: 0.02)

        let trimmed = try AVAudioFile(forReading: try AudioEngine.trimSilence(wav, context: context)).length
        XCTAssertLessThan(trimmed, original - 20_000)
        XCTAssertGreaterThan(trimmed, 22_000)

        let parts = try AudioEngine.split(try makeWAV(seconds: 1.4), every: 0.5, context: context)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: parts.path).count, 3)
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

        let rotated = try await VideoEngine.rotate(mp4, context: context)
        let rotatedFrame = try await VideoEngine.snapshot(rotated, context: context)
        XCTAssertTrue(pixelSize(rotatedFrame) == (120, 160))
        let parts = try await VideoEngine.split(mp4, every: 0.4, context: context)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: parts.path).count, 3)
        let fast = try await VideoEngine.speedUp(mp4, context: context)
        let duration = try await AVURLAsset(url: fast).load(.duration).seconds
        XCTAssertEqual(duration, 0.5, accuracy: 0.1)
    }

    /// Runs against the FFmpeg that ships in the app when CI provides it.
    func testBundledFFmpeg() async throws {
        guard let path = ProcessInfo.processInfo.environment["KUMQUAT_FFMPEG"], FileManager.default.isExecutableFile(atPath: path) else {
            throw XCTSkip("Set KUMQUAT_FFMPEG to the bundled FFmpeg to run this test.")
        }
        let context = OperationContext(outputDirectory: dir, ffmpeg: URL(fileURLWithPath: path))
        let wav = try makeWAV(seconds: 1)
        for format in [FileFormat.mp3, .ogg, .opus, .wma, .flac] {
            let output = try await FFmpegEngine.convert(wav, to: format, context: context)
            XCTAssertGreaterThan(FileManager.default.fileSize(output), 1_000, format.displayName)
        }
        let mp4 = try await makeVideo()
        for format in [FileFormat.webm, .mkv, .avi, .wmv, .mov] {
            let output = try await FFmpegEngine.convert(mp4, to: format, context: context)
            XCTAssertGreaterThan(FileManager.default.fileSize(output), 1_000, format.displayName)
        }
        let recorder = ProgressRecorder()
        let webm = try await WorkProgress.$sink.withValue(recorder.sink) {
            try await FFmpegEngine.convert(mp4, to: .webm, context: context)
        }
        XCTAssertGreaterThan(recorder.last, 0.9, "FFmpeg reports its progress")
        let back = try await FFmpegEngine.convert(webm, to: .mp4, context: context)
        let duration = try await AVURLAsset(url: back).load(.duration).seconds
        XCTAssertGreaterThan(duration, 0.5)
        let webp = try await FFmpegEngine.convert(try makePNG(), to: .webp, context: context)
        XCTAssertNotNil(CGImageSourceCreateWithURL(webp as CFURL, nil))
    }

    func testNewImageTools() throws {
        let png = try makePNG()
        XCTAssertTrue(pixelSize(try ImageEngine.edit(png, .squareCrop, context: context)) == (20, 20))
        XCTAssertTrue(pixelSize(try ImageEngine.edit(png, .trimEdges, context: context)) == (20, 20))
        let rounded = try ImageEngine.edit(png, .roundCorners, context: context)
        XCTAssertTrue(pixelSize(rounded) == (40, 20))
        let jpeg = try ImageEngine.convert(png, to: .jpeg, context: context)
        XCTAssertEqual(try ImageEngine.edit(jpeg, .roundCorners, context: context).pathExtension, "png")
    }

    func testPDFToSlidesAndTable() async throws {
        let png = try makePNG()
        let pdfURL = dir.appendingPathComponent("deck.pdf")
        try ImageEngine.makePDF(from: [png, png], to: pdfURL)
        let pptx = try await PPTX.fromPDF(pdfURL, context: context)
        let unpacked = dir.appendingPathComponent("unpacked")
        try await Zip.extract(pptx, to: unpacked)
        let parts = try XCTUnwrap(FileManager.default.subpaths(atPath: unpacked.path))
        XCTAssertTrue(parts.contains("ppt/slides/slide2.xml"))
        XCTAssertTrue(parts.contains("ppt/media/image2.jpeg"))
        for part in parts where part.hasSuffix(".xml") || part.hasSuffix(".rels") {
            XCTAssertNoThrow(try XMLDocument(contentsOf: unpacked.appendingPathComponent(part), options: []), part)
        }
        XCTAssertThrowsError(try PDFEngine.tableRows(pdfURL), "Image-only pages have no text")
    }

    func testPowerPointRendering() async throws {
        let png = try makePNG()
        let pdfURL = dir.appendingPathComponent("source.pdf")
        try ImageEngine.makePDF(from: [png, png, png], to: pdfURL)
        let pptx = try await PPTX.fromPDF(pdfURL, context: context)
        let rendered = try await PPTXRenderer.toPDF(pptx, context: context)
        let document = try XCTUnwrap(PDFDocument(url: rendered))
        XCTAssertEqual(document.pageCount, 3)
        // The picture fills the left of the slide with orange, so the page isn't blank.
        let page = try PDFEngine.render(try XCTUnwrap(document.page(at: 0)), dpi: 36)
        let context = ImageEngine.makeContext(width: page.width, height: page.height, alpha: true)!
        context.draw(page, in: CGRect(x: 0, y: 0, width: page.width, height: page.height))
        let pixels = context.data!.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * page.height)
        let middle = (page.height / 2) * context.bytesPerRow + (page.width / 4) * 4
        XCTAssertLessThan(pixels[middle + 2], 200, "expected orange, not white")
        let images = try await PPTXRenderer.slideImages(pptx, as: .png, context: self.context)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: images.path).count, 3)
    }

    func testTextClipping() async throws {
        let url = dir.appendingPathComponent("Snippet.textClipping")
        let plist: [String: Any] = ["UTI-Data": ["public.utf8-plain-text": "Hello from a clipping"]]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0).write(to: url)
        let text = try await DocumentEngine.read(url)
        XCTAssertEqual(text.string, "Hello from a clipping")
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
        let file = folder.appendingPathComponent("a.txt")
        let gzip = try await ArchiveEngine.compress([file], as: .gzip, context: context)
        XCTAssertEqual(gzip.lastPathComponent, "a.txt.gz")
        let unzipped = try await ArchiveEngine.extract(gzip, context: context)
        XCTAssertEqual(try String(contentsOf: unzipped), "hi")
    }

    func testProgressAndParallelPages() async throws {
        let png = try makePNG()
        let pdfURL = dir.appendingPathComponent("seven.pdf")
        try ImageEngine.makePDF(from: Array(repeating: png, count: 7), to: pdfURL)
        let recorder = ProgressRecorder()
        let pages = try WorkProgress.$sink.withValue(recorder.sink) {
            try PDFEngine.renderPages(pdfURL, as: .png, dpi: 72, context: context)
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: pages.path).sorted()
        XCTAssertEqual(names.count, 7)
        XCTAssertEqual(names.first, "seven 1.png")
        XCTAssertEqual(recorder.last, 1, accuracy: 0.001)

        // A batch adds up its files, never moving backwards.
        let wavs = try (0..<3).map { index -> URL in
            let url = dir.appendingPathComponent("tone \(index).wav")
            try FileManager.default.moveItem(at: try makeWAV(seconds: 1), to: url)
            return url
        }
        let operation = FileOperation.perFile(id: "test", title: "FLAC", symbol: "waveform", wheel: .convert, verb: "Encoding") {
            try AudioEngine.encode($0, .flac, context: $1)
        }
        let batch = ProgressRecorder()
        let outcome = try await WorkProgress.$sink.withValue(batch.sink) {
            try await operation.perform(wavs, context)
        }
        XCTAssertEqual(outcome.outputs.count, 3)
        XCTAssertEqual(batch.last, 1, accuracy: 0.001)
        XCTAssertEqual(batch.values, batch.values.sorted())
    }

    func testOutputChecks() async throws {
        let empty = dir.appendingPathComponent("empty.mp4")
        FileManager.default.createFile(atPath: empty.path, contents: Data())
        XCTAssertThrowsError(try OutputCheck.verify(empty))
        XCTAssertFalse(FileManager.default.fileExists(atPath: empty.path), "an empty result is removed")
        XCTAssertThrowsError(try OutputCheck.verify(dir.appendingPathComponent("never written.png")))

        // Six seconds of audio, and a "conversion" that came out half as long.
        let wav = try Fixtures.wav(seconds: 6, in: dir)
        let parts = try AudioEngine.split(wav, every: 3, context: context)
        let half = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: parts, includingPropertiesForKeys: nil).first)
        do {
            try await OutputCheck.verifyMedia(half, from: wav, ffmpeg: nil)
            XCTFail("a result half as long as the original passed")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("long"), error.localizedDescription)
        }
        let whole = try AudioEngine.encode(wav, .alac, context: context)
        try await OutputCheck.verifyMedia(whole, from: wav, ffmpeg: nil)
    }

    func testConversionsKeepTheOriginalsDates() async throws {
        let png = try makePNG()
        let then = Date(timeIntervalSince1970: 1_500_000_000)
        try FileManager.default.setAttributes([.creationDate: then, .modificationDate: then], ofItemAtPath: png.path)
        let operation = try XCTUnwrap(OperationCatalog.operations(for: [png], wheel: .convert, context: context).first { $0.id == "convert.jpeg" })
        let outcome = try await operation.perform([png], context)
        let output = try XCTUnwrap(outcome.outputs.first)
        let attributes = try FileManager.default.attributesOfItem(atPath: output.path)
        XCTAssertEqual((attributes[.modificationDate] as? Date)?.timeIntervalSince1970, then.timeIntervalSince1970)
        XCTAssertEqual((attributes[.creationDate] as? Date)?.timeIntervalSince1970, then.timeIntervalSince1970)
    }

    func testCancellingStopsTheTool() async throws {
        let started = Date()
        let task = Task { try await Shell.run("/bin/sleep", ["20"]) }
        try await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("a cancelled tool finished")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 3, "the tool kept running after the cancel")
    }

    func testCancellingStopsPageRendering() async throws {
        let pdf = try Fixtures.pdf(pages: 200, in: dir)
        let context = self.context
        let task = Task { try PDFEngine.renderPages(pdf, as: .png, context: context) }
        try await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("200 pages rendered despite the cancel")
        } catch {
            XCTAssertTrue(error is CancellationError, "\(error)")
        }
        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains("pages") }
        XCTAssertEqual(left, [], "half-rendered pages were left behind")
    }

    func testScannedPagesAreRead() throws {
        // Two pages that are only pictures of text: one upright, one scanned sideways.
        func scan(_ words: String, turned: Bool) -> CGImage {
            let width = 1700, height = 400
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            context.setFillColor(.white)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            // Core Text draws in black when no color is given.
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: words, attributes: [.font: NSFont.systemFont(ofSize: 96)]))
            context.textPosition = CGPoint(x: 40, y: 160)
            CTLineDraw(line, context)
            let image = context.makeImage()!
            guard turned else { return image }
            let sideways = CGContext(data: nil, width: height, height: width, bitsPerComponent: 8, bytesPerRow: 0,
                                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
            sideways.translateBy(x: CGFloat(height), y: 0)
            sideways.rotate(by: .pi / 2)
            sideways.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return sideways.makeImage()!
        }
        let url = dir.appendingPathComponent("scan.pdf")
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let pdf = CGContext(url as CFURL, mediaBox: &box, nil)!
        for (words, turned) in [("Kumquat reads scans", false), ("Sideways pages too", true)] {
            pdf.beginPage(mediaBox: &box)
            let image = scan(words, turned: turned)
            let scale = min(500 / CGFloat(image.width), 700 / CGFloat(image.height))
            pdf.draw(image, in: CGRect(x: 40, y: 80, width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale))
            pdf.endPage()
        }
        pdf.closePDF()

        let text = try PDFEngine.attributedText(url).string
        XCTAssertTrue(text.contains("Kumquat reads scans"), text)
        XCTAssertTrue(text.contains("Sideways pages too"), text)
    }

    func testLaneCapsConcurrency() async throws {
        let lane = Lane(limit: 2)
        let counter = ConcurrencyCounter()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<6 {
                group.addTask {
                    try await lane.run {
                        counter.enter()
                        try await Task.sleep(nanoseconds: 40_000_000)
                        counter.leave()
                    }
                }
            }
            try await group.waitForAll()
        }
        XCTAssertEqual(counter.peak, 2)
    }
}

/// Collects what an operation reports, from whichever thread it reports on.
final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [Double] = []

    var sink: @Sendable (Double) -> Void { { [self] value in lock.lock(); recorded.append(value); lock.unlock() } }
    var values: [Double] { lock.lock(); defer { lock.unlock() }; return recorded }
    var last: Double { values.last ?? 0 }
}

final class ConcurrencyCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var current = 0
    private(set) var peak = 0

    func enter() { lock.lock(); current += 1; peak = max(peak, current); lock.unlock() }
    func leave() { lock.lock(); current -= 1; lock.unlock() }
}

/// Time and memory for the work people do most, against the budgets in Budget.swift.
/// CI runners are slower and noisier than a Mac on a desk, so these fail only at twice the budget;
/// the exact comparison is `Kumquat --benchmark` on a real Mac (scripts/profile.sh).
final class PerformanceTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = try FileManager.default.makeTemporaryDirectory()
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testWheelLookupIsInstant() {
        let urls = ["png", "mp4", "mp3", "pdf", "docx", "pptx", "xlsx", "zip"].map { URL(fileURLWithPath: "/tmp/a.\($0)") }
        let context = OperationContext()
        OperationCatalog.prewarm(context: context)
        var samples: [Double] = []
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let start = DispatchTime.now().uptimeNanoseconds
            for url in urls {
                for wheel in [Wheel.convert, .tools] { _ = OperationCatalog.operations(for: [url], wheel: wheel, context: context) }
            }
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6 / Double(urls.count * 2))
        }
        // Looking up a wheel is part of opening it, so it gets a small slice of the 16 ms frame.
        XCTAssertLessThan(Stats.median(samples), 2, "ms per wheel lookup")
    }

    func testPhotoConversionPerformance() throws {
        let photo = try Fixtures.photo(in: dir)
        let context = OperationContext(outputDirectory: dir)
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = try? ImageEngine.convert(photo, to: .jpeg, context: context)
        }
    }

    func testConversionBudgets() async throws {
        let results = try await ConversionBenchmark.run(in: dir)
        XCTAssertEqual(results.count, 4)
        for result in results {
            print("\(result.title): \(String(format: "%.1f", result.value)) \(result.unit), budget \(result.limit)")
            XCTAssertLessThanOrEqual(result.value, result.limit * 2, result.title)
        }
    }
}
