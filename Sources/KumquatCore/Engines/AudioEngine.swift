import Accelerate
import AVFoundation
import Foundation

/// Audio work through Core Audio: decoding nearly anything, encoding AAC, ALAC, FLAC, WAV and AIFF.
public enum AudioEngine {
    public enum Encoding: Sendable {
        case wav, aiff, flac, alac
        case aac(bitRate: Int)

        var fileExtension: String {
            switch self {
            case .wav: "wav"
            case .aiff: "aiff"
            case .flac: "flac"
            case .alac, .aac: "m4a"
            }
        }

        var settings: [String: Any] {
            switch self {
            case .wav, .aiff:
                return [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: isBigEndian,
                    AVLinearPCMIsNonInterleaved: false,
                ]
            case .flac:
                return [AVFormatIDKey: kAudioFormatFLAC, AVEncoderBitDepthHintKey: 16]
            case .alac:
                return [AVFormatIDKey: kAudioFormatAppleLossless, AVEncoderBitDepthHintKey: 16]
            case .aac(let bitRate):
                return [AVFormatIDKey: kAudioFormatMPEG4AAC, AVEncoderBitRateKey: bitRate]
            }
        }

        private var isBigEndian: Bool {
            if case .aiff = self { return true }
            return false
        }
    }

    public static func convert(_ url: URL, to format: FileFormat, context: OperationContext) async throws -> URL {
        switch format {
        case .m4a:
            let output = context.destination(for: url, extension: "m4a")
            try await VideoEngine.export(AVURLAsset(url: url), preset: AVAssetExportPresetAppleM4A, as: .m4a, to: output)
            return output
        case .wav: return try encode(url, .wav, context: context)
        case .aiff: return try encode(url, .aiff, context: context)
        case .flac: return try encode(url, .flac, context: context)
        default: throw OperationError.unsupported(format.displayName)
        }
    }

    public static func encode(_ url: URL, _ encoding: Encoding, channels: AVAudioChannelCount? = nil, suffix: String? = nil, context: OperationContext) throws -> URL {
        let output = context.destination(for: url, extension: encoding.fileExtension, suffix: suffix)
        do {
            try transcode(url, to: output, settings: encoding.settings, channels: channels)
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        return output
    }

    public static func compress(_ url: URL, context: OperationContext) throws -> URL {
        let output = try encode(url, .aac(bitRate: 96_000), suffix: "compressed", context: context)
        return try keepIfSmaller(output, than: url)
    }

    /// Keeps lossless files lossless; everything else becomes AAC.
    static func encoding(matching url: URL) -> Encoding {
        switch FileFormat.detect(url) {
        case .wav: .wav
        case .aiff: .aiff
        case .flac: .flac
        default: .aac(bitRate: 192_000)
        }
    }

    public static func mono(_ url: URL, context: OperationContext) throws -> URL {
        try encode(url, encoding(matching: url), channels: 1, suffix: "mono", context: context)
    }

    /// Raises the volume so the loudest peak sits just under full scale.
    public static func normalize(_ url: URL, context: OperationContext) throws -> URL {
        let source = try AVAudioFile(forReading: url)
        var peak: Float = 0
        try forEachBuffer(of: source) { buffer, _ in
            for channel in 0..<Int(buffer.format.channelCount) {
                guard let samples = buffer.floatChannelData?[channel] else { continue }
                var channelPeak: Float = 0
                vDSP_maxmgv(samples, 1, &channelPeak, vDSP_Length(buffer.frameLength))
                peak = max(peak, channelPeak)
            }
        }
        guard peak > 0.0001 else { throw OperationError.failed("The audio is silent.") }
        let gain = 0.98 / peak
        guard abs(gain - 1) > 0.01 else { throw OperationError.failed("The audio is already as loud as it gets.") }
        return try rewrite(url, suffix: "normalized", context: context) { buffer in
            var scale = gain
            for channel in 0..<Int(buffer.format.channelCount) {
                guard let samples = buffer.floatChannelData?[channel] else { continue }
                vDSP_vsmul(samples, 1, &scale, samples, 1, vDSP_Length(buffer.frameLength))
            }
        }
    }

    /// Cuts the silence off the start and the end.
    public static func trimSilence(_ url: URL, threshold: Float = 0.01, context: OperationContext) throws -> URL {
        let source = try AVAudioFile(forReading: url)
        var first: AVAudioFramePosition?
        var last: AVAudioFramePosition = 0
        try forEachBuffer(of: source) { buffer, start in
            for frame in 0..<Int(buffer.frameLength) {
                var loud = false
                for channel in 0..<Int(buffer.format.channelCount) where abs(buffer.floatChannelData?[channel][frame] ?? 0) > threshold {
                    loud = true
                }
                if loud {
                    if first == nil { first = start + AVAudioFramePosition(frame) }
                    last = start + AVAudioFramePosition(frame)
                }
            }
        }
        guard let first else { throw OperationError.failed("The audio is silent.") }
        // Keep a breath of silence on both sides so the cut doesn't sound abrupt.
        let pad = AVAudioFramePosition(source.processingFormat.sampleRate * 0.05)
        let start = max(0, first - pad)
        let end = min(source.length, last + pad + 1)
        guard start > 0 || end < source.length else { throw OperationError.failed("There's no silence to trim.") }
        let output = context.destination(for: url, extension: encoding(matching: url).fileExtension, suffix: "trimmed")
        try copyFrames(of: url, range: start..<end, to: output, settings: encoding(matching: url).settings)
        return output
    }

    /// Cuts the audio into parts of a minute each, keeping the original quality where it's lossless.
    public static func split(_ url: URL, every seconds: Double = 60, context: OperationContext) throws -> URL {
        let source = try AVAudioFile(forReading: url)
        let partLength = AVAudioFramePosition(source.processingFormat.sampleRate * seconds)
        guard source.length > partLength else {
            throw OperationError.failed("The audio is shorter than \(Int(seconds)) seconds.")
        }
        let target = encoding(matching: url)
        let folder = context.folderDestination(for: url, suffix: "parts")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let count = Int((Double(source.length) / Double(partLength)).rounded(.up))
        let digits = String(count).count
        for index in 0..<count {
            let start = AVAudioFramePosition(index) * partLength
            let end = min(source.length, start + partLength)
            let name = "\(url.baseName) \(String(index + 1).leftPadded(to: digits)).\(target.fileExtension)"
            try copyFrames(of: url, range: start..<end, to: folder.appendingPathComponent(name), settings: target.settings)
        }
        return folder
    }

    /// Reads the whole file in its processing format (32-bit float), passing each buffer and its first frame.
    static func forEachBuffer(of source: AVAudioFile, _ body: (AVAudioPCMBuffer, AVAudioFramePosition) throws -> Void) throws {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: 32_768) else {
            throw OperationError.failed("Out of memory.")
        }
        source.framePosition = 0
        while source.framePosition < source.length {
            let start = source.framePosition
            try source.read(into: buffer)
            if buffer.frameLength == 0 { break }
            try body(buffer, start)
        }
    }

