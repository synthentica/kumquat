import AVFoundation
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

    /// The encoder a format needs that this FFmpeg wasn't built with, if any. Homebrew's FFmpeg, for one,
    /// comes without libwebp and libvorbis, and offering WebP or OGG there only ends in "Encoder not found".
    public static func missingEncoder(for format: FileFormat, ffmpeg: URL) -> String? {
        let arguments = arguments(for: format)
        let needed = arguments.indices.dropLast()
            .filter { ["-c:v", "-c:a"].contains(arguments[$0]) && arguments[$0 + 1] != "copy" }
            .map { arguments[$0 + 1] }
        guard !needed.isEmpty else { return nil }
        let available = encoders(ffmpeg)
        // An FFmpeg that won't list its encoders still gets tried, as before.
        guard !available.isEmpty else { return nil }
        return needed.first { !available.contains($0) }
    }

    public static func canEncode(_ format: FileFormat, ffmpeg: URL) -> Bool {
        missingEncoder(for: format, ffmpeg: ffmpeg) == nil
    }

    private static let encoderCache = EncoderCache()

    /// Asked once per FFmpeg binary; `OperationCatalog.prewarm` does it off the main thread.
    static func encoders(_ ffmpeg: URL) -> Set<String> {
        encoderCache.value(for: ffmpeg.path) {
            let process = Process()
            process.executableURL = ffmpeg
            process.arguments = ["-hide_banner", "-encoders"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            // " V....D libwebp              libwebp WebP image (codec webp)"
            let names = String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { line -> String? in
                let fields = line.split(separator: " ")
                guard fields.count >= 2, fields[0].count == 6, fields[0] != "------" else { return nil }
                return String(fields[1])
            }
            return Set(names)
        }
    }

    private final class EncoderCache: @unchecked Sendable {
        private let lock = NSLock()
        private var known: [String: Set<String>] = [:]

        func value(for key: String, _ make: () -> Set<String>) -> Set<String> {
            lock.lock()
            defer { lock.unlock() }
            if let value = known[key] { return value }
            let value = make()
            known[key] = value
            return value
        }
    }

    /// What FFmpeg says about a file: the first video stream's codec, like "h264", and the length in seconds.
    struct Probe {
        /// False when FFmpeg couldn't open the file at all.
        var found = false
        var codec: String?
        var duration: Double?
        var hasAudio = false
    }

    static func probe(_ ffmpeg: URL, input: URL) async -> Probe {
        guard let info = try? await Shell.run(
            ffmpeg.path, ["-hide_banner", "-nostdin", "-i", input.path, "-t", "0", "-f", "null", "-"]
        ) else { return Probe() }
        var probe = Probe()
        probe.found = info.contains("Input #0")
        probe.hasAudio = info.contains("Audio: ")
        if let range = info.range(of: "Video: ") {
            probe.codec = info[range.upperBound...].prefix { $0.isLetter || $0.isNumber }.lowercased()
        }
        // "Duration: 00:01:02.34,"
        if let range = info.range(of: "Duration: ") {
            let parts = info[range.upperBound...].prefix { $0 != "," }.split(separator: ":").compactMap { Double($0) }
            if parts.count == 3 { probe.duration = parts[0] * 3600 + parts[1] * 60 + parts[2] }
        }
        return probe
    }

    /// How much later a video's sound starts than its picture, in seconds, from the first packet of each in the
    /// first five seconds. Not limited by packet count: the muxer stops at the first limit reached, and in an ASF
    /// the sound's first packet comes after many of the picture's.
    static func audioDelay(_ ffmpeg: URL, input: URL) async -> Double {
        guard let lines = try? await Shell.run(ffmpeg.path, [
            "-hide_banner", "-loglevel", "error", "-nostdin", "-i", input.path,
            "-map", "0:v:0?", "-map", "0:a:0?", "-c", "copy", "-t", "5", "-f", "framemd5", "pipe:2",
        ]) else { return 0 }
        // "#tb 0: 1/1000" gives each stream's time base, then "0, 0, 0, 42, 1234, <md5>" is stream, dts, pts, ...
        var timeBase: [Substring: Double] = [:]
        var start: [Substring: Double] = [:]
        for line in lines.split(whereSeparator: \.isNewline) {
            if line.hasPrefix("#tb ") {
                let parts = line.dropFirst(4).split(separator: ":")
                let ratio = parts.last.map { $0.split(separator: "/").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } } ?? []
                if parts.count == 2, ratio.count == 2, ratio[1] != 0 { timeBase[parts[0]] = ratio[0] / ratio[1] }
            } else if !line.hasPrefix("#") {
                let fields = line.split(separator: ",")
                guard fields.count >= 3, start[fields[0]] == nil, let base = timeBase[fields[0]],
                      let pts = Double(fields[2].trimmingCharacters(in: .whitespaces))
                else { continue }
                start[fields[0]] = pts * base
            }
        }
        guard let video = start["0"], let audio = start["1"] else { return 0 }
        return audio - video
    }

    static let videoTargets: Set<FileFormat> = [.mp4, .mov, .m4v, .webm, .mkv, .avi, .wmv, .gif]

    /// What to try, in order. H.264 and HEVC video is copied as is when only the container changes,
    /// which takes a moment instead of a re-encode. Constant-quality hardware encoding needs Apple silicon,
    /// so Intel Macs fall back to a bitrate.
    static func attempts(for format: FileFormat, codec: String?) -> [[String]] {
        guard [.mp4, .mov, .m4v].contains(format) else { return [arguments(for: format)] }
        var attempts: [[String]] = []
        switch codec ?? "" {
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
        guard videoTargets.contains(format) else {
            // Audio and stills: light enough to run one per core.
            try await run(ffmpeg, input: url, output: output, arguments: arguments(for: format),
                          duration: await duration(of: url, ffmpeg: ffmpeg))
            return output
        }
        return try await Lane.encoder.run {
            let info = await probe(ffmpeg, input: url)
            var lastError: Error?
            for arguments in attempts(for: format, codec: info.codec) {
                do {
                    try await run(ffmpeg, input: url, output: output, arguments: arguments, duration: info.duration,
                                  hardwareDecode: info.codec != "av1")
                    return output
                } catch {
                    lastError = error
                }
            }
            throw lastError ?? OperationError.failed("FFmpeg couldn't convert \(url.lastPathComponent).")
        }
    }

    /// The length of a file in seconds, for the progress bar. Asks FFmpeg only for big files macOS can't read,
    /// since a small one is done before the answer would matter.
    static func duration(of url: URL, ffmpeg: URL) async -> Double? {
        guard WorkProgress.sink != nil else { return nil }
        if let seconds = try? await AVURLAsset(url: url).load(.duration).seconds, seconds.isFinite, seconds > 0 {
            return seconds
        }
        guard FileManager.default.fileSize(url) > 8_000_000 else { return nil }
        return await probe(ffmpeg, input: url).duration
    }

    public static func alac(_ url: URL, context: OperationContext) async throws -> URL {
        guard let ffmpeg = context.ffmpeg else { throw OperationError.unsupported("ALAC without FFmpeg") }
        let output = context.destination(for: url, extension: "m4a")
        try await run(ffmpeg, input: url, output: output, arguments: ["-vn", "-c:a", "alac"])
        return output
    }

    static func run(_ ffmpeg: URL, input: URL, output: URL, arguments: [String], duration: Double? = nil,
                    hardwareDecode: Bool = true) async throws {
        // With a known length, FFmpeg's machine-readable progress on stdout drives the progress bar.
        var progressArguments: [String] = []
        var onLine: (@Sendable (String) -> Void)?
        if let duration, duration > 0, let sink = WorkProgress.sink {
            progressArguments = ["-progress", "pipe:1", "-nostats"]
            onLine = { line in
                if line.hasPrefix("out_time_us="), let micros = Double(line.dropFirst(12)) {
                    sink(min(1, max(0, micros / 1_000_000 / duration)))
                } else if line == "progress=end" {
                    sink(1)
                }
            }
        }
        // Decoding on the media engine: a 4K HEVC clip to GIF took 49 s in the corpus with software decoding.
        // FFmpeg falls back to software by itself for most codecs the Mac can't decode in hardware. AV1 is the
        // exception: asking for the media engine picks FFmpeg's own AV1 decoder, which then fails on Macs before M3
        // (corpus: webm-av1), while leaving it out picks libdav1d.
        let decode = hardwareDecode && input.fileCategory == .video ? ["-hwaccel", "videotoolbox"] : []
        // Sound that starts well after the picture (corpus: an ASF whose audio begins at 0.39 s) is padded with silence
        // from zero, so it stays in sync and keeps its full length. Only then: padding a few milliseconds made FFmpeg
        // skip a frame in an AVI. Copied sound can't be filtered.
        var arguments = arguments
        if input.fileCategory == .video, let codec = arguments.firstIndex(of: "-c:a").map({ arguments[$0 + 1] }),
           codec != "copy", !arguments.contains("-af"), await audioDelay(ffmpeg, input: input) > 0.1 {
            arguments += ["-af", "aresample=async=1:first_pts=0"]
        }
        do {
            try await Shell.run(
                ffmpeg.path,
                ["-hide_banner", "-loglevel", "error", "-nostdin", "-y"] + progressArguments + decode + ["-i", input.path]
                    + arguments + [output.path],
                onOutputLine: onLine
            )
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }
}
