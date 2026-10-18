import Foundation

/// Optional FFmpeg support. When FFmpeg is installed (for example with Homebrew),
/// formats macOS can't encode natively appear on the wheel: MP3, OGG, Opus, WMA, WebM, MKV, AVI, WMV and WebP.
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
        case .webm: ["-c:v", "libvpx-vp9", "-crf", "32", "-b:v", "0", "-row-mt", "1", "-c:a", "libopus"]
        case .mkv: ["-map", "0", "-c", "copy"]
        case .wma: ["-vn", "-c:a", "wmav2", "-b:a", "192k"]
        case .avi: ["-c:v", "mpeg4", "-q:v", "3", "-c:a", "libmp3lame", "-q:a", "3"]
        case .wmv: ["-c:v", "wmv2", "-q:v", "3", "-c:a", "wmav2", "-b:a", "192k"]
        case .mp4, .mov, .m4v:
            ["-c:v", "libx264", "-crf", "20", "-preset", "veryfast", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"]
        case .gif:
            ["-vf", "fps=15,scale='min(480,iw)':-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse", "-loop", "0"]
        case .webp: ["-c:v", "libwebp", "-quality", "85"]
        default: []
        }
    }

    public static func convert(_ url: URL, to format: FileFormat, extension ext: String? = nil, context: OperationContext) async throws -> URL {
        guard let ffmpeg = context.ffmpeg else { throw OperationError.unsupported("\(format.displayName) without FFmpeg") }
        let output = context.destination(for: url, extension: ext ?? format.primaryExtension)
        try await run(ffmpeg, input: url, output: output, arguments: arguments(for: format))
        return output
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
