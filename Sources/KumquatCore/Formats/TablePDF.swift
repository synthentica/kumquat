import CoreGraphics
import CoreText
import Foundation

/// Lays a sheet out on PDF pages directly with Core Text: a fixed grid, one line per cell, the first row
/// repeated as a header on every page, and columns that don't fit continued on further pages.
///
/// The test corpus showed the earlier route (an HTML table laid out by NSTextView on the main thread) freezing
/// the whole app for 111 minutes on a sheet with 50,000 merged cells. This one runs on any thread, takes time
/// in proportion to the cells, and can be stopped between pages.
enum TablePDF {
    private static let margin: CGFloat = 36
    private static let padding: CGFloat = 4
    private static let rowHeight: CGFloat = 14
    private static let fontSize: CGFloat = 8

    static func write(_ rows: [[String]], to output: URL) throws {
        let columnCount = rows.map(\.count).max() ?? 0
        guard columnCount > 0 else { throw OperationError.failed("The sheet is empty.") }
        var page = columnCount > 6
            ? CGRect(x: 0, y: 0, width: 842, height: 595)
            : CGRect(x: 0, y: 0, width: 595, height: 842)

        let regular = CTFontCreateUIFontForLanguage(.system, fontSize, nil) ?? CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let bold = CTFontCreateUIFontForLanguage(.emphasizedSystem, fontSize, nil) ?? regular
        let ink = CGColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
        func line(_ text: String, _ font: CTFont) -> CTLine {
            let flat = text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink,
            ]
            return CTLineCreateWithAttributedString(NSAttributedString(string: flat, attributes: attributes))
        }
        func width(of line: CTLine) -> CGFloat {
            CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        }

        // Column widths from the first few hundred rows, so a long sheet doesn't get measured twice.
        var widths = [CGFloat](repeating: 28, count: columnCount)
        for (index, row) in rows.prefix(300).enumerated() {
            for (column, cell) in row.enumerated() where !cell.isEmpty {
                let measured = width(of: line(cell, index == 0 ? bold : regular)) + 2 * padding
                widths[column] = min(200, max(widths[column], measured))
            }
        }

        // Columns that fit side by side on one page.
        let available = page.width - 2 * margin
        var groups: [Range<Int>] = []
        var start = 0
        var used: CGFloat = 0
        for column in 0..<columnCount {
            if used + widths[column] > available, column > start {
                groups.append(start..<column)
                start = column
                used = 0
            }
            used += widths[column]
        }
        groups.append(start..<columnCount)

        let header = rows.count > 1 ? rows[0] : nil
        let body = header == nil ? rows[...] : rows.dropFirst()
        let perPage = max(1, Int((page.height - 2 * margin) / rowHeight) - (header == nil ? 0 : 1))
        let chunks = stride(from: body.startIndex, to: max(body.endIndex, body.startIndex + 1), by: perPage).map {
            $0..<min($0 + perPage, body.endIndex)
        }
        let totalPages = groups.count * chunks.count

        guard let pdf = CGContext(output as CFURL, mediaBox: &page, nil) else {
            throw OperationError.failed("Couldn't create the PDF.")
        }
        var finished = false
        defer {
            pdf.closePDF()
            if !finished { try? FileManager.default.removeItem(at: output) }
        }

        func draw(_ cells: [String], columns: Range<Int>, top: CGFloat, font: CTFont) {
            var x = margin
            for column in columns {
                let cellWidth = widths[column]
                if column < cells.count, !cells[column].isEmpty {
                    var cellLine = line(cells[column], font)
                    var lineWidth = width(of: cellLine)
                    let room = cellWidth - 2 * padding
                    if lineWidth > room, let cut = CTLineCreateTruncatedLine(cellLine, Double(room), .end, line("…", font)) {
                        cellLine = cut
                        lineWidth = width(of: cut)
                    }
                    // Numbers line up on the right, like in a spreadsheet.
                    let isNumber = Double(cells[column].trimmingCharacters(in: .whitespaces)) != nil
                    let textX = isNumber ? x + cellWidth - padding - lineWidth : x + padding
                    pdf.textPosition = CGPoint(x: textX, y: top - rowHeight + 4.5)
                    CTLineDraw(cellLine, pdf)
                }
                x += cellWidth
            }
        }

        var done = 0
        for columns in groups {
            let tableWidth = columns.reduce(0) { $0 + widths[$1] }
            for chunk in chunks {
                try Task.checkCancellation()
                pdf.beginPage(mediaBox: &page)
                pdf.textMatrix = .identity
                var top = page.height - margin
                let tableTop = top
                if let header {
                    pdf.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1))
                    pdf.fill(CGRect(x: margin, y: top - rowHeight, width: tableWidth, height: rowHeight))
                    draw(header, columns: columns, top: top, font: bold)
                    top -= rowHeight
                }
                for index in chunk {
                    draw(body[index], columns: columns, top: top, font: regular)
                    top -= rowHeight
                }

                // The grid: a line under every row and between every column.
                pdf.setStrokeColor(CGColor(red: 0.82, green: 0.82, blue: 0.85, alpha: 1))
                pdf.setLineWidth(0.5)
                var y = tableTop
                while y >= top - 0.01 {
                    pdf.move(to: CGPoint(x: margin, y: y))
                    pdf.addLine(to: CGPoint(x: margin + tableWidth, y: y))
                    y -= rowHeight
                }
                var x = margin
                pdf.move(to: CGPoint(x: x, y: tableTop))
                pdf.addLine(to: CGPoint(x: x, y: top))
                for column in columns {
                    x += widths[column]
                    pdf.move(to: CGPoint(x: x, y: tableTop))
                    pdf.addLine(to: CGPoint(x: x, y: top))
                }
                pdf.strokePath()
                pdf.endPage()

                done += 1
                WorkProgress.report(done, of: totalPages)
            }
        }
        finished = true
    }
}
