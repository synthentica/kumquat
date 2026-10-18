import Foundation

/// Reads and writes the first sheet of an OpenDocument spreadsheet (.ods), values only.
public enum ODS {
    static let mimeType = "application/vnd.oasis.opendocument.spreadsheet"

    public static func write(_ rows: [[String]], to output: URL) async throws {
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        try FileManager.default.createDirectory(at: work.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        let header = #"<?xml version="1.0" encoding="UTF-8"?>"#
        let width = rows.map(\.count).max() ?? 0

        var table = #"<table:table table:name="Sheet1"><table:table-column table:number-columns-repeated="\#(max(width, 1))"/>"#
        for (index, row) in rows.enumerated() {
            table += "<table:table-row>"
            for value in row {
                if value.isEmpty {
                    table += "<table:table-cell/>"
                } else if index > 0, XLSX.isNumber(value) {
                    table += #"<table:table-cell office:value-type="float" office:value="\#(value)"><text:p>\#(value)</text:p></table:table-cell>"#
                } else {
                    let paragraphs = value.components(separatedBy: "\n").map { "<text:p>\($0.xmlEscaped)</text:p>" }.joined()
                    table += #"<table:table-cell office:value-type="string">\#(paragraphs)</table:table-cell>"#
                }
            }
            table += "</table:table-row>"
        }
        table += "</table:table>"

        let files: [String: String] = [
            "mimetype": mimeType,
            "META-INF/manifest.xml": header + """
            <manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">\
            <manifest:file-entry manifest:full-path="/" manifest:version="1.2" manifest:media-type="\(mimeType)"/>\
            <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>\
            </manifest:manifest>
            """,
            "content.xml": header + """
            <office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" \
            xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" \
            xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.2">\
            <office:body><office:spreadsheet>\(table)</office:spreadsheet></office:body></office:document-content>
            """,
        ]
        for (path, contents) in files {
            try contents.write(to: work.appendingPathComponent(path), atomically: true, encoding: .utf8)
        }
        // Like EPUB, the mimetype entry comes first and uncompressed.
        try await Zip.create(output, from: work, entries: ["mimetype"], store: true)
        try await Zip.create(output, from: work, entries: ["META-INF", "content.xml"])
    }

    public static func read(_ url: URL) async throws -> [[String]] {
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        try await Zip.extract(url, to: work)
        let content = try XMLDocument(contentsOf: work.appendingPathComponent("content.xml"), options: [])
        guard let table = content.firstElement(named: "table") else { return [] }

        var rows: [[String]] = []
        for row in table.elements(named: "table-row") {
            var values: [String] = []
            for cell in (row.children ?? []).compactMap({ $0 as? XMLElement })
            where cell.localName == "table-cell" || cell.localName == "covered-table-cell" {
                let text = cell.children(named: "p").map { $0.stringValue ?? "" }.joined(separator: "\n")
                // Empty cells are often "repeated" thousands of times to the sheet's edge; trailing ones are dropped below.
                let repeats = min(Int(cell.attributeValue("number-columns-repeated") ?? "") ?? 1, text.isEmpty ? 256 : 1024)
                values += Array(repeating: text, count: max(repeats, 1))
            }
            while values.last?.isEmpty == true { values.removeLast() }
            let repeats = min(Int(row.attributeValue("number-rows-repeated") ?? "") ?? 1, values.isEmpty ? 64 : 4096)
            rows += Array(repeating: values, count: max(repeats, 1))
        }
        while rows.last?.isEmpty == true { rows.removeLast() }
        let width = rows.map(\.count).max() ?? 0
        return rows.map { $0 + Array(repeating: "", count: width - $0.count) }
    }
}