    /// Writes a copy of the file with every buffer passed through `process`.
    static func rewrite(_ url: URL, suffix: String, context: OperationContext, _ process: (AVAudioPCMBuffer) -> Void) throws -> URL {
        let target = encoding(matching: url)
        let output = context.destination(for: url, extension: target.fileExtension, suffix: suffix)
        do {
            let source = try AVAudioFile(forReading: url)
            let destination = try makeDestination(output, like: source, settings: target.settings)
            try forEachBuffer(of: source) { buffer, _ in
                process(buffer)
                try destination.write(from: buffer)
            }
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        return output
    }

    /// Copies the frames in `range` into a new file.
    static func copyFrames(of url: URL, range: Range<AVAudioFramePosition>, to output: URL, settings: [String: Any]) throws {
        do {
            let source = try AVAudioFile(forReading: url)
            let destination = try makeDestination(output, like: source, settings: settings)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: source.processingFormat, frameCapacity: 32_768) else {
                throw OperationError.failed("Out of memory.")
            }
            source.framePosition = range.lowerBound
            while source.framePosition < range.upperBound {
                let remaining = AVAudioFrameCount(range.upperBound - source.framePosition)
                try source.read(into: buffer, frameCount: min(buffer.frameCapacity, remaining))
                if buffer.frameLength == 0 { break }
                try destination.write(from: buffer)
            }
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }

    /// A file that takes buffers in the source's processing format and encodes them with `settings`.
    static func makeDestination(_ output: URL, like source: AVAudioFile, settings: [String: Any]) throws -> AVAudioFile {
        var settings = settings
        settings[AVSampleRateKey] = source.processingFormat.sampleRate
        settings[AVNumberOfChannelsKey] = source.processingFormat.channelCount
        return try AVAudioFile(forWriting: output, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    }

    public static func merge(_ urls: [URL], context: OperationContext) async throws -> URL {
        let composition = AVMutableComposition()
        let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        var cursor = CMTime.zero
        for url in urls {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            if let source = try await asset.loadTracks(withMediaType: .audio).first {
                try track?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: cursor)
            }
            cursor = cursor + duration
        }
        let output = context.destination(for: urls[0], name: "Merged audio", extension: "m4a")
        try await VideoEngine.export(composition, preset: AVAssetExportPresetAppleM4A, as: .m4a, to: output)
        return output
    }

    /// Streams audio from `input` into a new file, converting channels and sample format on the way.
    static func transcode(_ input: URL, to output: URL, settings: [String: Any], channels: AVAudioChannelCount? = nil) throws {
        let source = try AVAudioFile(forReading: input)
        let inputFormat = source.processingFormat
        var settings = settings
        settings[AVSampleRateKey] = inputFormat.sampleRate
        settings[AVNumberOfChannelsKey] = channels ?? inputFormat.channelCount
        let destination = try AVAudioFile(forWriting: output, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let outputFormat = destination.processingFormat
        let capacity: AVAudioFrameCount = 32_768

        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: capacity) else {
            throw OperationError.failed("Out of memory.")
        }

        if inputFormat == outputFormat {
            while source.framePosition < source.length {
                try source.read(into: inputBuffer)
                if inputBuffer.frameLength == 0 { break }
                try destination.write(from: inputBuffer)
                WorkProgress.report(Int(source.framePosition), of: Int(source.length))
            }
            return
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat),
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity * 2)
        else { throw OperationError.failed("Can't convert this audio.") }
        converter.downmix = true

        var finished = false
        var readError: Error?
        while true {
            var conversionError: NSError?
            outputBuffer.frameLength = 0
            let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
                if finished || source.framePosition >= source.length {
                    finished = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                do {
                    try source.read(into: inputBuffer)
                } catch {
                    readError = error
                    finished = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                if inputBuffer.frameLength == 0 {
                    finished = true
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inputStatus.pointee = .haveData
                return inputBuffer
            }
            if let conversionError { throw conversionError }
            if let readError { throw readError }
            if outputBuffer.frameLength > 0 { try destination.write(from: outputBuffer) }
            WorkProgress.report(Int(source.framePosition), of: Int(source.length))
            if status == .endOfStream || status == .error { break }
        }
    }
}
