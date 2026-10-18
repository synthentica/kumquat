import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// What "fast and light" means, in numbers. Every number Kumquat is measured against lives here,
/// so the benchmark, the tests and docs/performance.md all agree.
public struct Budget: Sendable {
    public let id: String
    public let title: String
    public let unit: String
    /// The value may not be above this.
    public let limit: Double

    public static let wheelOpenMedian = Budget(id: "wheel_open_median_ms", title: "Wheel opens (median)", unit: "ms", limit: 16)
    public static let wheelOpenP95 = Budget(id: "wheel_open_p95_ms", title: "Wheel opens (95th percentile)", unit: "ms", limit: 50)
    public static let wheelOpenFirst = Budget(id: "wheel_open_first_ms", title: "Wheel opens the first time", unit: "ms", limit: 50)
    public static let firstFeedbackP95 = Budget(id: "first_feedback_p95_ms", title: "Feedback after a drop (95th percentile)", unit: "ms", limit: 100)
    public static let idleCPU = Budget(id: "idle_cpu_percent", title: "Processor use while idle", unit: "%", limit: 0.1)
    public static let idleMemory = Budget(id: "idle_memory_mb", title: "Memory while idle", unit: "MB", limit: 40)
    public static let photoToJPEG = Budget(id: "photo_12mp_to_jpeg_ms", title: "12 MP photo to JPEG", unit: "ms", limit: 250)
    public static let pdfPages = Budget(id: "pdf_20_pages_to_png_ms", title: "20 PDF pages to PNG at 300 DPI", unit: "ms", limit: 3000)
    public static let audioToFLAC = Budget(id: "audio_3min_to_flac_ms", title: "3 minutes of audio to FLAC", unit: "ms", limit: 1500)
    public static let videoRemux = Budget(id: "video_1080p_10s_to_mp4_ms", title: "10 s 1080p MOV to MP4", unit: "ms", limit: 500)

    public static let all: [Budget] = [
        wheelOpenMedian, wheelOpenP95, wheelOpenFirst, firstFeedbackP95, idleCPU, idleMemory,
        photoToJPEG, pdfPages, audioToFLAC, videoRemux,
    ]
}

/// One measured value against its budget.
public struct BudgetResult: Codable, Sendable {
    public let id: String
    public let title: String
    public let unit: String
    public let value: Double
    public let limit: Double
    public var pass: Bool { value <= limit }

    public init(_ budget: Budget, _ value: Double) {
        id = budget.id
        title = budget.title
        unit = budget.unit
        self.value = value
        limit = budget.limit
    }

    enum CodingKeys: String, CodingKey { case id, title, unit, value, limit, pass }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(unit, forKey: .unit)
        try container.encode((value * 100).rounded() / 100, forKey: .value)
        try container.encode(limit, forKey: .limit)
        try container.encode(pass, forKey: .pass)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        unit = try container.decode(String.self, forKey: .unit)
        value = try container.decode(Double.self, forKey: .value)
        limit = try container.decode(Double.self, forKey: .limit)
    }
}

public enum Stats {
    public static func median(_ values: [Double]) -> Double { percentile(values, 0.5) }

    public static func percentile(_ values: [Double], _ p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let rank = p * Double(sorted.count - 1)
        let low = Int(rank.rounded(.down))
        let high = Int(rank.rounded(.up))
        return sorted[low] + (sorted[high] - sorted[low]) * (rank - Double(low))
    }

    /// Milliseconds `body` takes, median of `runs`.
    public static func milliseconds(runs: Int, _ body: () async throws -> Void) async rethrows -> Double {
        var samples: [Double] = []
        for _ in 0..<runs {
            let start = DispatchTime.now().uptimeNanoseconds
            try await body()
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6)
        }
        return median(samples)
    }
}

