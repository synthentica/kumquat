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

    public static func mono(_ url: URL, context: OperationContext) throws -> URL {
        let format = FileFormat.detect(url)
        let encoding: Encoding
        switch format {
        case .wav: encoding = .wav
        case .aiff: encoding = .aiff
        case .flac: encoding = .flac
        default: encoding = .aac(bitRate: 128_000)
        }
        return try encode(url, encoding, channels: 1, suffix: "mono", context: context)
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
            if status == .endOfStream || status == .error { break }
        }
    }
}
