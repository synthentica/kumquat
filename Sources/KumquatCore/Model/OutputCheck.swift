import AVFoundation
import Foundation

/// Looks at every result before Kumquat calls it done.
///
/// The most common complaint about other converters is a job that "finishes" with no file, an empty file,
/// or a video that lost its sound (research/complaints-summary.md, theme 3). A result that fails these checks
/// is removed and reported as an error instead.
enum OutputCheck {
    /// Basic checks for any result: it exists, and isn't empty.
    static func verify(_ output: URL) throws {
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: output.path, isDirectory: &isFolder) else {
            throw OperationError.failed("No file was written.")
        }
        if isFolder.boolValue {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: output.path)) ?? []
            if !items.contains(where: { !$0.hasPrefix(".") }) {
                discard(output)
                throw OperationError.failed("The result came out empty.")
            }
        } else if FileManager.default.fileSize(output) == 0 {
            discard(output)
            throw OperationError.failed("The result came out empty.")
        }
    }

    /// For conversions between audio and video: the result plays as long as the original and keeps its sound.
    static func verifyMedia(_ output: URL, from source: URL, ffmpeg: URL?) async throws {
        guard let target = FileFormat.detect(output), [.video, .audio].contains(target.category),
              let original = FileFormat.detect(source), [.video, .audio].contains(original.category)
        else { return }
        guard let result = await MediaInfo.read(output, ffmpeg: ffmpeg) else { return }
        func fail(_ message: String) throws -> Never {
            discard(output)
            throw OperationError.failed(message)
        }
        if let duration = result.duration, duration <= 0 { try fail("The result has no length.") }
        if target.category == .video, result.hasVideo == false { try fail("The result has no picture.") }
        if target.category == .audio, result.hasAudio == false { try fail("The result has no sound.") }
        guard let before = await MediaInfo.read(source, ffmpeg: ffmpeg) else { return }
        if before.hasAudio == true, result.hasAudio == false { try fail("The result lost its sound.") }
        if let length = before.duration, let made = result.duration, length > 1 {
            // Containers round differently, so allow a little either way.
            let tolerance = max(0.5, length * 0.02)
            if abs(made - length) > tolerance {
                try fail("The result is \(seconds(made)) long but the original is \(seconds(length)).")
            }
        }
    }

    private static func seconds(_ value: Double) -> String {
        value < 60 ? String(format: "%.1f s", value) : String(format: "%d min %02d s", Int(value) / 60, Int(value) % 60)
    }

    private static func discard(_ output: URL) {
        try? FileManager.default.removeItem(at: output)
    }
}

/// Length and tracks of a media file, from AVFoundation where it can read the format and FFmpeg elsewhere.
struct MediaInfo {
    var duration: Double?
    var hasVideo: Bool?
    var hasAudio: Bool?

    static let readable: Set<FileFormat> = [.mp4, .mov, .m4v, .m4a, .aac, .mp3, .wav, .aiff, .flac, .caf]

    static func read(_ url: URL, ffmpeg: URL?) async -> MediaInfo? {
        if let format = FileFormat.detect(url), readable.contains(format) {
            let asset = AVURLAsset(url: url)
            guard let loaded = try? await asset.load(.duration, .tracks) else { return nil }
            let (duration, tracks) = loaded
            return MediaInfo(
                duration: duration.isNumeric ? duration.seconds : nil,
                hasVideo: tracks.contains { $0.mediaType == .video },
                hasAudio: tracks.contains { $0.mediaType == .audio }
            )
        }
        guard let ffmpeg else { return nil }
        let probe = await FFmpegEngine.probe(ffmpeg, input: url)
        guard probe.found else { return nil }
        return MediaInfo(duration: probe.duration, hasVideo: probe.codec != nil, hasAudio: probe.hasAudio)
    }
}

/// Gives a result the original's creation and modification dates, so it sorts next to it
/// in Finder and Photos instead of jumping to today (research/complaints-summary.md, theme 10).
enum FileDates {
    static func copy(from source: URL, to output: URL) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: source.path) else { return }
        var dates: [FileAttributeKey: Any] = [:]
        if let created = attributes[.creationDate] { dates[.creationDate] = created }
        if let modified = attributes[.modificationDate] { dates[.modificationDate] = modified }
        guard !dates.isEmpty else { return }
        try? FileManager.default.setAttributes(dates, ofItemAtPath: output.path)
        if output.isDirectory, FileFormat.detect(output) == nil {
            for name in (try? FileManager.default.contentsOfDirectory(atPath: output.path)) ?? [] {
                try? FileManager.default.setAttributes(dates, ofItemAtPath: output.appendingPathComponent(name).path)
            }
        }
    }
}
