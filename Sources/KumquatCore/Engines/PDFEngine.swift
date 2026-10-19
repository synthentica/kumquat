import AppKit
import Foundation
import PDFKit
import Vision

/// PDF rendering, text extraction and page tools through PDFKit.
public enum PDFEngine {
    static func open(_ url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else { throw OperationError.unreadable(url.lastPathComponent) }
        if document.isLocked { throw OperationError.failed("\(url.lastPathComponent) is password protected.") }
        if isDynamicForm(document) {
            throw OperationError.failed("\(url.lastPathComponent) is an XFA form, which only Adobe Acrobat and Reader can show.")
        }
        return document
    }

    /// A dynamic XFA form keeps its pages as XML that only Adobe's apps lay out. Everywhere else, PDFKit included,
    /// it shows a "Please wait..." page, and converting that would quietly give the wrong result
    /// (corpus: pdf-xfa-dynamic-form).
    static func isDynamicForm(_ document: PDFDocument) -> Bool {
        guard let catalog = document.documentRef?.catalog else { return false }
        var form: CGPDFDictionaryRef?
        var xfa: CGPDFObjectRef?
        guard CGPDFDictionaryGetDictionary(catalog, "AcroForm", &form), let form,
              CGPDFDictionaryGetObject(form, "XFA", &xfa)
        else { return false }
        var needsRendering: CGPDFBoolean = 0
        if CGPDFDictionaryGetBoolean(catalog, "NeedsRendering", &needsRendering), needsRendering != 0 { return true }
        // A static XFA form also carries ordinary fields and pages, and those convert fine.
        var fields: CGPDFArrayRef?
        if !CGPDFDictionaryGetArray(form, "Fields", &fields) || fields.map(CGPDFArrayGetCount) == 0 { return true }
        let first = document.page(at: 0)?.string ?? ""
        return first.contains("Please wait") && first.contains("may not be able to display")
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
        let count = document.pageCount
        let digits = String(count).count
        // Pages render side by side, each worker with its own copy of the document so PDFKit is never shared
        // across threads. Up to four workers, one core left free: each page at 300 DPI takes tens of megabytes.
        let workers = min(count, max(2, min(4, ProcessInfo.processInfo.activeProcessorCount - 1)))
        let state = PageState()
        // Read here: the worker threads aren't part of this task, so they can't see its task-locals.
        let progress = WorkProgress.sink
        // The task is borrowed only while the workers run, to see whether someone pressed stop.
        withUnsafeCurrentTask { task in
            DispatchQueue.concurrentPerform(iterations: workers) { worker in
                let copy: PDFDocument
                if worker == 0 {
                    copy = document
                } else if let opened = try? open(url) {
                    copy = opened
                } else {
                    state.fail(OperationError.unreadable(url.lastPathComponent))
                    return
                }
                for index in stride(from: worker, to: count, by: workers) where !state.failed {
                    if task?.isCancelled == true {
                        state.fail(CancellationError())
                        break
                    }
                    autoreleasepool {
                        guard let page = copy.page(at: index) else { return }
                        let number = String(index + 1).leftPadded(to: digits)
                        let output = folder.appendingPathComponent("\(named.baseName) \(number).\(format.primaryExtension)")
                        do {
                            try ImageEngine.write(try render(page, dpi: dpi), to: output, format: format, quality: context.imageQuality)
                            state.finishPage { done in progress?(Double(done) / Double(count)) }
                        } catch {
                            state.fail(error)
                        }
                    }
                }
            }
        }
        if let error = state.error {
            try? FileManager.default.removeItem(at: folder)
            throw error
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
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            var pageText = page.attributedString
            // A scanned page has no text layer, only a picture of the text (corpus: both scanned PDFs came out empty).
            if (pageText?.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let recognized = recognizeText(on: page)
                pageText = recognized.isEmpty ? nil : NSAttributedString(string: recognized)
            }
            WorkProgress.report(index + 1, of: document.pageCount)
            guard let pageText else { continue }
            if text.length > 0 { text.append(NSAttributedString(string: "\n\n")) }
            text.append(pageText)
        }
        return text
    }

    /// The text in a picture of a page, read with the Mac's own text recognition. A page scanned sideways or upside
    /// down is first skimmed in every direction with the quick recognizer, and only the direction it reads best
    /// gets the slow, accurate pass.
    static func recognizeText(on page: PDFPage) -> String {
        guard let image = try? render(page, dpi: 200) else { return "" }
        func read(_ orientation: CGImagePropertyOrientation, accurate: Bool) -> (text: String, score: Float) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = accurate ? .accurate : .fast
            request.usesLanguageCorrection = accurate
            if accurate { request.automaticallyDetectsLanguage = true }
            // Vision can fail a request when the Neural Engine is busy, so a failed read gets a second try.
            if (try? VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])) == nil {
                try? VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
            }
            // Top to bottom, then left to right; Vision measures from the bottom left.
            let lines = (request.results ?? [])
                .sorted { abs($0.boundingBox.midY - $1.boundingBox.midY) > 0.01 ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.minX < $1.boundingBox.minX }
                .compactMap { $0.topCandidates(1).first }
            let score = lines.reduce(Float(0)) { $0 + $1.confidence * Float($1.string.count) }
            return (lines.map(\.string).joined(separator: "\n"), score)
        }
        var direction = CGImagePropertyOrientation.up
        let upright = read(.up, accurate: false)
        let characters = Float(upright.text.count)
        if characters < 40 || upright.score < characters * 0.6 {
            var best = upright.score
            for orientation in [CGImagePropertyOrientation.right, .left, .down] {
                let score = read(orientation, accurate: false).score
                if score > best { best = score; direction = orientation }
            }
        }
        let result = read(direction, accurate: true)
        guard result.text.isEmpty else { return result.text }
        // The skim found nothing it could trust: read the other directions accurately and keep the best.
        var best = result
        for orientation in [CGImagePropertyOrientation.up, .right, .left, .down] where orientation != direction {
            let other = read(orientation, accurate: true)
            if other.score > best.score { best = other }
        }
        return best.text
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

/// Shared bookkeeping for pages rendered in parallel.
private final class PageState: @unchecked Sendable {
    private let lock = NSLock()
    private var done = 0
    private(set) var error: Error?

    var failed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return error != nil
    }

    /// Counts a page and reports the new total while still locked, so reports arrive in order.
    func finishPage(_ report: (Int) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        done += 1
        report(done)
    }

    func fail(_ error: Error) {
        lock.lock()
        if self.error == nil { self.error = error }
        lock.unlock()
    }
}
