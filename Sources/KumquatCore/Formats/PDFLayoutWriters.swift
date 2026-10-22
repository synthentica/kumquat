import AppKit
import Foundation

// Writers for a PDF read with `PDFLayout`: Word, HTML (and the XHTML inside an EPUB), Markdown and plain text.

// MARK: Word

enum LayoutDOCX {
    static func write(_ document: PDFLayout.Document, to output: URL) async throws {
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        let fm = FileManager.default
        for folder in ["_rels", "word/_rels", "word/media"] {
            try fm.createDirectory(at: work.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        var writer = Writer()
        let body = writer.blocks(document.blocks, width: document.contentWidth)
        for (index, picture) in writer.pictures.enumerated() {
            try picture.data.write(to: work.appendingPathComponent("word/media/image\(index + 1).\(picture.isJPEG ? "jpeg" : "png")"))
        }

        let page = document.pageSize
        let m = document.margins
        let landscape = page.width > page.height ? #" w:orient="landscape""# : ""
        let section = #"<w:sectPr><w:pgSz w:w="\#(twips(page.width))" w:h="\#(twips(page.height))"\#(landscape)/><w:pgMar w:top="\#(twips(m.top))" w:right="\#(twips(m.right))" w:bottom="\#(twips(m.bottom))" w:left="\#(twips(m.left))" w:header="0" w:footer="0" w:gutter="0"/></w:sectPr>"#
        let header = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#
        let namespaces = [
            #"xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main""#,
            #"xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships""#,
            #"xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing""#,
            #"xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main""#,
            #"xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture""#,
        ].joined(separator: " ")
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        var relationships = #"<Relationship Id="rIdStyles" Type="\#(rel)/styles" Target="styles.xml"/>"#
        for (index, picture) in writer.pictures.enumerated() {
            relationships += #"<Relationship Id="rIdImage\#(index + 1)" Type="\#(rel)/image" Target="media/image\#(index + 1).\#(picture.isJPEG ? "jpeg" : "png")"/>"#
        }
        let bodySize = Int((document.bodySize * 2).rounded())
        let files: [String: String] = [
            "[Content_Types].xml": header + """
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
            <Default Extension="xml" ContentType="application/xml"/>\
            <Default Extension="jpeg" ContentType="image/jpeg"/>\
            <Default Extension="png" ContentType="image/png"/>\
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\
            <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>\
            </Types>
            """,
            "_rels/.rels": header + """
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
            <Relationship Id="rId1" Type="\(rel)/officeDocument" Target="word/document.xml"/>\
            </Relationships>
            """,
            "word/_rels/document.xml.rels": header + """
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\(relationships)</Relationships>
            """,
            "word/styles.xml": header + """
            <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">\
            <w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:eastAsia="Arial" w:cs="Arial"/>\
            <w:sz w:val="\(bodySize)"/><w:szCs w:val="\(bodySize)"/></w:rPr></w:rPrDefault>\
            <w:pPrDefault><w:pPr><w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>\
            <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>\
            <w:style w:type="table" w:default="1" w:styleId="TableNormal"><w:name w:val="Normal Table"/><w:uiPriority w:val="99"/><w:semiHidden/>\
            <w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="0" w:type="dxa"/>\
            <w:bottom w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>\
            </w:styles>
            """,
            "word/document.xml": header + "<w:document \(namespaces)><w:body>\(body)\(section)</w:body></w:document>",
        ]
        for (path, contents) in files {
            try contents.write(to: work.appendingPathComponent(path), atomically: true, encoding: .utf8)
        }
        try? fm.removeItem(at: output)
        try await Zip.create(output, from: work, entries: ["[Content_Types].xml", "_rels", "word"])
    }

    static func twips(_ points: CGFloat) -> Int { Int((points * 20).rounded()) }
    static func emu(_ points: CGFloat) -> Int { Int((points * 12700).rounded()) }

    struct Writer {
        var pictures: [PDFLayout.Picture] = []

        mutating func blocks(_ blocks: [PDFLayout.Block], width: CGFloat) -> String {
            var xml = ""
            for block in blocks { xml += self.block(block, width: width) }
            return xml
        }

        mutating func block(_ block: PDFLayout.Block, width: CGFloat) -> String {
            let spacing = #"<w:spacing w:before="\#(twips(block.spaceBefore))" w:after="0"/>"#
            let indent = block.indent > 0.5 ? #"<w:ind w:left="\#(twips(block.indent))"/>"# : ""
            switch block.kind {
            case .paragraph(let paragraph):
                let align: String
                switch paragraph.alignment {
                case .left: align = ""
                case .center: align = #"<w:jc w:val="center"/>"#
                case .right: align = #"<w:jc w:val="right"/>"#
                }
                let keep = paragraph.heading > 0 ? "<w:keepNext/>" : ""
                return "<w:p><w:pPr>\(keep)\(spacing)\(paragraph.alignment == .left ? indent : "")\(align)</w:pPr>\(runs(paragraph.runs))</w:p>"
            case .picture(let picture):
                guard !picture.data.isEmpty else { return "" }
                pictures.append(picture)
                let number = pictures.count
                // A picture wider than the space it lands in is scaled down to fit.
                let scale = min(1, max(width - block.indent, 1) / max(picture.rect.width, 1))
                let cx = emu(picture.rect.width * scale), cy = emu(picture.rect.height * scale)
                let name = "image\(number).\(picture.isJPEG ? "jpeg" : "png")"
                let drawing = """
                <w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="\(cx)" cy="\(cy)"/>\
                <wp:docPr id="\(number)" name="Picture \(number)"/><wp:cNvGraphicFramePr/>\
                <a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">\
                <pic:pic><pic:nvPicPr><pic:cNvPr id="\(number)" name="\(name)"/><pic:cNvPicPr/></pic:nvPicPr>\
                <pic:blipFill><a:blip r:embed="rIdImage\(number)"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>\
                <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>\
                </pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing>
                """
                return #"<w:p><w:pPr>\#(spacing)\#(indent)</w:pPr><w:r>\#(drawing)</w:r></w:p>"#
            case .rule(let ruleWidth, let thickness, let color):
                let size = min(96, max(2, Int((thickness * 8).rounded())))
                let right = max(0, width - block.indent - ruleWidth)
                let ind = #"<w:ind w:left="\#(twips(block.indent))" w:right="\#(twips(right))"/>"#
                return #"<w:p><w:pPr><w:pBdr><w:bottom w:val="single" w:sz="\#(size)" w:space="0" w:color="\#(color.hex)"/></w:pBdr><w:spacing w:before="\#(twips(block.spaceBefore))" w:after="0" w:line="20" w:lineRule="exact"/>\#(ind)<w:rPr><w:sz w:val="2"/></w:rPr></w:pPr></w:p>"#
            case .table(let table):
                return self.table(table, block: block, width: width)
            case .pageBreak:
                // The next page starts with a paragraph that asks for a new page, so a page that runs over doesn't
                // leave a blank one behind.
                return #"<w:p><w:pPr><w:pageBreakBefore/><w:spacing w:before="0" w:after="0" w:line="20" w:lineRule="exact"/><w:rPr><w:sz w:val="2"/></w:rPr></w:pPr></w:p>"#
            }
        }

        func runs(_ runs: [PDFLayout.Run]) -> String {
            runs.map { run in
                let font = fontName(run)
                var properties = #"<w:rFonts w:ascii="\#(font)" w:hAnsi="\#(font)" w:cs="\#(font)"/>"#
                if run.bold { properties += "<w:b/><w:bCs/>" }
                if run.italic { properties += "<w:i/><w:iCs/>" }
                if !run.color.isBlack { properties += #"<w:color w:val="\#(run.color.hex)"/>"# }
                let size = Int((run.size * 2).rounded())
                properties += #"<w:sz w:val="\#(size)"/><w:szCs w:val="\#(size)"/>"#
                if run.underline { properties += #"<w:u w:val="single"/>"# }
                return #"<w:r><w:rPr>\#(properties)</w:rPr><w:t xml:space="preserve">\#(run.text.xmlEscaped)</w:t></w:r>"#
            }.joined()
        }

        func fontName(_ run: PDFLayout.Run) -> String {
            switch run.family {
            case .serif: return run.fontName.lowercased().contains("times") ? "Times New Roman" : run.fontName.xmlEscaped
            case .mono: return "Courier New"
            case .sans:
                // Helvetica isn't on Windows or in LibreOffice everywhere; Arial has its widths and is.
                let lower = run.fontName.lowercased()
                return lower.contains("helvetica") || lower.contains("arial") || run.fontName.isEmpty ? "Arial" : run.fontName.xmlEscaped
            }
        }

        mutating func table(_ table: PDFLayout.Table, block: PDFLayout.Block, width: CGFloat) -> String {
            let total = table.columns.reduce(0, +)
            // A table that would run past the margin is scaled down to fit.
            let scale = min(1, max(width - block.indent, 1) / max(total, 1))
            let columns = table.columns.map { $0 * scale }
            var xml = "<w:tbl><w:tblPr>"
            xml += #"<w:tblW w:w="\#(twips(columns.reduce(0, +)))" w:type="dxa"/>"#
            if block.indent > 0.5 { xml += #"<w:tblInd w:w="\#(twips(block.indent))" w:type="dxa"/>"# }
            xml += "<w:tblBorders>" + ["top", "left", "bottom", "right", "insideH", "insideV"].map { #"<w:\#($0) w:val="nil"/>"# }.joined() + "</w:tblBorders>"
            xml += #"<w:tblLayout w:type="fixed"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="0" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="0" w:type="dxa"/></w:tblCellMar><w:tblLook w:val="0000"/></w:tblPr>"#
            xml += "<w:tblGrid>" + columns.map { #"<w:gridCol w:w="\#(twips($0))"/>"# }.joined() + "</w:tblGrid>"
            for (number, row) in table.rows.enumerated() {
                xml += "<w:tr>"
                if let height = table.rowHeights[number] {
                    xml += #"<w:trPr><w:cantSplit/><w:trHeight w:val="\#(twips(height))" w:hRule="atLeast"/></w:trPr>"#
                } else {
                    xml += "<w:trPr><w:cantSplit/></w:trPr>"
                }
                for (column, cell) in row.enumerated() {
                    let cellWidth = columns[min(column, columns.count - 1)]
                    xml += #"<w:tc><w:tcPr><w:tcW w:w="\#(twips(cellWidth))" w:type="dxa"/>"#
                    if let shading = cell.shading { xml += #"<w:shd w:val="clear" w:color="auto" w:fill="\#(shading.hex)"/>"# }
                    if cell.centeredVertically { xml += #"<w:vAlign w:val="center"/>"# }
                    xml += "</w:tcPr>"
                    var blocks = cell.blocks
                    // Space between rows goes on the first paragraph of every cell, so the row moves down as a whole.
                    if number > 0, !blocks.isEmpty { blocks[0].spaceBefore += table.rowSpacing[number] }
                    var content = self.blocks(blocks, width: cellWidth)
                    // A cell must end with a paragraph.
                    if blocks.isEmpty || content.isEmpty || content.hasSuffix("</w:tbl>") {
                        let before = number > 0 && blocks.isEmpty ? twips(table.rowSpacing[number]) : 0
                        content += #"<w:p><w:pPr><w:spacing w:before="\#(before)" w:after="0" w:line="20" w:lineRule="exact"/><w:rPr><w:sz w:val="2"/></w:rPr></w:pPr></w:p>"#
                    }
                    xml += content + "</w:tc>"
                }
                xml += "</w:tr>"
            }
            xml += "</w:tbl>"
            if block.spaceBefore > 0.5 {
                // Tables have no space before of their own: an exact-height empty paragraph holds it.
                let gap = #"<w:p><w:pPr><w:spacing w:before="0" w:after="0" w:line="\#(max(20, twips(block.spaceBefore)))" w:lineRule="exact"/><w:rPr><w:sz w:val="2"/></w:rPr></w:pPr></w:p>"#
                return gap + xml
            }
            return xml
        }
    }
}

// MARK: HTML and XHTML

enum LayoutHTML {
    /// A whole HTML page with the pictures inside it.
    static func document(_ document: PDFLayout.Document, title: String) -> String {
        var writer = Writer(xhtml: false)
        let body = writer.blocks(document.blocks, width: document.contentWidth)
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(title.xmlEscaped)</title>
        <style>\(stylesheet(document))</style></head>
        <body><div class="page">
        \(body)
        </div></body></html>
        """
    }

    /// The body and pictures for an EPUB chapter; pictures are files next to it.
    static func xhtml(_ document: PDFLayout.Document) -> (body: String, css: String, pictures: [(name: String, data: Data, mediaType: String)]) {
        var writer = Writer(xhtml: true)
        let body = writer.blocks(document.blocks, width: document.contentWidth)
        return ("<div class=\"page\">\n\(body)\n</div>", stylesheet(document), writer.files)
    }

    static func stylesheet(_ document: PDFLayout.Document) -> String {
        let m = document.margins
        return """
        body { margin: 0; background: #fff; color: #000; font-family: Helvetica, Arial, sans-serif; font-size: \(points(document.bodySize)); }
        .page { max-width: \(points(document.pageSize.width)); margin: 0 auto; padding: \(points(m.top)) \(points(m.right)) \(points(m.bottom)) \(points(m.left)); box-sizing: border-box; }
        p, h1, h2, h3 { margin: 0; line-height: 1.2; font-weight: normal; font-size: inherit; }
        table.layout, table.data { border-collapse: collapse; table-layout: fixed; }
        td { padding: 0; vertical-align: top; }
        img { display: block; max-width: 100%; height: auto; }
        hr { border: 0; margin: 0; }
        .break { border-top: 1px dashed #bbb; margin: 24pt 0; page-break-after: always; }
        """
    }

    static func points(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))pt" : "\(rounded)pt"
    }

    struct Writer {
        let xhtml: Bool
        var files: [(name: String, data: Data, mediaType: String)] = []

        mutating func blocks(_ blocks: [PDFLayout.Block], width: CGFloat) -> String {
            blocks.map { block($0, width: width) }.joined(separator: "\n")
        }

        mutating func block(_ block: PDFLayout.Block, width: CGFloat) -> String {
            var style: [String] = []
            if block.spaceBefore > 0.5 { style.append("margin-top: \(points(block.spaceBefore))") }
            if block.indent > 0.5 { style.append("margin-left: \(points(block.indent))") }
            switch block.kind {
            case .paragraph(let paragraph):
                switch paragraph.alignment {
                case .left: break
                case .center: style.append("text-align: center")
                case .right: style.append("text-align: right")
                }
                let tag = paragraph.heading > 0 ? "h\(paragraph.heading)" : "p"
                return "<\(tag)\(attribute(style))>\(runs(paragraph.runs))</\(tag)>"
            case .picture(let picture):
                guard !picture.data.isEmpty else { return "" }
                let type = picture.isJPEG ? "image/jpeg" : "image/png"
                let source: String
                if xhtml {
                    let name = "images/picture\(files.count + 1).\(picture.isJPEG ? "jpg" : "png")"
                    files.append((name, picture.data, type))
                    source = name
                } else {
                    source = "data:\(type);base64,\(picture.data.base64EncodedString())"
                }
                style.append("width: \(points(min(picture.rect.width, max(width - block.indent, 1))))")
                let close = xhtml ? "/>" : ">"
                return "<img src=\"\(source)\" alt=\"\"\(attribute(style))\(close)"
            case .rule(let ruleWidth, let thickness, let color):
                style.append("width: \(points(ruleWidth))")
                style.append("border-top: \(points(max(0.5, thickness))) solid #\(color.hex)")
                return xhtml ? "<hr\(attribute(style))/>" : "<hr\(attribute(style))>"
            case .table(let table):
                return self.table(table, style: style, width: width)
            case .pageBreak:
                return xhtml ? "<div class=\"break\"></div>" : "<div class=\"break\"></div>"
            }
        }

        func attribute(_ style: [String]) -> String {
            style.isEmpty ? "" : " style=\"\(style.joined(separator: "; "))\""
        }

        func runs(_ runs: [PDFLayout.Run]) -> String {
            runs.map { run in
                var style: [String] = []
                // The PDF's own font first (Calibri stays Calibri), then what's on every Mac and PC.
                let named = run.fontName.isEmpty || ["helvetica", "arial", "times", "courier"].contains { run.fontName.lowercased().hasPrefix($0) }
                    ? "" : "'\(run.fontName.replacingOccurrences(of: "'", with: ""))', "
                switch run.family {
                case .serif: style.append("font-family: \(named)'Times New Roman', Times, serif")
                case .mono: style.append("font-family: \(named)Menlo, 'Courier New', monospace")
                case .sans: if !named.isEmpty { style.append("font-family: \(named)Helvetica, Arial, sans-serif") }
                }
                style.append("font-size: \(points(run.size))")
                if run.bold { style.append("font-weight: bold") }
                if run.italic { style.append("font-style: italic") }
                if run.underline { style.append("text-decoration: underline") }
                if !run.color.isBlack { style.append("color: #\(run.color.hex)") }
                return "<span style=\"\(style.joined(separator: "; "))\">\(run.text.xmlEscaped)</span>"
            }.joined()
        }

        mutating func table(_ table: PDFLayout.Table, style: [String], width: CGFloat) -> String {
            var style = style
            let total = table.columns.reduce(0, +)
            style.append("width: \(points(total))")
            style.append("max-width: 100%")
            var html = "<table class=\"\(table.isData ? "data" : "layout")\"\(attribute(style))><colgroup>"
            html += table.columns.map { "<col style=\"width: \(points($0))\"\(xhtml ? "/" : "")>" }.joined()
            html += "</colgroup><tbody>"
            for (number, row) in table.rows.enumerated() {
                html += "<tr>"
                for (column, cell) in row.enumerated() {
                    var cellStyle: [String] = []
                    if let shading = cell.shading { cellStyle.append("background: #\(shading.hex)") }
                    if let height = table.rowHeights[number] { cellStyle.append("height: \(points(height))") }
                    if cell.centeredVertically { cellStyle.append("vertical-align: middle") }
                    var blocks = cell.blocks
                    if number > 0, !blocks.isEmpty { blocks[0].spaceBefore += table.rowSpacing[number] }
                    if number > 0, blocks.isEmpty, table.rowSpacing[number] > 0.5 { cellStyle.append("padding-top: \(points(table.rowSpacing[number]))") }
                    let cellWidth = table.columns[min(column, table.columns.count - 1)]
                    html += "<td\(attribute(cellStyle))>\(self.blocks(blocks, width: cellWidth))</td>"
                }
                html += "</tr>"
            }
            return html + "</tbody></table>"
        }
    }
}

// MARK: Markdown and plain text

enum LayoutText {
    static func markdown(_ document: PDFLayout.Document) -> String {
        var parts: [String] = []
        func emit(_ blocks: [PDFLayout.Block]) {
            for block in blocks {
                switch block.kind {
                case .paragraph(let paragraph):
                    let text = inline(paragraph.runs)
                    guard !text.isEmpty else { continue }
                    parts.append(paragraph.heading > 0 ? String(repeating: "#", count: paragraph.heading) + " " + plain(paragraph.runs) : text)
                case .table(let table):
                    if table.isData, table.columns.count > 1 {
                        parts.append(gfm(table))
                    } else {
                        for row in table.rows { for cell in row { emit(cell.blocks) } }
                    }
                case .rule: parts.append("---")
                case .pageBreak: parts.append("---")
                case .picture: break
                }
            }
        }
        emit(document.blocks)
        // Two rules in a row (a rule just before a page break) read as one.
        var cleaned: [String] = []
        for part in parts where !(part == "---" && cleaned.last == "---") { cleaned.append(part) }
        while cleaned.first == "---" { cleaned.removeFirst() }
        while cleaned.last == "---" { cleaned.removeLast() }
        return cleaned.joined(separator: "\n\n") + "\n"
    }

    static func gfm(_ table: PDFLayout.Table) -> String {
        let rows = table.rows.map { row in row.map { PDFLayout.plainText($0.blocks).replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ") } }
        guard let header = rows.first else { return "" }
        var lines = ["| " + header.joined(separator: " | ") + " |"]
        lines.append("|" + header.map { _ in " --- " }.joined(separator: "|") + "|")
        for row in rows.dropFirst() { lines.append("| " + row.joined(separator: " | ") + " |") }
        return lines.joined(separator: "\n")
    }

    static func plain(_ runs: [PDFLayout.Run]) -> String {
        runs.map(\.text).joined().trimmingCharacters(in: .whitespaces)
    }

    static func inline(_ runs: [PDFLayout.Run]) -> String {
        var text = ""
        for run in runs {
            let (lead, core, trail) = run.text.splitWhitespace()
            guard !core.isEmpty else { text += run.text; continue }
            var escaped = core.replacingOccurrences(of: "*", with: "\\*").replacingOccurrences(of: "_", with: "\\_")
            if run.bold && run.italic { escaped = "***\(escaped)***" }
            else if run.bold { escaped = "**\(escaped)**" }
            else if run.italic { escaped = "*\(escaped)*" }
            text += lead + escaped + trail
        }
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// Paragraphs with a blank line between them; table rows on lines of their own, cells split by tabs.
    static func text(_ document: PDFLayout.Document) -> String {
        var parts: [String] = []
        func emit(_ blocks: [PDFLayout.Block]) {
            for block in blocks {
                switch block.kind {
                case .paragraph(let paragraph):
                    let text = plain(paragraph.runs)
                    if !text.isEmpty { parts.append(text) }
                case .table(let table) where table.isData:
                    parts.append(table.rows.map { row in row.map { PDFLayout.plainText($0.blocks) }.joined(separator: "\t") }.joined(separator: "\n"))
                case .table(let table):
                    for row in table.rows { for cell in row { emit(cell.blocks) } }
                case .picture, .rule, .pageBreak:
                    break
                }
            }
        }
        emit(document.blocks)
        return parts.joined(separator: "\n\n") + "\n"
    }
}

// MARK: RTF

/// The layout as Cocoa text, with real text tables, for RTF. (Cocoa's RTF has no room for pictures.)
enum LayoutRichText {
    static func attributedString(_ document: PDFLayout.Document) -> NSAttributedString {
        let text = NSMutableAttributedString()
        append(flatten(document.blocks), to: text, width: document.contentWidth, enclosing: [])
        return text
    }

    /// RTF readers handle one level of tables at best, so layout tables give way to their contents and only data
    /// tables and shaded boxes stay tables.
    static func flatten(_ blocks: [PDFLayout.Block]) -> [PDFLayout.Block] {
        var flat: [PDFLayout.Block] = []
        for block in blocks {
            guard case .table(let table) = block.kind else { flat.append(block); continue }
            let nested = table.rows.contains { $0.contains { cell in cell.blocks.contains { if case .table = $0.kind { true } else { false } } } }
            if table.isData || (!nested && table.rows.count == 1 && table.columns.count == 1) {
                flat.append(block)
                continue
            }
            var first = true
            for row in table.rows {
                for cell in row {
                    var inner = flatten(cell.blocks)
                    if first, !inner.isEmpty { inner[0].spaceBefore += block.spaceBefore; first = false }
                    flat += inner.map { inner in
                        var inner = inner
                        if case .paragraph = inner.kind { inner.indent = 0 }
                        return inner
                    }
                }
            }
        }
        return flat
    }

    static func append(_ blocks: [PDFLayout.Block], to text: NSMutableAttributedString, width: CGFloat, enclosing: [NSTextBlock]) {
        for block in blocks {
            switch block.kind {
            case .paragraph(let paragraph):
                let style = NSMutableParagraphStyle()
                style.paragraphSpacingBefore = block.spaceBefore
                style.textBlocks = enclosing
                switch paragraph.alignment {
                case .left:
                    style.firstLineHeadIndent = block.indent
                    style.headIndent = block.indent
                case .center: style.alignment = .center
                case .right: style.alignment = .right
                }
                for run in paragraph.runs {
                    text.append(NSAttributedString(string: run.text, attributes: attributes(run, style)))
                }
                text.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: style, .font: font(paragraph.runs.last)]))
            case .rule(_, let thickness, let color):
                // A paragraph with a bottom border stands in for the line.
                let table = NSTextTable()
                table.numberOfColumns = 1
                let cell = NSTextTableBlock(table: table, startingRow: 0, rowSpan: 1, startingColumn: 0, columnSpan: 1)
                cell.setValue(width - block.indent, type: .absoluteValueType, for: .width)
                cell.setWidth(max(0.5, thickness), type: .absoluteValueType, for: .border, edge: .maxY)
                cell.setBorderColor(NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1), for: .maxY)
                let style = NSMutableParagraphStyle()
                style.textBlocks = enclosing + [cell]
                style.paragraphSpacingBefore = block.spaceBefore
                style.maximumLineHeight = 2
                text.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: style, .font: NSFont.systemFont(ofSize: 1)]))
            case .table(let table):
                let textTable = NSTextTable()
                textTable.numberOfColumns = max(1, table.columns.count)
                textTable.layoutAlgorithm = .fixedLayoutAlgorithm
                textTable.collapsesBorders = true
                textTable.setValue(table.columns.reduce(0, +), type: .absoluteValueType, for: .width)
                for (number, row) in table.rows.enumerated() {
                    for (column, cell) in row.enumerated() {
                        let cellBlock = NSTextTableBlock(table: textTable, startingRow: number, rowSpan: 1, startingColumn: column, columnSpan: 1)
                        cellBlock.setValue(table.columns[min(column, table.columns.count - 1)], type: .absoluteValueType, for: .width)
                        if let shading = cell.shading {
                            cellBlock.backgroundColor = NSColor(srgbRed: shading.red, green: shading.green, blue: shading.blue, alpha: 1)
                        }
                        if let height = table.rowHeights[number] { cellBlock.setValue(height, type: .absoluteValueType, for: .minimumHeight) }
                        if cell.centeredVertically { cellBlock.verticalAlignment = .middleAlignment }
                        var blocks = cell.blocks
                        if blocks.isEmpty { blocks = [PDFLayout.Block(kind: .paragraph(PDFLayout.Paragraph(runs: [PDFLayout.Run(text: "")])))] }
                        if number > 0 { blocks[0].spaceBefore += table.rowSpacing[number] }
                        if number == 0 { blocks[0].spaceBefore += block.spaceBefore }
                        append(blocks, to: text, width: table.columns[min(column, table.columns.count - 1)], enclosing: enclosing + [cellBlock])
                    }
                }
            case .picture, .pageBreak:
                break
            }
        }
    }

    static func font(_ run: PDFLayout.Run?) -> NSFont {
        guard let run else { return NSFont(name: "Helvetica", size: 11) ?? .systemFont(ofSize: 11) }
        let family: String
        switch run.family {
        case .sans: family = "Helvetica"
        case .serif: family = "Times New Roman"
        case .mono: family = "Courier"
        }
        var traits: NSFontTraitMask = []
        if run.bold { traits.insert(.boldFontMask) }
        if run.italic { traits.insert(.italicFontMask) }
        return NSFontManager.shared.font(withFamily: family, traits: traits, weight: 5, size: run.size)
            ?? NSFont(name: family, size: run.size) ?? .systemFont(ofSize: run.size)
    }

    static func attributes(_ run: PDFLayout.Run, _ style: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(run),
            .foregroundColor: NSColor(srgbRed: run.color.red, green: run.color.green, blue: run.color.blue, alpha: 1),
            .paragraphStyle: style,
        ]
        if run.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        return attributes
    }
}
