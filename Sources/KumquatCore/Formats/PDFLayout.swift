import AppKit
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// A PDF read back as a document: positioned text, pictures, rules and shaded boxes on each page, grouped into
/// headings, paragraphs and tables, so it keeps its look when it becomes a Word, HTML or EPUB file.
///
/// PDFKit gives the text with its fonts and the position of every character; the page's content stream gives
/// the pictures and the drawn lines and boxes, which PDFKit doesn't expose. The page is then cut into bands and
/// columns along its white space (an XY cut), and the pieces become paragraphs, layout tables and data tables.
enum PDFLayout {
    // MARK: Model

    struct Color: Equatable {
        var red: CGFloat, green: CGFloat, blue: CGFloat
        static let black = Color(red: 0, green: 0, blue: 0)

        var hex: String {
            func byte(_ value: CGFloat) -> String { String(format: "%02X", Int((min(max(value, 0), 1) * 255).rounded())) }
            return byte(red) + byte(green) + byte(blue)
        }

        var isNearWhite: Bool { red > 0.97 && green > 0.97 && blue > 0.97 }
        var isBlack: Bool { red < 0.05 && green < 0.05 && blue < 0.05 }
    }

    enum Family: Equatable { case sans, serif, mono }

    struct Run: Equatable {
        var text: String
        var family: Family = .sans
        var fontName = "Helvetica"
        var size: CGFloat = 11
        var bold = false
        var italic = false
        var underline = false
        var color = Color.black

        func sameStyle(_ other: Run) -> Bool {
            family == other.family && fontName == other.fontName && abs(size - other.size) < 0.25 && bold == other.bold
                && italic == other.italic && underline == other.underline && color == other.color
        }
    }

    /// One stretch of text on one line, up to a wide gap. Rectangles measure from the page's top left.
    struct Line {
        var runs: [Run]
        var rect: CGRect
        var text: String { runs.map(\.text).joined() }
        var size: CGFloat { runs.map(\.size).max() ?? 11 }
        var isBold: Bool { runs.allSatisfy { $0.bold || $0.text.trimmingCharacters(in: .whitespaces).isEmpty } }

        mutating func append(_ text: String, style: Run) {
            if var last = runs.last, last.sameStyle(style) {
                last.text += text
                runs[runs.count - 1] = last
            } else {
                var run = style
                run.text = text
                runs.append(run)
            }
        }
    }

    struct Picture {
        var rect: CGRect
        var data: Data
        var isJPEG: Bool
        var pixelSize: CGSize
    }

    enum Alignment { case left, center, right }

    struct Paragraph {
        var runs: [Run]
        var heading = 0
        var alignment = Alignment.left
        var lineCount = 1
    }

    struct Cell {
        var blocks: [Block] = []
        var shading: Color?
        var centeredVertically = false
    }

    struct Table {
        /// Column widths in points.
        var columns: [CGFloat]
        var rows: [[Cell]]
        /// Space above each row, in points.
        var rowSpacing: [CGFloat]
        /// The least height of each row, in points (shaded boxes keep their size).
        var rowHeights: [CGFloat?]
        /// True for rows of text in aligned columns, false for a layout (pictures beside text, a shaded box).
        var isData: Bool
        /// For data tables: where each column starts on the page, and the span its text covers.
        var starts: [CGFloat] = []
        var spans: [ClosedRange<CGFloat>] = []
    }

    enum Kind {
        case paragraph(Paragraph)
        case picture(Picture)
        case rule(width: CGFloat, thickness: CGFloat, color: Color)
        case table(Table)
        case pageBreak
    }

    struct Block {
        var kind: Kind
        var spaceBefore: CGFloat = 0
        var indent: CGFloat = 0
    }

    struct Document {
        var pageSize: CGSize
        var margins: NSEdgeInsets
        var blocks: [Block]
        var bodySize: CGFloat
        var contentWidth: CGFloat { pageSize.width - margins.left - margins.right }
    }

    // MARK: Reading

    /// The document's layout. Without `pictures`, images are left out (plain text, Markdown, tables),
    /// which saves rendering them.
    static func read(_ url: URL, pictures: Bool) throws -> Document {
        let document = try PDFEngine.open(url)
        guard document.pageCount > 0, let first = document.page(at: 0) else { throw OperationError.failed("The PDF has no pages.") }
        let firstBox = displayBox(first)
        var pages: [[Element]] = []
        var allLines: [Line] = []
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            let elements = autoreleasepool { self.elements(on: page, pictures: pictures) }
            pages.append(elements)
            for element in elements { allLines += element.lines }
            WorkProgress.report(index + 1, of: document.pageCount)
        }
        let bodySize = mostCommonSize(allLines)

        // Margins from where the content sits, so the result's text column matches the PDF's.
        let rects = pages.flatMap { $0.map(\.rect) }
        let content = rects.reduce(CGRect.null) { $0.union($1) }
        let left = content.isNull ? 56 : max(18, min(content.minX, firstBox.width / 3))
        let right = content.isNull ? 56 : max(18, min(firstBox.width - content.maxX, firstBox.width / 3))
        let top = content.isNull ? 56 : max(18, min(pages.compactMap { $0.map(\.rect.minY).min() }.min() ?? 56, firstBox.height / 4))
        let margins = NSEdgeInsets(top: top, left: left, bottom: 36, right: right)
        let width = firstBox.width - left - right

