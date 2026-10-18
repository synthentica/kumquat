import Foundation

/// FFmpeg for the formats macOS can't encode natively: MP3, OGG, Opus, WMA, WebM, MKV, AVI, WMV and WebP.
/// The app ships its own LGPL build (scripts/build-ffmpeg.sh); a system FFmpeg is used when running from source.
public enum FFmpegEngine {
    public static let searchPaths = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/opt/local/bin/ffmpeg",
        "/usr/bin/ffmpeg",
    ]

    public static func locate(custom: String? = nil) -> URL? {
        let fm = FileManager.default
        if let custom, !custom.isEmpty {
            let path = (custom as NSString).expandingTildeInPath
            return fm.isExecutableFile(atPath: path) ? URL(fileURLWithPath: path) : nil
        }
        if let bundled = Bundle.main.url(forAuxiliaryExecutable: "ffmpeg"), fm.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        return searchPaths.first(where: fm.isExecutableFile(atPath:)).map(URL.init(fileURLWithPath:))
    }

    static func arguments(for format: FileFormat) -> [String] {
        switch format {
        case .mp3: ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
        case .ogg: ["-vn", "-c:a", "libvorbis", "-q:a", "5"]
        case .opus: ["-vn", "-c:a", "libopus", "-b:a", "128k"]
        case .flac: ["-vn", "-c:a", "flac"]
        case .wav: ["-vn", "-c:a", "pcm_s16le"]
        case .aiff: ["-vn", "-c:a", "pcm_s16be"]
        case .m4a: ["-vn", "-c:a", "aac", "-b:a", "256k"]
        case .webm: ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-deadline", "good", "-cpu-used", "4", "-row-mt", "1", "-c:a", "libopus"]
        case .mkv: ["-map", "0", "-c", "copy"]
        case .wma: ["-vn", "-c:a", "wmav2", "-b:a", "192k"]
        case .avi: ["-c:v", "mpeg4", "-q:v", "3", "-c:a", "libmp3lame", "-q:a", "3"]
        case .wmv: ["-c:v", "wmv2", "-q:v", "3", "-c:a", "wmav2", "-b:a", "192k"]
        case .mp4, .mov, .m4v:
            // The Mac's hardware H.264 encoder: many times faster than software.
            ["-c:v", "h264_videotoolbox", "-q:v", "62", "-allow_sw", "1", "-pix_fmt", "yuv420p",
             "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"]
        case .gif:
            ["-vf", "fps=15,scale='min(480,iw)':-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse", "-loop", "0"]
        case .webp: ["-c:v", "libwebp", "-quality", "85"]
        default: []
        }
    }

    /// The first video stream's codec name, like "h264", from FFmpeg's description of the file.
    static func videoCodec(_ ffmpeg: URL, input: URL) async -> String? {
        guard let info = try? await Shell.run(
            ffmpeg.path, ["-hide_banner", "-nostdin", "-i", input.path, "-t", "0", "-f", "null", "-"]
        ) else { return nil }
        guard let range = info.range(of: "Video: ") else { return nil }
        return info[range.upperBound...].prefix { $0.isLetter || $0.isNumber }.lowercased()
    }

    /// What to try, in order. H.264 and HEVC video is copied as is when only the container changes,
    /// which takes a moment instead of a re-encode. Constant-quality hardware encoding needs Apple silicon,
    /// so Intel Macs fall back to a bitrate.
    static func attempts(for format: FileFormat, ffmpeg: URL, input: URL) async -> [[String]] {
        guard [.mp4, .mov, .m4v].contains(format) else { return [arguments(for: format)] }
        var attempts: [[String]] = []
        switch await videoCodec(ffmpeg, input: input) ?? "" {
        case "h264":
            attempts.append(["-map", "0:v:0", "-map", "0:a:0?", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"])
        case "hevc":
            attempts.append(["-map", "0:v:0", "-map", "0:a:0?", "-c:v", "copy", "-tag:v", "hvc1", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"])
        default:
            break
        }
        attempts.append(arguments(for: format))
        attempts.append(["-c:v", "h264_videotoolbox", "-b:v", "8M", "-allow_sw", "1", "-pix_fmt", "yuv420p",
                         "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"])
        return attempts
    }

    public static func convert(_ url: URL, to format: FileFormat, extension ext: String? = nil, context: OperationContext) async throws -> URL {
        guard let ffmpeg = context.ffmpeg else { throw OperationError.unsupported("\(format.displayName) without FFmpeg") }
        let output = context.destination(for: url, extension: ext ?? format.primaryExtension)
        var lastError: Error?
        for arguments in await attempts(for: format, ffmpeg: ffmpeg, input: url) {
            do {
                try await run(ffmpeg, input: url, output: output, arguments: arguments)
                return output
            } catch {
                lastError = error
            }
        }
        throw lastError ?? OperationError.failed("FFmpeg couldn't convert \(url.lastPathComponent).")
    }

    public static func alac(_ url: URL, context: OperationContext) async throws -> URL {
        guard let ffmpeg = context.ffmpeg else { throw OperationError.unsupported("ALAC without FFmpeg") }
        let output = context.destination(for: url, extension: "m4a")
        try await run(ffmpeg, input: url, output: output, arguments: ["-vn", "-c:a", "alac"])
        return output
    }

    static func run(_ ffmpeg: URL, input: URL, output: URL, arguments: [String]) async throws {
        do {
            try await Shell.run(
                ffmpeg.path,
                ["-hide_banner", "-loglevel", "error", "-nostdin", "-y", "-i", input.path] + arguments + [output.path]
            )
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }
}
