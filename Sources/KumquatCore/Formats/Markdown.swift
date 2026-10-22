import Foundation

/// A small, dependency-free Markdown to XHTML converter covering everyday Markdown:
/// headings, paragraphs, emphasis, links, images, code, lists, quotes, rules and tables.
public enum Markdown {
    public static func xhtml(from markdown: String) -> String {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        return blocks(lines).joined(separator: "\n")
    }

    /// A complete, styled HTML document.
    public static func htmlDocument(from markdown: String, title: String) -> String {
        """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"/><title>\(title.xmlEscaped)</title>
        <style>\(stylesheet)</style></head>
        <body>
        \(xhtml(from: markdown))
        </body></html>
        """
    }

    static let stylesheet = """
    body { font-family: -apple-system, 'Helvetica Neue', Helvetica, Arial, sans-serif; font-size: 12pt; line-height: 1.5; color: #1d1d1f; }
    h1 { font-size: 24pt; } h2 { font-size: 18pt; } h3 { font-size: 14pt; }
    code, pre { font-family: Menlo, monospace; font-size: 10.5pt; }
    pre { background: #f5f5f7; padding: 8pt; }
    blockquote { color: #555; margin-left: 12pt; }
    table { border-collapse: collapse; } td, th { border: 1px solid #ccc; padding: 4pt 8pt; }
    """

    private static func blocks(_ lines: [String]) -> [String] {
        var output: [String] = []
        var paragraph: [String] = []
        var index = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            var html = ""
            for (offset, line) in paragraph.enumerated() {
                let hardBreak = line.hasSuffix("  ")
                html += inline(line.trimmingCharacters(in: .whitespaces))
                if offset < paragraph.count - 1 { html += hardBreak ? "<br/>" : " " }
            }
            output.append("<p>\(html)</p>")
            paragraph.removeAll()
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushParagraph()
                let fence = String(trimmed.prefix(3))
                var code: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix(fence) {
                    code.append(lines[index])
                    index += 1
                }
                index += 1
                output.append("<pre><code>\(code.joined(separator: "\n").xmlEscaped)</code></pre>")
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if let found = heading(trimmed) {
                flushParagraph()
                output.append("<h\(found.level)>\(inline(found.text))</h\(found.level)>")
                index += 1
                continue
            }

            if isRule(trimmed) {
                flushParagraph()
                output.append("<hr/>")
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                var quoted: [String] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.hasPrefix(">") else { break }
                    var stripped = String(current.dropFirst())
                    if stripped.hasPrefix(" ") { stripped.removeFirst() }
                    quoted.append(stripped)
                    index += 1
                }
                output.append("<blockquote>\n\(blocks(quoted).joined(separator: "\n"))\n</blockquote>")
                continue
            }

            if listItem(line) != nil {
                flushParagraph()
                var items: [String] = []
                let ordered = listItem(line)!.ordered
                while index < lines.count, let item = listItem(lines[index]), item.ordered == ordered {
                    items.append("<li>\(inline(item.text))</li>")
                    index += 1
                }
                let tag = ordered ? "ol" : "ul"
                output.append("<\(tag)>\n\(items.joined(separator: "\n"))\n</\(tag)>")
                continue
            }

            if trimmed.contains("|"), index + 1 < lines.count, isTableSeparator(lines[index + 1]) {
                flushParagraph()
                let header = cells(trimmed)
                index += 2
                var rows: [[String]] = []
                while index < lines.count {
                    let current = lines[index].trimmingCharacters(in: .whitespaces)
                    guard current.contains("|"), !current.isEmpty else { break }
                    rows.append(cells(current))
                    index += 1
                }
                var html = "<table>\n<tr>" + header.map { "<th>\(inline($0))</th>" }.joined() + "</tr>"
                for row in rows {
                    html += "\n<tr>" + row.map { "<td>\(inline($0))</td>" }.joined() + "</tr>"
                }
                output.append(html + "\n</table>")
                continue
            }

            paragraph.append(line)
            index += 1
        }
        flushParagraph()
        return output
    }

    private static func heading(_ line: String) -> (level: Int, text: String)? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        guard rest.isEmpty || rest.hasPrefix(" ") else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        while text.hasSuffix("#") { text.removeLast() }
        return (hashes, text.trimmingCharacters(in: .whitespaces))
    }

    private static func isRule(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private static func listItem(_ line: String) -> (ordered: Bool, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        for bullet in ["- ", "* ", "+ "] where trimmed.hasPrefix(bullet) {
            var text = String(trimmed.dropFirst(2))
            if text.hasPrefix("[ ] ") { text = "☐ " + text.dropFirst(4) }
            else if text.lowercased().hasPrefix("[x] ") { text = "☑ " + text.dropFirst(4) }
            return (false, text)
        }
        let digits = trimmed.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let rest = trimmed.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return (true, String(rest.dropFirst(2)))
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-") else { return false }
        return trimmed.allSatisfy { "|:- ".contains($0) }
    }

    private static func cells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // MARK: Inline

    static func inline(_ text: String) -> String {
        // Code spans are cut out first so nothing inside them is treated as formatting. The marks around their
        // numbers are private-use characters, which XML allows, so escaping leaves them alone.
        var codes: [String] = []
        var working = replace(text, #"`([^`]+)`"#) { groups in
            codes.append(groups[1])
            return "\u{E000}\(codes.count - 1)\u{E000}"
        }
        working = working.xmlEscaped
        working = replace(working, #"!\[([^\]]*)\]\(([^)\s]+)\)"#) { "<img alt=\"\($0[1])\" src=\"\($0[2])\"/>" }
        working = replace(working, #"\[([^\]]+)\]\(([^)\s]+)\)"#) { "<a href=\"\($0[2])\">\($0[1])</a>" }
        working = replace(working, #"&lt;(https?://[^\s&]+)&gt;"#) { "<a href=\"\($0[1])\">\($0[1])</a>" }
        working = replace(working, #"\*\*(.+?)\*\*"#) { "<strong>\($0[1])</strong>" }
        working = replace(working, #"__(.+?)__"#) { "<strong>\($0[1])</strong>" }
        working = replace(working, #"\*(.+?)\*"#) { "<em>\($0[1])</em>" }
        working = replace(working, #"(?<![\w])_(.+?)_(?![\w])"#) { "<em>\($0[1])</em>" }
        working = replace(working, #"~~(.+?)~~"#) { "<del>\($0[1])</del>" }
        working = replace(working, "\u{E000}(\\d+)\u{E000}") { groups in
            let index = Int(groups[1]) ?? 0
            return "<code>\((codes.indices.contains(index) ? codes[index] : "").xmlEscaped)</code>"
        }
        return working
    }

    private static func replace(_ text: String, _ pattern: String, _ transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            var groups: [String] = []
            for group in 0..<match.numberOfRanges {
                let range = match.range(at: group)
                groups.append(range.location == NSNotFound ? "" : ns.substring(with: range))
            }
            result += transform(groups)
            last = match.range.location + match.range.length
        }
        result += ns.substring(from: last)
        return result
    }
}