        var blocks: [Block] = []
        for (number, elements) in pages.enumerated() {
            if number > 0 { blocks.append(Block(kind: .pageBreak)) }
            guard !elements.isEmpty else { continue }
            let tree = cut(elements)
            var pageBlocks = self.blocks(tree, left: left, width: width, bodySize: bodySize)
            if !pageBlocks.isEmpty {
                pageBlocks[0].spaceBefore = max(0, tree.rect.minY - top)
            }
            blocks += pageBlocks
        }
        return Document(pageSize: firstBox.size, margins: margins, blocks: blocks, bodySize: bodySize)
    }

    static func displayBox(_ page: PDFPage) -> CGRect {
        page.bounds(for: .mediaBox)
    }

    static func mostCommonSize(_ lines: [Line]) -> CGFloat {
        var counts: [Int: Int] = [:]
        for line in lines {
            for run in line.runs { counts[Int((run.size * 2).rounded()), default: 0] += run.text.count }
        }
        guard let common = counts.max(by: { $0.value < $1.value })?.key else { return 11 }
        return CGFloat(common) / 2
    }

    // MARK: Elements

    indirect enum Element {
        case text(Line)
        case picture(Picture)
        case rule(CGRect, Color)
        case box(CGRect, Color, [Element])

        var rect: CGRect {
            switch self {
            case .text(let line): line.rect
            case .picture(let picture): picture.rect
            case .rule(let rect, _): rect
            case .box(let rect, _, _): rect
            }
        }

        var lines: [Line] {
            switch self {
            case .text(let line): [line]
            case .box(_, _, let children): children.flatMap(\.lines)
            default: []
            }
        }

        var isText: Bool { if case .text = self { true } else { false } }
    }

    /// Everything on a page, in top-left coordinates.
    static func elements(on page: PDFPage, pictures: Bool) -> [Element] {
        let box = displayBox(page)
        // Pages turned with /Rotate and scans keep the plain text path.
        if page.rotation % 360 != 0 { return plainLines(page) }
        let graphics = GraphicsScan(page: page)
        graphics.scan()
        // Where each run of text starts and in which font, measured from the top left like everything else.
        let fontHits = graphics.texts
            .map { GraphicsScan.TextHit(point: CGPoint(x: $0.point.x - box.minX, y: box.maxY - $0.point.y), size: $0.size, font: $0.font) }
            .sorted { $0.point.y < $1.point.y }
        var lines = textLines(page, box: box, fonts: fontHits)
        if lines.isEmpty {
            // A scan: its text, read from the picture. A page of photos without text goes on to keep them.
            let recognized = PDFEngine.recognizeText(on: page)
            // Lines of read text have no positions; their length stands in for width, so long lines that ran to the
            // edge join into paragraphs and short ones (headings, the end of a paragraph) don't.
            if !recognized.isEmpty { return recognized.components(separatedBy: .newlines).enumerated().map { index, text in
                .text(Line(runs: [Run(text: text)], rect: CGRect(x: 0, y: CGFloat(index) * 14, width: min(500, CGFloat(text.count) * 5.5), height: 11)))
            } }
        }
        // Page numbers in the top or bottom margin ("1 / 2", "Page 3 of 9") belong to the PDF's pages, not to the
        // document; in a Word or HTML file they'd land mid-page.
        lines.removeAll { line in
            let edge = line.rect.minY > box.height * 0.92 || line.rect.maxY < box.height * 0.06
            // Text too small to read is a hidden stamp ("Powered by …"), not content.
            return edge && isPageNumber(line.text) || line.size < 3
        }
        func flip(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX - box.minX, y: box.maxY - rect.maxY, width: rect.width, height: rect.height).standardized
        }
        let pageArea = box.width * box.height

        // Thin fills and strokes are underlines when they sit under a line of text of about their width,
        // rules otherwise; other filled shapes are shaded boxes.
        var rules: [(CGRect, Color)] = []
        var boxes: [(CGRect, Color)] = []
        for (rect, color) in graphics.fills {
            let rect = flip(rect)
            guard !color.isNearWhite, rect.width * rect.height < pageArea * 0.8 else { continue }
            if rect.height <= 1.6, rect.width >= 4 {
                rules.append((rect, color))
            } else if rect.width > 1.6, rect.height > 1.6 {
                boxes.append((rect, color))
            }
        }
        for (rect, color) in graphics.strokes {
            let rect = flip(rect)
            if rect.height <= 2.5, rect.width >= 4, !color.isNearWhite { rules.append((rect, color)) }
        }
        let contentWidth = lines.reduce(CGRect.null) { $0.union($1.rect) }.width
        var ruleElements: [Element] = []
        for (rule, color) in rules {
            if let index = lines.firstIndex(where: { line in
                let overlap = line.rect.intersection(CGRect(x: rule.minX, y: line.rect.minY, width: rule.width, height: line.rect.height)).width
                return overlap >= 0.8 * min(rule.width, line.rect.width) && rule.width <= line.rect.width * 1.3 + 2
                    && rule.midY >= line.rect.minY + line.rect.height * 0.5 && rule.midY <= line.rect.maxY + 3.5
            }) {
                for run in lines[index].runs.indices { lines[index].runs[run].underline = true }
            } else if rule.width >= max(40, contentWidth * 0.3) {
                ruleElements.append(.rule(rule, color))
            }
        }

        // A rule drawn in pieces (a border under each cell of a row) is one rule.
        ruleElements.sort { $0.rect.minY == $1.rect.minY ? $0.rect.minX < $1.rect.minX : $0.rect.minY < $1.rect.minY }
        var joinedRules: [Element] = []
        for rule in ruleElements {
            if case .rule(let last, let color) = joinedRules.last, abs(last.midY - rule.rect.midY) < 2,
               rule.rect.minX <= last.maxX + 3, rule.rect.maxX >= last.minX - 3 {
                joinedRules[joinedRules.count - 1] = .rule(last.union(rule.rect), color)
            } else {
                joinedRules.append(rule)
            }
        }
        ruleElements = joinedRules

        var picturesFound: [Picture] = []
        if pictures {
            picturesFound = extractPictures(graphics.images, page: page, box: box)
        } else {
            // Without pixels a picture still holds its place, so the text around it is grouped the same way.
            picturesFound = graphics.images.map { Picture(rect: flip($0.rect), data: Data(), isJPEG: false, pixelSize: .zero) }
                .filter { $0.rect.width >= 4 && $0.rect.height >= 4 }
        }

        // Shaded boxes take the text and pictures inside them. The smallest box that holds an element gets it.
        var loose: [Element] = lines.map(Element.text) + picturesFound.map(Element.picture) + ruleElements
        let sortedBoxes = boxes.sorted { $0.0.width * $0.0.height < $1.0.width * $1.0.height }
        var boxElements: [(CGRect, Color, [Element])] = sortedBoxes.map { ($0.0, $0.1, []) }
        loose = loose.filter { element in
            let center = CGPoint(x: element.rect.midX, y: element.rect.midY)
            guard let index = boxElements.firstIndex(where: { $0.0.contains(center) && $0.0.insetBy(dx: -1, dy: -1).contains(element.rect) }) else { return true }
            boxElements[index].2.append(element)
            return false
        }
        // A box inside a bigger box goes inside it too; one that frames most of the page is just a background.
        var result = loose
        var nested = Array(repeating: false, count: boxElements.count)
        for index in boxElements.indices.reversed() {
            let (rect, color, children) = boxElements[index]
            if rect.width * rect.height > pageArea * 0.5 {
                result += children
                continue
            }
            if let outer = boxElements.indices.first(where: { $0 > index && boxElements[$0].0.insetBy(dx: -1, dy: -1).contains(rect) }) {
                boxElements[outer].2.append(.box(rect, color, children))
                nested[index] = true
            }
        }
        for index in boxElements.indices where !nested[index] {
            let (rect, color, children) = boxElements[index]
            if rect.width * rect.height > pageArea * 0.5 { continue }
            result.append(.box(rect, color, children))
        }
        return result
    }

    static func isPageNumber(_ text: String) -> Bool {
        let pattern = #"^\s*(-\s*)?((page|sivu|sida|side|seite|página|pagina)\s*)?\d{1,4}(\s*(/|of|af|av|von|de|di|-)\s*\d{1,4})?(\s*-)?\s*$"#
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func plainLines(_ page: PDFPage) -> [Element] {
        let text = page.string ?? ""
        return text.components(separatedBy: .newlines).enumerated().compactMap { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : .text(Line(runs: [Run(text: trimmed)], rect: CGRect(x: 0, y: CGFloat(index) * 14, width: 400, height: 12)))
        }
    }

    // MARK: Text

    /// The font the content stream used for a character: the last run of text that starts on its baseline at or
    /// before it.
    static func font(at rect: CGRect, size: CGFloat, in hits: [GraphicsScan.TextHit]) -> GraphicsScan.FontInfo? {
        guard !hits.isEmpty else { return nil }
        let baseline = rect.maxY
        let tolerance = max(size, 1) * 0.45
        var low = 0, high = hits.count
        while low < high {
            let middle = (low + high) / 2
            if hits[middle].point.y < baseline - tolerance { low = middle + 1 } else { high = middle }
        }
        var best: GraphicsScan.TextHit?
        var index = low
        while index < hits.count, hits[index].point.y <= baseline + tolerance {
            let hit = hits[index]
            if hit.point.x <= rect.minX + 1, best.map({ hit.point.x >= $0.point.x }) ?? true { best = hit }
            index += 1
        }
        return best?.font
    }

    static func family(of name: String) -> Family {
        let lower = name.lowercased()
        if ["courier", "mono", "consol", "menlo", "code"].contains(where: { lower.contains($0) }) { return .mono }
        if !lower.contains("sans"), ["times", "serif", "georgia", "garamond", "minion", "cambria", "palatino", "baskerville", "book antiqua", "caslon", "roman"]
            .contains(where: { lower.contains($0) }) { return .serif }
        return .sans
    }

    static func textLines(_ page: PDFPage, box: CGRect, fonts: [GraphicsScan.TextHit] = []) -> [Line] {
        guard let attributed = page.attributedString, attributed.length > 0 else { return [] }
        let plain = (page.string ?? "") as NSString
        // The attributes come from the attributed string, positions from the page; both index the same text.
        let string = attributed.string as NSString
        let sameText = plain.length == string.length
        var lines: [Line] = []
        var current: Line?
        var previous: CGRect?
        var pendingSpace = false
        var bottoms: [CGFloat] = []
        var styleCache: [ObjectIdentifier: (Family, String, Bool, Bool)] = [:]
        // PDFKit names a font it can't load (one embedded in the PDF and not on this Mac) Times. When the page has no
        // serif font of its own, that Times is a stand-in, and the text is set in a sans-serif like most documents.
        let pageHasSerif = fontNames(page).contains { name in
            let lower = name.lowercased()
            return !lower.contains("sans") && ["times", "serif", "georgia", "garamond", "minion", "cambria", "palatino", "baskerville", "caslon", "roman"].contains { lower.contains($0) }
        }

        func flush() {
            if var line = current {
                if var last = line.runs.last {
                    last.text = String(last.text.reversed().drop(while: { $0 == " " }).reversed())
                    line.runs[line.runs.count - 1] = last
                }
                line.runs.removeAll { $0.text.isEmpty }
                // Glyph boxes vary (accents, descenders, dots), so the line gets a box from its baseline and size:
                // most characters sit on the baseline, so the middle of their bottoms is it.
                if !bottoms.isEmpty {
                    let baseline = bottoms.sorted()[bottoms.count / 2]
                    let size = line.size
                    line.rect = CGRect(x: line.rect.minX, y: baseline - size * 0.78, width: line.rect.width, height: size)
                }
                if !line.runs.isEmpty, !line.text.trimmingCharacters(in: .whitespaces).isEmpty { lines.append(line) }
            }
            current = nil
            previous = nil
            pendingSpace = false
            bottoms.removeAll(keepingCapacity: true)
        }

        // On some systems PDFKit leaves the line breaks it adds out of its list of character positions, so every
        // position after one belongs to the next character. When the line breaks themselves come back with real
        // positions, that's the case, and positions are looked up without counting the line breaks.
        var breaks = 0, positioned = 0
        for index in 0..<min(string.length, 20_000) {
            let character = string.character(at: index)
            guard character == 10 || character == 13 else { continue }
            breaks += 1
            if sameText, !page.characterBounds(at: index).isEmpty { positioned += 1 }
        }
        let skipsBreaks = breaks > 0 && positioned * 2 > breaks
        var breaksSoFar = 0

        var index = 0
        while index < string.length {
            let character = string.character(at: index)
            if character == 10 || character == 13 || character == 0x2028 || character == 0x2029 {
                flush()
                if character == 10 || character == 13 { breaksSoFar += 1 }
                index += 1
                continue
            }
            if character == 32 || character == 9 || character == 0xA0 {
                if current != nil { pendingSpace = true }
                index += 1
                continue
            }
            // A surrogate pair is one character on the page.
            let length = (0xD800...0xDBFF).contains(character) && index + 1 < string.length ? 2 : 1
            let position = skipsBreaks ? index - breaksSoFar : index
            var bounds = sameText ? page.characterBounds(at: position) : .zero
            if bounds.isNull || bounds.isInfinite || !bounds.width.isFinite { bounds = .zero }
            let rect = CGRect(x: bounds.minX - box.minX, y: box.maxY - bounds.maxY, width: bounds.width, height: bounds.height)
            var range = NSRange()
            let attributes = attributed.attributes(at: index, effectiveRange: &range)
            let font = attributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: 11)
            let style = styleCache[ObjectIdentifier(font)] ?? {
                var value = describe(font)
                if value.0 == .serif, !pageHasSerif { value = (.sans, "Helvetica", value.2, value.3) }
                styleCache[ObjectIdentifier(font)] = value
                return value
            }()
            var run = Run(text: "", family: style.0, fontName: style.1, size: font.pointSize, bold: style.2, italic: style.3)
            // PDFKit stands Times in for a font it can't load (Calibri, the system font) and drops its weight; the
            // PDF's own font says what it was. Where PDFKit did load it, the PDF can still add bold or italic.
            if let pdfFont = self.font(at: rect, size: font.pointSize, in: fonts) {
                let standIn = (font.familyName ?? font.fontName).hasPrefix("Times") && !pdfFont.family.lowercased().contains("times")
                if standIn {
                    run.family = family(of: pdfFont.family)
                    run.fontName = pdfFont.family
                    run.bold = pdfFont.bold
                    run.italic = pdfFont.italic
                } else {
                    run.bold = run.bold || pdfFont.bold
                    run.italic = run.italic || pdfFont.italic
                }
            }
            if let color = (attributes[.foregroundColor] as? NSColor)?.usingColorSpace(.sRGB) {
                run.color = Color(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
            }
            let text = string.substring(with: NSRange(location: index, length: length))
            index += length

            if bounds == .zero {
                // No position (some synthetic characters): keep the text with what's around it.
                if current != nil { current!.append(text, style: run) }
                continue
            }
            if let last = previous, let line = current?.rect {
                // A new line when the character no longer overlaps the line's height (dots and commas sit low,
                // so they're measured against the whole line, not the letter before).
                let overlap = min(rect.maxY, line.maxY) - max(rect.minY, line.minY)
                let jumped = overlap < min(rect.height, line.height) * 0.3 - 0.01
                let backwards = rect.minX < last.minX - 1
                let gap = rect.minX - last.maxX
                if jumped || backwards || gap > max(10, run.size * 1.2) { flush() }
            }
            if current == nil {
                current = Line(runs: [], rect: rect)
            } else if pendingSpace {
                current!.append(" ", style: run)
            }
            pendingSpace = false
            current!.append(text, style: run)
            current!.rect = current!.rect.union(rect)
            bottoms.append(rect.maxY)
            previous = rect
        }
        flush()
        return joinPieces(lines)
    }

    /// PDFKit sometimes breaks one line into pieces (a bold label, then the rest): joins pieces that touch.
    static func joinPieces(_ lines: [Line]) -> [Line] {
        let sorted = lines.sorted { abs($0.rect.maxY - $1.rect.maxY) > max($0.rect.height, $1.rect.height) * 0.3 ? $0.rect.maxY < $1.rect.maxY : $0.rect.minX < $1.rect.minX }
        var joined: [Line] = []
        for line in sorted {
            if var last = joined.last {
                let height = max(last.rect.height, line.rect.height)
                let gap = line.rect.minX - last.rect.maxX
                if abs(last.rect.maxY - line.rect.maxY) < height * 0.3, gap > -1, gap <= max(10, line.size * 1.2) {
                    if gap > line.size * 0.15, let first = line.runs.first { last.append(" ", style: first) }
                    for run in line.runs { last.append(run.text, style: run) }
                    last.rect = last.rect.union(line.rect)
                    joined[joined.count - 1] = last
                    continue
                }
            }
            joined.append(line)
        }
        return joined
    }

    /// The names of the fonts a page uses, from its resources.
    static func fontNames(_ page: PDFPage) -> [String] {
        guard let dictionary = page.pageRef?.dictionary else { return [] }
        var resources: CGPDFDictionaryRef?, fonts: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources), let resources,
              CGPDFDictionaryGetDictionary(resources, "Font", &fonts), let fonts
        else { return [] }
        var names: [String] = []
        CGPDFDictionaryApplyBlock(fonts, { _, object, _ in
            var font: CGPDFDictionaryRef?
            var name: UnsafePointer<CChar>?
            if CGPDFObjectGetValue(object, .dictionary, &font), let font, CGPDFDictionaryGetName(font, "BaseFont", &name), let name {
                names.append(String(cString: name))
            }
            return true
        }, nil)
        return names
    }

    static func describe(_ font: NSFont) -> (Family, String, Bool, Bool) {
        let name = (font.familyName ?? font.fontName)
        let lower = (font.fontName + " " + name).lowercased()
        let traits = font.fontDescriptor.symbolicTraits
        let bold = traits.contains(.bold) || ["bold", "black", "heavy", "semibold", "demi"].contains { lower.contains($0) }
        let italic = traits.contains(.italic) || lower.contains("italic") || lower.contains("oblique")
        let family: Family
        if traits.contains(.monoSpace) || ["courier", "mono", "consol", "menlo", "code"].contains(where: { lower.contains($0) }) {
            family = .mono
        } else if ["times", "serif", "georgia", "garamond", "minion", "cambria", "palatino", "baskerville", "book antiqua", "caslon"]
            .contains(where: { lower.contains($0) }) && !lower.contains("sans") {
            family = .serif
        } else {
            family = .sans
        }
        // Subset prefixes ("ABCDEF+Helvetica") and style suffixes leave the family a writer can name.
        var clean = name
        if let plus = clean.firstIndex(of: "+"), clean.distance(from: clean.startIndex, to: plus) == 6 { clean = String(clean[clean.index(after: plus)...]) }
        if let dash = clean.firstIndex(of: "-") { clean = String(clean[..<dash]) }
        return (family, clean, bold, italic)
    }

    // MARK: Pictures

    static func extractPictures(_ hits: [GraphicsScan.ImageHit], page: PDFPage, box: CGRect) -> [Picture] {
        var pictures: [Picture] = []
        var rendered: (image: CGImage, scale: CGFloat)?
        for hit in hits {
            let rect = CGRect(x: hit.rect.minX - box.minX, y: box.maxY - hit.rect.maxY, width: hit.rect.width, height: hit.rect.height).standardized
            guard rect.width >= 4, rect.height >= 4 else { continue }
            if let jpeg = hit.jpeg {
                pictures.append(Picture(rect: rect, data: jpeg, isJPEG: true, pixelSize: hit.pixelSize))
                continue
            }
            // Anything else (masks, CMYK, flipped or turned pictures, other encodings) is taken from a rendering
            // of the page, which also shows it the way the PDF does.
            if rendered == nil {
                let longest = max(box.width, box.height)
                let scale = min(2.5, 2000 / max(longest, 1))
                if let image = try? PDFEngine.render(page, dpi: 72 * scale) { rendered = (image, scale) }
            }
            guard let rendered else { continue }
            let (image, scale) = rendered
            let crop = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale).integral
                .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard !crop.isEmpty, let piece = image.cropping(to: crop), let png = pngData(piece) else { continue }
            pictures.append(Picture(rect: rect, data: png, isJPEG: false, pixelSize: CGSize(width: piece.width, height: piece.height)))
        }
        return pictures
    }

    static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    // MARK: Cutting the page

    indirect enum Node {
        case leaf(Element)
        case stack([Node])
        case row([Node])

        var rect: CGRect {
            switch self {
            case .leaf(let element): element.rect
            case .stack(let nodes), .row(let nodes): nodes.reduce(CGRect.null) { $0.union($1.rect) }
            }
        }

        /// Text lines only, top to bottom: a column that can join a data table.
        var textLines: [Line]? {
            switch self {
            case .leaf(.text(let line)): return [line]
            case .leaf: return nil
            case .stack(let nodes):
                var lines: [Line] = []
                for node in nodes {
                    guard let more = node.textLines else { return nil }
                    lines += more
                }
                return lines
            case .row: return nil
            }
        }
    }

    /// Splits elements into bands along horizontal white space, and bands into columns along vertical white space.
    static func cut(_ elements: [Element]) -> Node {
        if elements.count == 1 { return .leaf(elements[0]) }
        let byTop = elements.sorted { $0.rect.minY < $1.rect.minY }
        var bands: [[Element]] = []
        var bottom = -CGFloat.infinity
        for element in byTop {
            if bands.isEmpty || element.rect.minY >= bottom - 1 {
                bands.append([element])
            } else {
                bands[bands.count - 1].append(element)
            }
            bottom = max(bottom, element.rect.maxY)
        }
        if bands.count > 1 { return .stack(bands.map(cut)) }

        let byLeft = elements.sorted { $0.rect.minX < $1.rect.minX }
        var columns: [[Element]] = []
        var right = -CGFloat.infinity
        for element in byLeft {
            if columns.isEmpty || element.rect.minX > right + 6 {
                columns.append([element])
            } else {
                columns[columns.count - 1].append(element)
            }
            right = max(right, element.rect.maxX)
        }
        if columns.count > 1 { return .row(columns.map(cut)) }

        // Overlapping elements (text over a picture, a rule through a line): rules and pictures go first,
        // then the rest is cut again without them.
        let solid = elements.filter { !$0.isText }
        let text = elements.filter(\.isText)
        if !solid.isEmpty, !text.isEmpty {
            return .stack(solid.sorted { $0.rect.minY < $1.rect.minY }.map(Node.leaf) + [cut(text)])
        }
        // Text over text: read it top to bottom, left to right.
        return .stack(byTop.map(Node.leaf))
    }

    // MARK: Building blocks

    static func blocks(_ node: Node, left: CGFloat, width: CGFloat, bodySize: CGFloat) -> [Block] {
        switch node {
        case .leaf(let element):
            return leafBlocks(element, left: left, width: width, bodySize: bodySize)
        case .row(let columns):
            return [rowBlock(columns, left: left, width: width, bodySize: bodySize)]
        case .stack(let children):
            var result: [Block] = []
            var index = 0
            var previousBottom: CGFloat?
            while index < children.count {
                // Lines of one paragraph: same start, size and leading, each but the last running to the right.
                var group = [children[index]]
                if case .leaf(.text(let first)) = children[index] {
                    var last = first
                    var next = index + 1
                    while next < children.count, case .leaf(.text(let line)) = children[next], continues(last, line, left: left, width: width) {
                        group.append(children[next])
                        last = line
                        next += 1
                    }
                }
                let rect = group.reduce(CGRect.null) { $0.union($1.rect) }
                var made: [Block]
                if group.count > 1 {
                    let lines = group.compactMap { node -> Line? in if case .leaf(.text(let line)) = node { line } else { nil } }
                    made = [paragraphBlock(lines, left: left, width: width, bodySize: bodySize)]
                } else {
                    made = blocks(group[0], left: left, width: width, bodySize: bodySize)
                }
                // Space is kept as it is on the page, up to two inches: more than that is a page's empty bottom
                // above a footer, which in a flowing document would only push the footer onto a page of its own.
                if !made.isEmpty, let previousBottom { made[0].spaceBefore += min(144, max(0, rect.minY - previousBottom)) }
                previousBottom = rect.maxY
                for block in made { append(block, to: &result) }
                index += group.count
            }
            return result
        }
    }

    /// Whether `next` carries on the paragraph that `line` belongs to.
    static func continues(_ line: Line, _ next: Line, left: CGFloat, width: CGFloat) -> Bool {
        guard abs(line.rect.minX - next.rect.minX) < 2.5, abs(line.size - next.size) < 0.6 else { return false }
        let gap = next.rect.minY - line.rect.maxY
        guard gap < line.size * 0.6 + 1 else { return false }
        // The line above must have been full: it ran close to the right edge of its column.
        let right = left + width
        guard line.rect.maxX >= right - max(line.size * 6, width * 0.2) else { return false }
        // A bold line over regular text is a heading, not the start of the paragraph.
        if line.isBold != next.isBold { return false }
        // Nor does a list item run into the next one.
        if next.text.range(of: #"^\s*([•▪◦‣∙·*–—-]|\d{1,3}[.)]|[a-z][.)])\s"#, options: .regularExpression) != nil { return false }
        return true
    }

    /// Appends a block, joining a data table onto the one above when their columns line up.
    static func append(_ block: Block, to blocks: inout [Block]) {
        if case .table(let table) = block.kind, table.isData, var last = blocks.last, case .table(let above) = last.kind, above.isData,
           let merged = mergeTables(above, aboveIndent: last.indent, table, indent: block.indent, spacing: block.spaceBefore) {
            last.kind = .table(merged)
            blocks[blocks.count - 1] = last
            return
        }
        blocks.append(block)
    }

    static func leafBlocks(_ element: Element, left: CGFloat, width: CGFloat, bodySize: CGFloat) -> [Block] {
        switch element {
        case .text(let line):
            return [paragraphBlock([line], left: left, width: width, bodySize: bodySize)]
        case .picture(let picture):
            return [Block(kind: .picture(picture), indent: max(0, picture.rect.minX - left))]
        case .rule(let rect, let color):
            return [Block(kind: .rule(width: min(rect.width, width), thickness: max(0.5, rect.height), color: color), indent: max(0, rect.minX - left))]
        case .box(let rect, let color, let children):
            var cell = Cell(shading: color)
            if !children.isEmpty {
                let inner = cut(children)
                cell.blocks = blocks(inner, left: rect.minX, width: rect.width, bodySize: bodySize)
                // Text sitting in the middle of the box stays in the middle.
                let content = inner.rect
                if abs(content.midY - rect.midY) < rect.height * 0.15 { cell.centeredVertically = true }
                if abs(content.midX - rect.midX) < rect.width * 0.1, content.minX - rect.minX > 4 {
                    cell.blocks = cell.blocks.map { block in
                        var block = block
                        if case .paragraph(var paragraph) = block.kind {
                            paragraph.alignment = .center
                            paragraph.heading = 0
                            block.kind = .paragraph(paragraph)
                            block.indent = 0
                        }
                        return block
                    }
                }
                if cell.centeredVertically, !cell.blocks.isEmpty { cell.blocks[0].spaceBefore = 0 }
                else if !cell.blocks.isEmpty { cell.blocks[0].spaceBefore = max(0, content.minY - rect.minY) }
            }
            let table = Table(columns: [min(rect.width, width)], rows: [[cell]], rowSpacing: [0], rowHeights: [rect.height], isData: false)
            return [Block(kind: .table(table), indent: max(0, rect.minX - left))]
        }
    }

    static func paragraphBlock(_ lines: [Line], left: CGFloat, width: CGFloat, bodySize: CGFloat) -> Block {
        var runs: [Run] = []
        for (number, line) in lines.enumerated() {
            for (offset, run) in line.runs.enumerated() {
                var run = run
                if number > 0, offset == 0 {
                    // A word broken at the end of a line ("käyttö-" "ominaisuus") joins up; otherwise a space.
                    if let last = runs.last, last.text.hasSuffix("-"), !last.text.hasSuffix(" -"), run.text.first?.isLowercase == true {
                        runs[runs.count - 1].text.removeLast()
                    } else {
                        run.text = " " + run.text
                    }
                }
                if let last = runs.last, last.sameStyle(run) {
                    runs[runs.count - 1].text += run.text
                } else {
                    runs.append(run)
                }
            }
        }
        var paragraph = Paragraph(runs: runs, lineCount: lines.count)
        let size = lines.map(\.size).max() ?? bodySize
        let text = runs.map(\.text).joined()
        let allBold = lines.allSatisfy(\.isBold)
        if lines.count <= 2, text.count < 120 {
            if size >= bodySize * 1.5 { paragraph.heading = 1 }
            else if size >= bodySize * 1.2 { paragraph.heading = 2 }
            else if allBold, size >= bodySize * 1.05 || runs.allSatisfy(\.underline) { paragraph.heading = 3 }
        }
        let rect = lines.reduce(CGRect.null) { $0.union($1.rect) }
        return Block(kind: .paragraph(paragraph), indent: max(0, rect.minX - left))
    }

    /// Columns side by side: a data table when every column is lines of text, otherwise a layout table whose cells
    /// hold their own blocks (neighbouring text columns still become one data table inside their cell).
    static func rowBlock(_ columns: [Node], left: CGFloat, width: CGFloat, bodySize: CGFloat) -> Block {
        let textColumns = columns.map(\.textLines)
        if textColumns.allSatisfy({ $0 != nil }) {
            return dataTable(textColumns.map { $0! }, left: left, width: width, bodySize: bodySize)
        }
        // Group runs of text columns, so labels and values stay on the same rows.
        var groups: [[Int]] = []
        for index in columns.indices {
            if textColumns[index] != nil, let last = groups.last?.last, textColumns[last] != nil, last == index - 1 {
                groups[groups.count - 1].append(index)
            } else {
                groups.append([index])
            }
        }
        let right = left + width
        let starts = groups.enumerated().map { number, group in number == 0 ? left : columns[group[0]].rect.minX }
        var widths: [CGFloat] = []
        var cells: [Cell] = []
        for (number, group) in groups.enumerated() {
            let start = starts[number]
            let end = number + 1 < starts.count ? starts[number + 1] : max(right, columns[group.last!].rect.maxX)
            let cellWidth = max(end - start, 1)
            widths.append(cellWidth)
            var cell = Cell()
            if group.count > 1 {
                var table = dataTable(group.map { textColumns[$0]! }, left: start, width: cellWidth, bodySize: bodySize)
                table.spaceBefore = 0
                cell.blocks = [table]
                let top = group.map { columns[$0].rect.minY }.min() ?? 0
                cell.blocks[0].spaceBefore = top
            } else {
                let node = columns[group[0]]
                cell.blocks = blocks(node, left: start, width: cellWidth, bodySize: bodySize)
                if !cell.blocks.isEmpty { cell.blocks[0].spaceBefore = node.rect.minY }
            }
            cells.append(cell)
        }
        // Space above each column's content, measured from the top of the row.
        let top = columns.map(\.rect.minY).min() ?? 0
        for index in cells.indices where !cells[index].blocks.isEmpty {
            cells[index].blocks[0].spaceBefore = max(0, cells[index].blocks[0].spaceBefore - top)
        }
        let table = Table(columns: widths, rows: [cells], rowSpacing: [0], rowHeights: [nil], isData: false)
        return Block(kind: .table(table))
    }

    /// Lines in columns, matched into rows by their height on the page.
    static func dataTable(_ columns: [[Line]], left: CGFloat, width: CGFloat, bodySize: CGFloat) -> Block {
        var items: [(column: Int, line: Line)] = []
        for (column, lines) in columns.enumerated() { items += lines.map { (column, $0) } }
        items.sort { $0.line.rect.midY < $1.line.rect.midY }
        var rows: [[(column: Int, line: Line)]] = []
        var rowMid: CGFloat = -.infinity
        for item in items {
            if let last = rows.last, !last.isEmpty, abs(item.line.rect.midY - rowMid) < item.line.rect.height * 0.5 {
                rows[rows.count - 1].append(item)
            } else {
                rows.append([item])
                rowMid = item.line.rect.midY
            }
        }
        let right = left + width
        // Each column starts halfway across the gap before it, so text set in another font has room to grow;
        // indents keep it where the PDF has it.
        let starts = columns.enumerated().map { index, lines -> CGFloat in
            guard index > 0 else { return left }
            let start = lines.map(\.rect.minX).min() ?? left
            let before = columns[index - 1].map(\.rect.maxX).max() ?? start
            return before < start ? (before + start) / 2 : start
        }
        var widths: [CGFloat] = []
        for index in columns.indices {
            let end = index + 1 < starts.count ? starts[index + 1] : max(right, columns[index].map(\.rect.maxX).max() ?? right)
            widths.append(max(end - starts[index], 1))
        }
        // Columns of figures line up on their right edge, headings over the middle sit centered.
        let alignments: [Alignment] = columns.enumerated().map { index, lines in
            // A last column that runs to the right margin (a date in a title row) is set flush right.
            if index == columns.count - 1, index > 0, lines.count == 1, let line = lines.first, line.rect.maxX >= right - 2 { return .right }
            guard lines.count >= 2 else { return .left }
            let lefts = lines.map(\.rect.minX), rights = lines.map(\.rect.maxX), mids = lines.map(\.rect.midX)
            let spread = { (values: [CGFloat]) in (values.max() ?? 0) - (values.min() ?? 0) }
            if spread(lefts) < 2.5 { return .left }
            if spread(rights) < 2.5 { return .right }
            if spread(mids) < 2.5 { return .center }
            return .left
        }
        var tableRows: [[Cell]] = []
        var spacing: [CGFloat] = []
        var previousBottom: CGFloat?
        for row in rows {
            var cells = Array(repeating: Cell(), count: columns.count)
            for (column, line) in row.sorted(by: { $0.line.rect.minX < $1.line.rect.minX }) {
                var block = paragraphBlock([line], left: starts[column], width: widths[column], bodySize: bodySize)
                if case .paragraph(var paragraph) = block.kind {
                    paragraph.alignment = alignments[column]
                    paragraph.heading = 0
                    block.kind = .paragraph(paragraph)
                    if alignments[column] != .left { block.indent = 0 }
                }
                if cells[column].blocks.isEmpty {
                    cells[column].blocks.append(block)
                } else if case .paragraph(var existing) = cells[column].blocks[0].kind, case .paragraph(let more) = block.kind {
                    existing.runs.append(Run(text: " ", size: more.runs.first?.size ?? bodySize))
                    existing.runs += more.runs
                    cells[column].blocks[0].kind = .paragraph(existing)
                }
            }
            let rect = row.reduce(CGRect.null) { $0.union($1.line.rect) }
            spacing.append(previousBottom.map { max(0, rect.minY - $0) } ?? 0)
            previousBottom = rect.maxY
            tableRows.append(cells)
        }
        let spans = columns.map { lines in (lines.map(\.rect.minX).min() ?? 0)...(lines.map(\.rect.maxX).max() ?? 0) }
        let table = Table(columns: widths, rows: tableRows, rowSpacing: spacing, rowHeights: Array(repeating: nil, count: tableRows.count),
                          isData: true, starts: starts, spans: spans)
        var block = Block(kind: .table(table))
        block.spaceBefore = 0
        return block
    }

    /// Two data tables one above the other become one when each column of the one with fewer columns falls on a
    /// column of the other (a total row with fewer cells, say).
    static func mergeTables(_ above: Table, aboveIndent: CGFloat, _ below: Table, indent: CGFloat, spacing: CGFloat) -> Table? {
        guard abs(aboveIndent - indent) < 1, above.spans.count == above.columns.count, below.spans.count == below.columns.count,
              abs(above.columns.reduce(0, +) - below.columns.reduce(0, +)) < 2
        else { return nil }
        let aboveIsBase = above.columns.count >= below.columns.count
        let (base, other) = aboveIsBase ? (above, below) : (below, above)
        // Each column of `other` goes to the column of `base` its text overlaps most, in the same order.
        var mapping: [Int] = []
        for span in other.spans {
            let overlaps = base.spans.map { min($0.upperBound, span.upperBound) - max($0.lowerBound, span.lowerBound) }
            // Overlap counts, less how far apart the columns start (a figure under a long label still belongs to
            // the column it starts in).
            let scores = base.spans.indices.map { overlaps[$0] - abs(base.spans[$0].lowerBound - span.lowerBound) }
            guard let best = scores.indices.max(by: { scores[$0] < scores[$1] }), overlaps[best] > 0,
                  mapping.last.map({ $0 < best }) ?? true
            else { return nil }
            mapping.append(best)
        }
        func spread(_ rows: [[Cell]]) -> [[Cell]] {
            rows.map { row in
                var cells = Array(repeating: Cell(), count: base.columns.count)
                for (index, cell) in row.enumerated() where index < mapping.count {
                    var cell = cell
                    let shift = other.starts[index] - base.starts[mapping[index]]
                    cell.blocks = cell.blocks.map { block in
                        var block = block
                        if case .paragraph(let paragraph) = block.kind, paragraph.alignment == .left { block.indent = max(0, block.indent + shift) }
                        return block
                    }
                    cells[mapping[index]] = cell
                }
                return cells
            }
        }
        var merged = base
        merged.rows = aboveIsBase ? above.rows + spread(below.rows) : spread(above.rows) + below.rows
        merged.rowSpacing = above.rowSpacing + [spacing] + below.rowSpacing.dropFirst()
        merged.rowHeights = above.rowHeights + below.rowHeights
        for (index, column) in mapping.enumerated() {
            let a = merged.spans[column], b = other.spans[index]
            merged.spans[column] = min(a.lowerBound, b.lowerBound)...max(a.upperBound, b.upperBound)
        }
        // The columns move to fit the rows that joined (a longer label in the first column, say).
        let left = merged.starts[0], right = left + merged.columns.reduce(0, +)
        var starts = [left]
        for index in merged.spans.indices.dropFirst() {
            let before = merged.spans[index - 1].upperBound, start = merged.spans[index].lowerBound
            starts.append(max(starts[index - 1] + 1, before < start ? (before + start) / 2 : start))
        }
        for row in merged.rows.indices {
            for column in merged.rows[row].indices {
                let shift = merged.starts[column] - starts[column]
                merged.rows[row][column].blocks = merged.rows[row][column].blocks.map { block in
                    var block = block
                    if case .paragraph(let paragraph) = block.kind, paragraph.alignment == .left { block.indent = max(0, block.indent + shift) }
                    return block
                }
            }
        }
        merged.starts = starts
        merged.columns = starts.indices.map { index in (index + 1 < starts.count ? starts[index + 1] : right) - starts[index] }
        return merged
    }

    // MARK: Plain views of the layout

    /// Every data table's rows, for spreadsheets.
    static func tables(in blocks: [Block]) -> [[[String]]] {
        var found: [[[String]]] = []
        for block in blocks {
            guard case .table(let table) = block.kind else { continue }
            if table.isData {
                found.append(table.rows.map { $0.map { plainText($0.blocks) } })
            } else {
                for row in table.rows { for cell in row { found += tables(in: cell.blocks) } }
            }
        }
        return found
    }

    static func plainText(_ blocks: [Block]) -> String {
        var parts: [String] = []
        for block in blocks {
            switch block.kind {
            case .paragraph(let paragraph): parts.append(paragraph.runs.map(\.text).joined())
            case .table(let table):
                for row in table.rows {
                    if table.isData {
                        parts.append(row.map { plainText($0.blocks) }.joined(separator: "\t"))
                    } else {
                        parts += row.map { plainText($0.blocks) }.filter { !$0.isEmpty }
                    }
                }
            case .pageBreak: parts.append("")
            case .picture, .rule: break
            }
        }
        return parts.joined(separator: "\n")
    }
}
