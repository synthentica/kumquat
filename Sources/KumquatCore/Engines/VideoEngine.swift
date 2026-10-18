import AVFoundation
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Video work through AVFoundation, which uses the Mac's media engines.
public enum VideoEngine {
    static func fileType(for format: FileFormat) -> AVFileType {
        switch format {
        case .mov: .mov
        case .m4v: .m4v
        case .m4a: .m4a
        default: .mp4
        }
    }

    static func export(_ asset: AVAsset, preset: String, as fileType: AVFileType, to output: URL) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw OperationError.failed("This video can't be exported.")
        }
        guard session.supportedFileTypes.contains(fileType) else {
            throw OperationError.unsupported("\(fileType.rawValue) for this video")
        }
        session.outputURL = output
        session.outputFileType = fileType
        session.shouldOptimizeForNetworkUse = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        switch session.status {
        case .completed:
            return
        case .cancelled:
            try? FileManager.default.removeItem(at: output)
            throw CancellationError()
        default:
            try? FileManager.default.removeItem(at: output)
            throw session.error ?? OperationError.failed("The export failed.")
        }
    }

    /// Tries a lossless, near-instant remux first and re-encodes only when that isn't possible.
    static func exportFast(_ asset: AVAsset, as fileType: AVFileType, to output: URL) async throws {
        do {
            try await export(asset, preset: AVAssetExportPresetPassthrough, as: fileType, to: output)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try await export(asset, preset: AVAssetExportPresetHighestQuality, as: fileType, to: output)
        }
    }

    public static func convert(_ url: URL, to format: FileFormat, context: OperationContext) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let output = context.destination(for: url, extension: format.primaryExtension)
        switch format {
        case .mp4, .mov, .m4v:
            try await exportFast(asset, as: fileType(for: format), to: output)
        case .m4a:
            try await export(asset, preset: AVAssetExportPresetAppleM4A, as: .m4a, to: output)
        case .gif:
            try await makeGIF(from: asset, to: output)
        default:
            throw OperationError.unsupported(format.displayName)
        }
        return output
    }

    public static func hevc(_ url: URL, context: OperationContext) async throws -> URL {
        let output = context.destination(for: url, extension: "mp4", suffix: "HEVC")
        try await export(AVURLAsset(url: url), preset: AVAssetExportPresetHEVCHighestQuality, as: .mp4, to: output)
        return output
    }

    public static func compress(_ url: URL, context: OperationContext) async throws -> URL {
        let output = context.destination(for: url, extension: "mp4", suffix: "compressed")
        try await export(AVURLAsset(url: url), preset: AVAssetExportPresetHEVC1920x1080, as: .mp4, to: output)
        return try keepIfSmaller(output, than: url)
    }

    public static func resize720(_ url: URL, context: OperationContext) async throws -> URL {
        let output = context.destination(for: url, extension: "mp4", suffix: "720p")
        try await export(AVURLAsset(url: url), preset: AVAssetExportPreset1280x720, as: .mp4, to: output)
        return output
    }

    public static func removeAudio(_ url: URL, context: OperationContext) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let composition = AVMutableComposition()
        for track in try await asset.loadTracks(withMediaType: .video) {
            guard let target = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { continue }
            try target.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: track, at: .zero)
            target.preferredTransform = try await track.load(.preferredTransform)
        }
        let format = FileFormat.detect(url) == .mov ? FileFormat.mov : .mp4
        let output = context.destination(for: url, extension: format.primaryExtension, suffix: "muted")
        try await exportFast(composition, as: fileType(for: format), to: output)
        return output
    }

    public static func snapshot(_ url: URL, context: OperationContext) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: duration.isFinite ? min(duration * 0.1, 3) : 0, preferredTimescale: 600)
        let (image, _) = try await generator.image(at: time)
        let output = context.destination(for: url, extension: "png")
        try ImageEngine.write(image, to: output, format: .png, quality: 1)
        return output
    }

    /// Joins clips end to end, in the order given.
    public static func merge(_ urls: [URL], context: OperationContext) async throws -> URL {
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        var cursor = CMTime.zero
        for (index, url) in urls.enumerated() {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            let range = CMTimeRange(start: .zero, duration: duration)
            if let source = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack?.insertTimeRange(range, of: source, at: cursor)
                if index == 0 { videoTrack?.preferredTransform = try await source.load(.preferredTransform) }
            }
            if let source = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack?.insertTimeRange(range, of: source, at: cursor)
            }
            cursor = cursor + duration
        }
        let output = context.destination(for: urls[0], name: "Merged video", extension: "mp4")
        try await export(composition, preset: AVAssetExportPresetHighestQuality, as: .mp4, to: output)
        return output
    }

    /// A looping GIF of up to the first 30 seconds, 480 px wide at 12 fps.
    static func makeGIF(from asset: AVAsset, to output: URL, fps: Double = 12, maxSide: CGFloat = 480) async throws {
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0 else { throw OperationError.failed("The video has no frames.") }
        let length = min(duration, 30)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxSide, height: maxSide)
        let tolerance = CMTime(seconds: 0.5 / fps, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance

        let count = max(1, Int(length * fps))
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.gif.identifier as CFString, count, nil) else {
            throw OperationError.failed("Couldn't create the GIF.")
        }
        let loop = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(destination, loop as CFDictionary)
        let frame = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]]
        for index in 0..<count {
            try Task.checkCancellation()
            let time = CMTime(seconds: Double(index) / fps, preferredTimescale: 600)
            let (image, _) = try await generator.image(at: time)
            CGImageDestinationAddImage(destination, image, frame as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: output)
            throw OperationError.failed("Couldn't write the GIF.")
        }
    }
}
