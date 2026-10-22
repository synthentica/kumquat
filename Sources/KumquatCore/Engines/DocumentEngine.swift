import AppKit
import Foundation

/// Text documents through Cocoa's text system: DOCX, DOC, RTF, RTFD, ODT, HTML, TXT,
/// plus Markdown and EPUB handled in this package.
public enum DocumentEngine {
    public static func read(_ url: URL) async throws -> NSAttributedString {
        switch FileFormat.detect(url) {
        case .docx: return try load(url, .officeOpenXML)
        case .doc: return try load(url, .docFormat)
        case .rtf: return try load(url, .rtf)
        case .rtfd: return try load(url, .rtfd)
        case .odt: return try load(url, .openDocument)
        case .html:
            let html = try readText(url)
            return try await attributed(html: html, baseURL: url.deletingLastPathComponent())
        case .markdown:
            let html = Markdown.htmlDocument(from: try readText(url), title: url.baseName)
            return try await attributed(html: html, baseURL: url.deletingLastPathComponent())
        case .txt:
            return plain(try readText(url))
        case .epub:
            let book = try await EPUB.read(url)
            defer { book.cleanUp() }
            return try await attributed(html: book.html, baseURL: book.baseURL)
        case .pdf:
            return try PDFEngine.attributedText(url)
        case .textClipping:
            return try clipping(url)
        default:
            throw OperationError.unsupported("This document type")
        }
    }

    public static func convert(_ url: URL, to format: FileFormat, context: OperationContext) async throws -> URL {
        let source = FileFormat.detect(url)
        let output = context.destination(for: url, extension: format.primaryExtension)
        do {
            // Markdown keeps its structure best when converted directly.
            if source == .markdown, format == .html || format == .epub {
                let markdown = try readText(url)
                if format == .html {
                    try Markdown.htmlDocument(from: markdown, title: url.baseName).write(to: output, atomically: true, encoding: .utf8)
                } else {
                    try await EPUB.write(title: url.baseName, bodyXHTML: Markdown.xhtml(from: markdown), to: output)
                }
                return output
            }
            // PDFs keep their layout: pictures, tables, columns and headings (see PDFLayout).
            if source == .pdf, [.docx, .html, .epub, .markdown, .txt, .rtf, .pages].contains(format) {
                try await convertPDF(url, to: format, output: output, title: url.baseName)
                return output
            }
            if source == .txt, format == .markdown {
                try FileManager.default.copyItem(at: url, to: output)
                return output
            }
            // macOS's own ODT writer breaks on lists inside table cells and leaves out images
            // (corpus: docx-images-in-tables), so Word and RTF files go through LibreOffice when it's installed.
            if format == .odt, let source, [.docx, .doc, .rtf].contains(source), OfficeEngine.libreOffice != nil,
               OfficeEngine.canConvert(source, to: .odt) {
                try await OfficeEngine.convert(url, to: .odt, output: output)
                return output
            }
            try await write(try await read(url), to: output, as: format, title: url.baseName)
            if format == .odt { try await checkODT(output) }
            return output
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }

    public static func write(_ text: NSAttributedString, to output: URL, as format: FileFormat, title: String) async throws {
        switch format {
        case .docx: try data(text, .officeOpenXML).write(to: output)
        case .doc: try data(text, .docFormat).write(to: output)
        case .rtf: try data(text, .rtf).write(to: output)
        case .odt: try data(text, .openDocument).write(to: output)
        case .html: try data(text, .html).write(to: output)
        case .rtfd:
            let wrapper = try text.fileWrapper(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
            try wrapper.write(to: output, options: .atomic, originalContentsURL: nil)
        case .txt:
            try text.string.write(to: output, atomically: true, encoding: .utf8)
        case .markdown:
            try MarkdownWriter.markdown(from: text).write(to: output, atomically: true, encoding: .utf8)
        case .epub:
            try await EPUB.write(title: title, bodyXHTML: XHTMLWriter.body(from: text), to: output)
        case .pdf:
            try await printPDF(text, to: output)
        case .pages:
            // Pages builds its own file from a Word document.
            let document = output.deletingLastPathComponent().appendingPathComponent(".\(title)-kumquat-\(UUID().uuidString.prefix(8)).docx")
            defer { try? FileManager.default.removeItem(at: document) }
            try data(text, .officeOpenXML).write(to: document)
            try await OfficeEngine.convert(document, to: .pages, output: output)
        default:
            throw OperationError.unsupported(format.displayName)
        }
    }

    static func convertPDF(_ url: URL, to format: FileFormat, output: URL, title: String) async throws {
        let pictures: Bool = [FileFormat.docx, .html, .epub, .pages].contains(format)
        let layout = try PDFLayout.read(url, pictures: pictures)
        guard layout.blocks.contains(where: { if case .pageBreak = $0.kind { false } else { true } }) else {
            throw OperationError.failed("The PDF has no text or pictures to convert.")
        }
        switch format {
        case .docx:
            try await LayoutDOCX.write(layout, to: output)
        case .html:
            try LayoutHTML.document(layout, title: title).write(to: output, atomically: true, encoding: .utf8)
        case .epub:
            let chapter = LayoutHTML.xhtml(layout)
            try await EPUB.write(title: title, bodyXHTML: chapter.body, css: chapter.css, resources: chapter.pictures, to: output)
        case .markdown:
            try LayoutText.markdown(layout).write(to: output, atomically: true, encoding: .utf8)
        case .txt:
            try LayoutText.text(layout).write(to: output, atomically: true, encoding: .utf8)
        case .rtf:
            try data(LayoutRichText.attributedString(layout), .rtf).write(to: output)
        case .pages:
            let document = output.deletingLastPathComponent().appendingPathComponent(".\(title)-kumquat-\(UUID().uuidString.prefix(8)).docx")
            defer { try? FileManager.default.removeItem(at: document) }
            try await LayoutDOCX.write(layout, to: document)
            try await OfficeEngine.convert(document, to: .pages, output: output)
        default:
            throw OperationError.unsupported(format.displayName)
        }
    }

    /// Fails when the ODT's text isn't well-formed XML, which no office app will open.
    static func checkODT(_ output: URL) async throws {
        let content = output.deletingLastPathComponent().appendingPathComponent(".kumquat-\(UUID().uuidString.prefix(8)).xml")
        defer { try? FileManager.default.removeItem(at: content) }
        try await Shell.run("/usr/bin/unzip", ["-p", output.path, "content.xml"], standardOutput: content)
        guard let parser = XMLParser(contentsOf: content), parser.parse() else {
            throw OperationError.failed("macOS couldn't write this document as ODT. With LibreOffice installed, Kumquat uses it instead.")
        }
    }

    /// A text clipping dragged out of an app: a property list with the text in several flavors.
    static func clipping(_ url: URL) throws -> NSAttributedString {
        let data = try Data(contentsOf: url)
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let flavors = plist["UTI-Data"] as? [String: Any]
        else { throw OperationError.unreadable(url.lastPathComponent) }
        if let rtf = flavors["public.rtf"] as? Data,
           let text = try? NSAttributedString(data: rtf, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            return text
        }
        for key in ["public.utf8-plain-text", "public.utf16-plain-text", "public.plain-text"] {
            if let string = flavors[key] as? String { return plain(string) }
            if let data = flavors[key] as? Data {
                let encoding: String.Encoding = key == "public.utf16-plain-text" ? .utf16 : .utf8
                if let string = String(data: data, encoding: encoding) { return plain(string) }
            }
        }
        throw OperationError.unreadable(url.lastPathComponent)
    }

    static func load(_ url: URL, _ type: NSAttributedString.DocumentType) throws -> NSAttributedString {
        do {
            return try NSAttributedString(url: url, options: [.documentType: type], documentAttributes: nil)
        } catch {
            throw OperationError.unreadable(url.lastPathComponent)
        }
    }

    static func data(_ text: NSAttributedString, _ type: NSAttributedString.DocumentType) throws -> Data {
        try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: type])
    }

