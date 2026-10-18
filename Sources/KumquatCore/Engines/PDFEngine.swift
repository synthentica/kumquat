import AppKit
import Foundation
import PDFKit

/// PDF rendering, text extraction and page tools through PDFKit.
public enum PDFEngine {
    static func open(_ url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else { throw OperationError.unreadable(url.lastPathComponent) }
        if document.isLocked { throw OperationError.failed("\(url.lastPathComponent) is password protected.") }
        return document
    }

    /// Every page as an image at 300 DPI. One page gives one file; more pages give a folder.
    /// `original` names the results when `url` is an intermediate file.
    public static func renderPages(_ url: URL, as format: FileFormat, dpi: CGFloat = 300, naming original: URL? = nil, context: OperationContext) throws -> URL {
        let document = try open(url)
        let named = original ?? url
        guard document.pageCount > 0 else { throw OperationError.failed("The PDF has no pages.") }
        if document.pageCount == 1, let page = document.page(at: 0) {
            let output = context.destination(for: named, extension: format.primaryExtension)
            try ImageEngine.write(try render(page, dpi: dpi), to: output, format: format, quality: context.imageQuality)
            return output
        }
        let folder = context.folderDestination(for: named, suffix: original == nil ? "pages" : "slides")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let digits = String(document.pageCount).count
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let number = String(index + 1).leftPadded(to: digits)
            let output = folder.appendingPathComponent("\(named.baseName) \(number).\(format.primaryExtension)")
            try ImageEngine.write(try render(page, dpi: dpi), to: output, format: format, quality: context.imageQuality)
        }
        return folder
    }

    static func render(_ page: PDFPage, dpi: CGFloat) throws -> CGImage {
        let box = page.bounds(for: .mediaBox)
        let quarterTurned = (page.rotation / 90) % 2 != 0
        let size = quarterTurned ? CGSize(width: box.height, height: box.width) : box.size
        var scale = dpi / 72
        let maxPixels: CGFloat = 120_000_000
        if size.width * size.height * scale * scale > maxPixels {
            scale = (maxPixels / (size.width * size.height)).squareRoot()
        }
        let width = max(1, Int((size.width * scale).rounded()))
        let height = max(1, Int((size.height * scale).rounded()))
        guard let context = ImageEngine.makeContext(width: width, height: height, alpha: false) else {
            throw OperationError.failed("The page is too large to render.")
        }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.scaleBy(x: scale, y: scale)
        page.transform(context, for: .mediaBox)
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage() else { throw OperationError.failed("Couldn't render the page.") }
        return image
    }

    public static func attributedText(_ url: URL) throws -> NSAttributedString {
        let document = try open(url)
        let text = NSMutableAttributedString()
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index)?.attributedString else { continue }
            if text.length > 0 { text.append(NSAttributedString(string: "\n\n")) }
            text.append(page)
        }
        return text
    }

    /// Text laid out in rows, with columns split where the text has wide gaps or tabs.
    static func tableRows(_ url: URL) throws -> [[String]] {
        let document = try open(url)
        var rows: [[String]] = []
        for index in 0..<document.pageCount {
            guard let text = document.page(at: index)?.string else { continue }
            for line in text.components(separatedBy: .newlines) {
                let cells = line
                    .replacingOccurrences(of: "\t| {2,}", with: "\u{1F}", options: .regularExpression)
                    .components(separatedBy: "\u{1F}")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if cells.contains(where: { !$0.isEmpty }) { rows.append(cells) }
            }
        }
        guard !rows.isEmpty else { throw OperationError.failed("The PDF has no text. Scanned pages can't become a table.") }
        let width = rows.map(\.count).max() ?? 0
        return rows.map { $0 + Array(repeating: "", count: width - $0.count) }
    }

    public static func compress(_ url: URL, context: OperationContext) throws -> URL {
        let document = try open(url)
        let output = context.destination(for: url, extension: "pdf", suffix: "compressed")
        var options: [PDFDocumentWriteOption: Any] = [:]
        if #available(macOS 13.4, *) {
            options[.saveImagesAsJPEGOption] = true
            options[.optimizeImagesForScreenOption] = true
        }
        guard document.write(to: output, withOptions: options) else { throw OperationError.failed("Couldn't write the PDF.") }
        return try keepIfSmaller(output, than: url)
    }

    public static func split(_ url: URL, context: OperationContext) throws -> URL {
        let document = try open(url)
        guard document.pageCount > 1 else { throw OperationError.failed("The PDF has only one page.") }
        let folder = context.folderDestination(for: url, suffix: "pages")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let digits = String(document.pageCount).count
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
            let single = PDFDocument()
            single.insert(page, at: 0)
            let number = String(index + 1).leftPadded(to: digits)
            single.write(to: folder.appendingPathComponent("\(url.baseName) \(number).pdf"))
        }
        return folder
    }

    public static func merge(_ urls: [URL], context: OperationContext) throws -> URL {
        let merged = PDFDocument()
        for url in urls {
            let document = try open(url)
            for index in 0..<document.pageCount {
                guard let page = document.page(at: index)?.copy() as? PDFPage else { continue }
                merged.insert(page, at: merged.pageCount)
            }
        }
        let output = context.destination(for: urls[0], name: "Merged", extension: "pdf")
        guard merged.write(to: output) else { throw OperationError.failed("Couldn't write the PDF.") }
        return output
    }

    public static func rotate(_ url: URL, context: OperationContext) throws -> URL {
        let document = try open(url)
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            page.rotation = (page.rotation + 90) % 360
        }
        let output = context.destination(for: url, extension: "pdf", suffix: "rotated")
        guard document.write(to: output) else { throw OperationError.failed("Couldn't write the PDF.") }
        return output
    }
}

extension String {
    func leftPadded(to length: Int, with pad: Character = "0") -> String {
        count >= length ? self : String(repeating: pad, count: length - count) + self
    }
}