/// The conversion half of the benchmark: realistic files made on the spot, each converted a few times.
public enum ConversionBenchmark {
    public static func run(in directory: URL) async throws -> [BudgetResult] {
        let context = OperationContext(outputDirectory: directory.appendingPathComponent("out", isDirectory: true))
        try FileManager.default.createDirectory(at: context.outputDirectory!, withIntermediateDirectories: true)

        let photo = try Fixtures.photo(in: directory)
        let photoMS = try await Stats.milliseconds(runs: 5) { _ = try ImageEngine.convert(photo, to: .jpeg, context: context) }

        let pdf = try Fixtures.pdf(pages: 20, in: directory)
        let pdfMS = try await Stats.milliseconds(runs: 3) { _ = try PDFEngine.renderPages(pdf, as: .png, context: context) }

        let wav = try Fixtures.wav(seconds: 180, in: directory)
        let flacMS = try await Stats.milliseconds(runs: 3) { _ = try AudioEngine.encode(wav, .flac, context: context) }

        let mov = try await Fixtures.video(seconds: 10, in: directory)
        let mp4MS = try await Stats.milliseconds(runs: 3) { _ = try await VideoEngine.convert(mov, to: .mp4, context: context) }

        return [
            BudgetResult(.photoToJPEG, photoMS),
            BudgetResult(.pdfPages, pdfMS),
            BudgetResult(.audioToFLAC, flacMS),
            BudgetResult(.videoRemux, mp4MS),
        ]
    }
}

/// Files with the size and shape of real ones: a phone photo, a document, a song, a clip.
public enum Fixtures {
    /// A 4032 × 3024 photo-like PNG with gradients and detail, so encoders can't take shortcuts.
    public static func photo(in directory: URL) throws -> URL {
        let width = 4032, height = 3024
        guard let context = ImageEngine.makeContext(width: width, height: height, alpha: false) else {
            throw OperationError.failed("Couldn't make the photo.")
        }
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [CGColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 1), CGColor(red: 0.1, green: 0.35, blue: 0.25, alpha: 1)]
        if let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        }
        var seed: UInt64 = 42
        for _ in 0..<4_000 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let x = Double(seed >> 40 & 0xFFF) / 4096 * Double(width)
            let y = Double(seed >> 20 & 0xFFF) / 4096 * Double(height)
            let size = Double(seed & 0x3F) + 4
            context.setFillColor(CGColor(red: Double(seed >> 8 & 0xFF) / 255, green: Double(seed >> 16 & 0xFF) / 255, blue: Double(seed >> 24 & 0xFF) / 255, alpha: 0.6))
            context.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }
        let url = directory.appendingPathComponent("photo.png")
        try ImageEngine.write(context.makeImage()!, to: url, format: .png, quality: 1)
        return url
    }

    /// A text-heavy US Letter PDF with the given number of pages.
    public static func pdf(pages: Int, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("document \(pages).pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { throw OperationError.failed("Couldn't make the PDF.") }
        for page in 0..<pages {
            pdf.beginPage(mediaBox: &box)
            pdf.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1))
            for line in 0..<48 {
                let width = 380 + Double((page * 31 + line * 17) % 120)
                pdf.fill(CGRect(x: 72, y: 720 - Double(line) * 13, width: width, height: 6))
            }
            pdf.setFillColor(CGColor(red: 0.95, green: 0.55, blue: 0.1, alpha: 1))
            pdf.fillEllipse(in: CGRect(x: 420, y: 80, width: 120, height: 120))
            pdf.endPage()
        }
        pdf.closePDF()
        return url
    }

    /// A stereo 44.1 kHz WAV with a changing tone.
    public static func wav(seconds: Double, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("song.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let file = try AVAudioFile(forWriting: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
            AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 2,
        ], commonFormat: .pcmFormatFloat32, interleaved: false)
        let chunk: AVAudioFrameCount = 44_100
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunk)!
        buffer.frameLength = chunk
        for second in 0..<Int(seconds) {
            let pitch = 220 + Double(second % 12) * 30
            for channel in 0..<2 {
                let samples = buffer.floatChannelData![channel]
                for frame in 0..<Int(chunk) {
                    samples[frame] = Float(sin(Double(frame) / 44_100 * 2 * .pi * pitch) * 0.4)
                }
            }
            try file.write(from: buffer)
        }
        return url
    }

    /// A 1080p H.264 QuickTime movie at 30 frames a second.
    public static func video(seconds: Int, in directory: URL) async throws -> URL {
        let url = directory.appendingPathComponent("clip.mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1920, AVVideoHeightKey: 1080,
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 1920, kCVPixelBufferHeightKey as String: 1080,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? OperationError.failed("Couldn't make the clip.") }
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<(seconds * 30) {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            guard let pool = adaptor.pixelBufferPool else { break }
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { continue }
            CVPixelBufferLockBaseAddress(buffer, [])
            let base = CVPixelBufferGetBaseAddress(buffer)!
            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            for row in 0..<1080 {
                memset(base + row * bytesPerRow, Int32((row + frame * 4) & 0xFF), bytesPerRow)
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? OperationError.failed("Couldn't make the clip.") }
        return url
    }
}
