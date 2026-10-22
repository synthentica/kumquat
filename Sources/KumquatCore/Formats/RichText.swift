import AppKit
import Foundation

/// A simple block model of an attributed string, used to write Markdown and XHTML.
struct RichBlock: Equatable {
    enum Kind: Equatable {
        case heading(Int)
        case paragraph
        case listItem(ordered: Bool, level: Int)
    }

    var kind: Kind
    var runs: [RichRun]
}

struct RichRun: Equatable {
    var text: String
    var bold = false
    var italic = false
    var code = false
    var link: String?
}

enum RichText {
    static func blocks(from text: NSAttributedString) -> [RichBlock] {
        let string = text.string as NSString
        let base = bodyFontSize(text)
        var blocks: [RichBlock] = []
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            guard range.length > 0 else { return }
            let paragraph = text.attributedSubstring(from: range)
            var runs = self.runs(in: paragraph)
            let plain = runs.map(\.text).joined()
            guard !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            let style = paragraph.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
            if let lists = style?.textLists, let list = lists.last {
                runs = stripListMarker(runs)
                let ordered = list.markerFormat.rawValue.contains("decimal") || list.markerFormat.rawValue.contains("alpha")
                    || list.markerFormat.rawValue.contains("roman")
                blocks.append(RichBlock(kind: .listItem(ordered: ordered, level: lists.count - 1), runs: runs))
                return
            }

            let size = maxFontSize(paragraph) ?? base
            let allBold = runs.allSatisfy { $0.bold || $0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            let level: Int?
            if size >= base * 1.6 { level = 1 } else if size >= base * 1.3 { level = 2 } else if size >= base * 1.12 && allBold { level = 3 } else { level = nil }
            if let level, plain.count < 200 {
                let unstyled = runs.map { run -> RichRun in
                    var run = run
                    run.bold = false
                    return run
                }
                blocks.append(RichBlock(kind: .heading(level), runs: unstyled))
            } else {
                blocks.append(RichBlock(kind: .paragraph, runs: runs))
            }
        }
        return blocks
    }

    private static func runs(in paragraph: NSAttributedString) -> [RichRun] {
        var runs: [RichRun] = []
        let full = NSRange(location: 0, length: paragraph.length)
        paragraph.enumerateAttributes(in: full) { attributes, range, _ in
            var text = (paragraph.string as NSString).substring(with: range)
            text = text.replacingOccurrences(of: "\u{FFFC}", with: "")
                .replacingOccurrences(of: "\u{2028}", with: "\n")
            guard !text.isEmpty else { return }
            var run = RichRun(text: text)
            if let font = attributes[.font] as? NSFont {
                let traits = font.fontDescriptor.symbolicTraits
                run.bold = traits.contains(.bold)
                run.italic = traits.contains(.italic)
                run.code = traits.contains(.monoSpace)
            }
            if let link = attributes[.link] {
                run.link = (link as? URL)?.absoluteString ?? (link as? String)
            }
            if let last = runs.last, last.bold == run.bold, last.italic == run.italic, last.code == run.code, last.link == run.link {
                runs[runs.count - 1].text += run.text
            } else {
                runs.append(run)
            }
        }
        return runs
    }

    /// Cocoa stores list bullets as text, like "\t•\t". Drop them; the writers add their own.
    private static func stripListMarker(_ runs: [RichRun]) -> [RichRun] {
        guard var first = runs.first else { return runs }
        if let range = first.text.range(of: #"^\t?[^\t]{0,8}\t"#, options: .regularExpression) {
            first.text.removeSubrange(range)
        }
        var result = runs
        result[0] = first
        return result.filter { !$0.text.isEmpty }
    }

    private static func maxFontSize(_ text: NSAttributedString) -> CGFloat? {
        var size: CGFloat?
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, _, _ in
            guard let font = value as? NSFont else { return }
            size = max(size ?? 0, font.pointSize)
        }
        return size
    }

    /// The font size covering the most characters, taken as body text.
    private static func bodyFontSize(_ text: NSAttributedString) -> CGFloat {
        var counts: [CGFloat: Int] = [:]
        text.enumerateAttribute(.font, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            let size = (value as? NSFont)?.pointSize ?? 12
            counts[size, default: 0] += range.length
        }
        return counts.max { $0.value < $1.value }?.key ?? 12
    }
}

