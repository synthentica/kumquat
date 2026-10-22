import Foundation

/// Minimal EPUB 3 reading and writing.
public enum EPUB {
    public struct Book {
        public var title: String
        /// The spine's chapters joined into one HTML document.
        public var html: String
        /// Folder the book was unpacked into; relative image paths resolve against it.
        public var baseURL: URL
        let workDirectory: URL

        public func cleanUp() {
            try? FileManager.default.removeItem(at: workDirectory)
        }
    }

    public static func read(_ url: URL) async throws -> Book {
        let work = try FileManager.default.makeTemporaryDirectory()
        do {
            try await Zip.extract(url, to: work)
            let container = try XMLDocument(contentsOf: work.appendingPathComponent("META-INF/container.xml"), options: [])
            guard let rootPath = container.firstElement(named: "rootfile")?.attributeValue("full-path") else {
                throw OperationError.unreadable(url.lastPathComponent)
            }
            let opfURL = work.appendingPathComponent(rootPath)
            let opf = try XMLDocument(contentsOf: opfURL, options: [])
            let base = opfURL.deletingLastPathComponent()

            var manifest: [String: String] = [:]
            for item in opf.elements(named: "item") {
                if let id = item.attributeValue("id"), let href = item.attributeValue("href") {
                    manifest[id] = href.removingPercentEncoding ?? href
                }
            }
            var bodies: [String] = []
            for reference in opf.elements(named: "itemref") {
                guard let id = reference.attributeValue("idref"), let href = manifest[id] else { continue }
                guard let chapter = try? String(contentsOf: base.appendingPathComponent(href), encoding: .utf8) else { continue }
                bodies.append(bodyContent(of: chapter))
            }
            let title = opf.firstElement(named: "title")?.stringValue ?? url.baseName
            let html = """
            <!DOCTYPE html><html><head><meta charset="utf-8"/><title>\(title.xmlEscaped)</title>
            <style>\(Markdown.stylesheet)</style></head><body>
            \(bodies.joined(separator: "\n"))
            </body></html>
            """
            return Book(title: title, html: html, baseURL: base, workDirectory: work)
        } catch {
            try? FileManager.default.removeItem(at: work)
            throw error
        }
    }

    static func bodyContent(of chapter: String) -> String {
        guard let open = chapter.range(of: "<body[^>]*>", options: [.regularExpression, .caseInsensitive]),
              let close = chapter.range(of: "</body>", options: [.caseInsensitive, .backwards]),
              open.upperBound <= close.lowerBound
        else { return chapter }
        return String(chapter[open.upperBound..<close.lowerBound])
    }

    /// Writes a single-chapter EPUB 3 from an XHTML body fragment.
    public static func write(title: String, bodyXHTML: String, language: String = "en", css: String? = nil,
                             resources: [(name: String, data: Data, mediaType: String)] = [], to output: URL) async throws {
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        let fm = FileManager.default
        try fm.createDirectory(at: work.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        try fm.createDirectory(at: work.appendingPathComponent("OEBPS"), withIntermediateDirectories: true)

        let identifier = "urn:uuid:\(UUID().uuidString.lowercased())"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let modified = formatter.string(from: Date())
        let safeTitle = title.xmlEscaped

        let manifestResources = resources.enumerated().map { index, resource in
            #"<item id="resource\#(index + 1)" href="\#(resource.name.xmlEscaped)" media-type="\#(resource.mediaType)"/>"#
        }.joined()
        for resource in resources {
            let file = work.appendingPathComponent("OEBPS").appendingPathComponent(resource.name)
            try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try resource.data.write(to: file)
        }
        let files: [String: String] = [
            "mimetype": "application/epub+zip",
            "META-INF/container.xml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
              <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
            </container>
            """,
            "OEBPS/content.opf": """
            <?xml version="1.0" encoding="UTF-8"?>
            <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
              <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="bookid">\(identifier)</dc:identifier>
                <dc:title>\(safeTitle)</dc:title>
                <dc:language>\(language.xmlEscaped)</dc:language>
                <meta property="dcterms:modified">\(modified)</meta>
              </metadata>
              <manifest>
                <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="style" href="style.css" media-type="text/css"/>
                <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>\(manifestResources)
              </manifest>
              <spine><itemref idref="chapter"/></spine>
            </package>
            """,
            "OEBPS/nav.xhtml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
            <head><title>\(safeTitle)</title></head>
            <body><nav epub:type="toc" id="toc"><ol><li><a href="chapter.xhtml">\(safeTitle)</a></li></ol></nav></body>
            </html>
            """,
            "OEBPS/style.css": css ?? Markdown.stylesheet,
            "OEBPS/chapter.xhtml": """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
            <head><meta charset="utf-8"/><title>\(safeTitle)</title><link rel="stylesheet" type="text/css" href="style.css"/></head>
            <body>
            \(bodyXHTML)
            </body>
            </html>
            """,
        ]
        for (path, contents) in files {
            try contents.write(to: work.appendingPathComponent(path), atomically: true, encoding: .utf8)
        }
        // The mimetype entry must come first and be stored uncompressed.
        try await Zip.create(output, from: work, entries: ["mimetype"], store: true)
        try await Zip.create(output, from: work, entries: ["META-INF", "OEBPS"])
    }
}
