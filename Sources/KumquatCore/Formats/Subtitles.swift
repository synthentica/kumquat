import Foundation

public struct SubtitleCue: Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var text: String
}

/// SRT and WebVTT parsing and writing.
public enum Subtitles {
    /// A cue runs from its timing line to the next blank line. A line of only spaces counts as blank too: splitting
    /// on empty lines alone merged such cues, and every cue after the first in a block was lost.
    public static func parse(_ text: String) -> [SubtitleCue] {
        let lines = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        var cues: [SubtitleCue] = []
        var current: SubtitleCue?
        var body: [String] = []
        func finish() {
            if var cue = current {
                cue.text = body.joined(separator: "\n")
                cues.append(cue)
            }
            current = nil
            body = []
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let span = timing(trimmed) {
                // Without a blank line before it, the next cue's number would end up in this cue's text.
                if let last = body.last, last.allSatisfy(\.isNumber) { body.removeLast() }
                finish()
                current = SubtitleCue(start: span.start, end: span.end, text: "")
            } else if trimmed.isEmpty {
                finish()
            } else if current != nil {
                body.append(line)
            }
        }
        finish()
        return cues
    }

    /// The start and end of a line like "00:00:01,000 --> 00:00:02,500 align:start".
    static func timing(_ line: String) -> (start: Double, end: Double)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2,
              let start = time(parts[0]),
              let end = time(parts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? "")
        else { return nil }
        return (start, end)
    }

    static func time(_ string: String) -> Double? {
        let clean = string.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        let parts = clean.components(separatedBy: ":")
        guard (2...3).contains(parts.count), let seconds = Double(parts[parts.count - 1]) else { return nil }
        guard let minutes = Double(parts[parts.count - 2]) else { return nil }
        let hours = parts.count == 3 ? Double(parts[0]) ?? 0 : 0
        let total = hours * 3600 + minutes * 60 + seconds
        // "nan" and absurd hours parse as numbers too, and writing them out as milliseconds would crash.
        guard total.isFinite, total >= 0, total < 3_600_000_000 else { return nil }
        return total
    }

    static func stamp(_ time: Double, separator: String) -> String {
        let milliseconds = Int((time * 1000).rounded())
        let hours = milliseconds / 3_600_000
        let minutes = milliseconds / 60_000 % 60
        let seconds = milliseconds / 1000 % 60
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, seconds, separator, milliseconds % 1000)
    }

    public static func srt(_ cues: [SubtitleCue]) -> String {
        cues.enumerated().map { index, cue in
            "\(index + 1)\n\(stamp(cue.start, separator: ",")) --> \(stamp(cue.end, separator: ","))\n\(cue.text)"
        }.joined(separator: "\n\n") + "\n"
    }

    public static func vtt(_ cues: [SubtitleCue]) -> String {
        "WEBVTT\n\n" + cues.map { cue in
            "\(stamp(cue.start, separator: ".")) --> \(stamp(cue.end, separator: "."))\n\(cue.text)"
        }.joined(separator: "\n\n") + "\n"
    }

    public static func plainText(_ cues: [SubtitleCue]) -> String {
        cues.map { $0.text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) }
            .joined(separator: "\n") + "\n"
    }

    public static func convert(_ url: URL, to format: FileFormat, context: OperationContext) throws -> URL {
        let cues = parse(try readText(url))
        guard !cues.isEmpty else { throw OperationError.failed("No subtitles found in \(url.lastPathComponent).") }
        let output = context.destination(for: url, extension: format.primaryExtension)
        let text: String
        switch format {
        case .srt: text = srt(cues)
        case .vtt: text = vtt(cues)
        case .txt: text = plainText(cues)
        default: throw OperationError.unsupported(format.displayName)
        }
        try text.write(to: output, atomically: true, encoding: .utf8)
        return output
    }
}