// MARK: - Writers

enum MarkdownWriter {
    static func markdown(from text: NSAttributedString) -> String {
        markdown(from: RichText.blocks(from: text))
    }

    static func markdown(from blocks: [RichBlock]) -> String {
        var output = ""
        var previous: RichBlock.Kind?
        for block in blocks {
            if let previous {
                if case .listItem = previous, case .listItem = block.kind {
                    output += "\n"
                } else {
                    output += "\n\n"
                }
            }
            let body = inline(block.runs)
            switch block.kind {
            case .heading(let level):
                output += String(repeating: "#", count: level) + " " + body.replacingOccurrences(of: "\n", with: " ")
            case .paragraph:
                output += body.replacingOccurrences(of: "\n", with: "  \n")
            case .listItem(let ordered, let level):
                output += String(repeating: "  ", count: level) + (ordered ? "1. " : "- ") + body
            }
            previous = block.kind
        }
        return output + "\n"
    }

    private static func inline(_ runs: [RichRun]) -> String {
        runs.map { run in
            let (lead, core, trail) = run.text.splitWhitespace()
            guard !core.isEmpty else { return run.text }
            var text = core
            if run.code {
                text = "`" + text + "`"
            } else {
                if run.italic { text = "*" + text + "*" }
                if run.bold { text = "**" + text + "**" }
            }
            if let link = run.link { text = "[" + text + "](" + link + ")" }
            return lead + text + trail
        }.joined()
    }
}

enum XHTMLWriter {
    static func body(from text: NSAttributedString) -> String {
        body(from: RichText.blocks(from: text))
    }

    static func body(from blocks: [RichBlock]) -> String {
        var lines: [String] = []
        var openList: Bool?
        func closeList() {
            if let ordered = openList { lines.append(ordered ? "</ol>" : "</ul>") }
            openList = nil
        }
        for block in blocks {
            let body = inline(block.runs)
            switch block.kind {
            case .heading(let level):
                closeList()
                lines.append("<h\(level)>\(body)</h\(level)>")
            case .paragraph:
                closeList()
                lines.append("<p>\(body.replacingOccurrences(of: "\n", with: "<br/>"))</p>")
            case .listItem(let ordered, _):
                if openList != ordered {
                    closeList()
                    lines.append(ordered ? "<ol>" : "<ul>")
                    openList = ordered
                }
                lines.append("<li>\(body)</li>")
            }
        }
        closeList()
        return lines.joined(separator: "\n")
    }

    private static func inline(_ runs: [RichRun]) -> String {
        runs.map { run in
            var text = run.text.xmlEscaped
            if run.code { text = "<code>\(text)</code>" }
            if run.italic { text = "<em>\(text)</em>" }
            if run.bold { text = "<strong>\(text)</strong>" }
            if let link = run.link { text = "<a href=\"\(link.xmlEscaped)\">\(text)</a>" }
            return text
        }.joined()
    }
}

extension String {
    var xmlEscaped: String {
        var result = ""
        result.reserveCapacity(count)
        for character in self {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            // Characters XML 1.0 doesn't allow (control codes from a PDF with a broken font map, say) would make
            // Word refuse the whole file, so they're left out.
            case _ where !character.isValidInXML: continue
            default: result.append(character)
            }
        }
        return result
    }

    /// Leading whitespace, the rest, and trailing whitespace.
    func splitWhitespace() -> (String, String, String) {
        let leading = prefix { $0.isWhitespace }
        let rest = dropFirst(leading.count)
        let trailing = rest.reversed().prefix { $0.isWhitespace }
        let core = rest.dropLast(trailing.count)
        return (String(leading), String(core), String(trailing.reversed()))
    }
}

extension Character {
    /// Whether XML 1.0 allows this character: tab, line feed, carriage return, and everything from space up except
    /// the surrogates and U+FFFE and U+FFFF.
    var isValidInXML: Bool {
        unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 0x9, 0xA, 0xD, 0x20...0xD7FF, 0xE000...0xFFFD, 0x10000...0x10FFFF: true
            default: false
            }
        }
    }
}