    static func plain(_ string: String) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black,
        ])
    }

    /// HTML import uses WebKit, which must run on the main thread.
    static func attributed(html: String, baseURL: URL?) async throws -> NSAttributedString {
        try await MainActor.run {
            var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue,
            ]
            if let baseURL { options[.baseURL] = baseURL }
            guard let data = html.data(using: .utf8) else { throw OperationError.failed("Invalid text encoding.") }
            return try NSAttributedString(data: data, options: options, documentAttributes: nil)
        }
    }

    /// Lays the text out on A4 pages and saves them as a PDF.
    static func printPDF(_ text: NSAttributedString, to output: URL, landscape: Bool = false) async throws {
        try await MainActor.run {
            let printInfo = NSPrintInfo(dictionary: [.jobSavingURL: output])
            printInfo.jobDisposition = .save
            printInfo.paperSize = landscape ? NSSize(width: 842, height: 595) : NSSize(width: 595, height: 842)
            printInfo.orientation = landscape ? .landscape : .portrait
            let margin: CGFloat = 56
            printInfo.topMargin = margin
            printInfo.bottomMargin = margin
            printInfo.leftMargin = margin
            printInfo.rightMargin = margin
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
            printInfo.isHorizontallyCentered = false
            printInfo.isVerticallyCentered = false

            let width = printInfo.paperSize.width - 2 * margin
            let view = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
            view.appearance = NSAppearance(named: .aqua)
            view.drawsBackground = false
            view.textContainerInset = .zero
            view.textContainer?.lineFragmentPadding = 0
            view.isVerticallyResizable = true
            view.isHorizontallyResizable = false
            view.textStorage?.setAttributedString(text)
            if let container = view.textContainer, let layout = view.layoutManager {
                layout.ensureLayout(for: container)
                let height = layout.usedRect(for: container).height
                view.setFrameSize(NSSize(width: width, height: max(height, 1)))
            }

            let operation = NSPrintOperation(view: view, printInfo: printInfo)
            operation.showsPrintPanel = false
            operation.showsProgressPanel = false
            guard operation.run() else { throw OperationError.failed("Couldn't create the PDF.") }
        }
    }
}
