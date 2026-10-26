import Foundation

/// RFC 4180 CSV / TSV reading and writing.
public enum CSV {
    public static func parse(_ text: String, delimiter: Unicode.Scalar = ",") -> [[String]] {
        var scalars = Array(text.unicodeScalars)
        if scalars.first == "\u{FEFF}" { scalars.removeFirst() }
        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if inQuotes {
                if scalar == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        field.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else if scalar == "\"" && field.isEmpty {
                inQuotes = true
            } else if scalar == delimiter {
                row.append(String(field))
                field = String.UnicodeScalarView()
            } else if scalar == "\n" || scalar == "\r" {
                row.append(String(field))
                field = String.UnicodeScalarView()
                rows.append(row)
                row = []
                if scalar == "\r", index + 1 < scalars.count, scalars[index + 1] == "\n" { index += 1 }
            } else {
                field.append(scalar)
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(String(field))
            rows.append(row)
        }
        return rows
    }

    public static func write(_ rows: [[String]], delimiter: Character = ",") -> String {
        rows.map { row in
            row.map { field in
                let needsQuotes = field.contains(delimiter) || field.contains("\"") || field.contains("\n") || field.contains("\r")
                return needsQuotes ? "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : field
            }.joined(separator: String(delimiter))
        }.joined(separator: "\n") + "\n"
    }
}

/// Reads and writes the first sheet of an .xlsx workbook, values only.
public enum XLSX {
    public static func write(_ rows: [[String]], to output: URL) async throws {
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        let fm = FileManager.default
        for folder in ["_rels", "xl/_rels", "xl/worksheets"] {
            try fm.createDirectory(at: work.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        let main = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let pkg = "http://schemas.openxmlformats.org/package/2006/relationships"
        let header = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#

        var sheet = header + #"<worksheet xmlns="\#(main)"><sheetData>"#
        for (rowIndex, row) in rows.enumerated() {
            sheet += #"<row r="\#(rowIndex + 1)">"#
            for (columnIndex, value) in row.enumerated() where !value.isEmpty {
                let reference = columnName(columnIndex) + String(rowIndex + 1)
                let style = rowIndex == 0 ? #" s="1""# : ""
                if rowIndex > 0, isNumber(value) {
                    sheet += #"<c r="\#(reference)"\#(style)><v>\#(value)</v></c>"#
                } else {
                    sheet += #"<c r="\#(reference)" t="inlineStr"\#(style)><is><t xml:space="preserve">\#(value.xmlEscaped)</t></is></c>"#
                }
            }
            sheet += "</row>"
        }
        sheet += "</sheetData></worksheet>"

        let files: [String: String] = [
            "[Content_Types].xml": header + """
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
            <Default Extension="xml" ContentType="application/xml"/>\
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>\
            <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\
            </Types>
            """,
            "_rels/.rels": header + """
            <Relationships xmlns="\(pkg)"><Relationship Id="rId1" Type="\(rel)/officeDocument" Target="xl/workbook.xml"/></Relationships>
            """,
            "xl/workbook.xml": header + """
            <workbook xmlns="\(main)" xmlns:r="\(rel)"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
            """,
            "xl/_rels/workbook.xml.rels": header + """
            <Relationships xmlns="\(pkg)">\
            <Relationship Id="rId1" Type="\(rel)/worksheet" Target="worksheets/sheet1.xml"/>\
            <Relationship Id="rId2" Type="\(rel)/styles" Target="styles.xml"/>\
            </Relationships>
            """,
            "xl/styles.xml": header + """
            <styleSheet xmlns="\(main)">\
            <fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>\
            <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>\
            <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>\
            <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>\
            <cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>\
            <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>\
            <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>\
            </styleSheet>
            """,
            "xl/worksheets/sheet1.xml": sheet,
        ]
        for (path, contents) in files {
            try contents.write(to: work.appendingPathComponent(path), atomically: true, encoding: .utf8)
        }
        try await Zip.create(output, from: work, entries: ["[Content_Types].xml", "_rels", "xl"])
    }

    public static func read(_ url: URL) async throws -> [[String]] {
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        try await Zip.extract(url, to: work)
        let xl = work.appendingPathComponent("xl")

        var shared: [String] = []
        if let strings = try? XMLDocument(contentsOf: xl.appendingPathComponent("sharedStrings.xml"), options: []) {
            shared = strings.elements(named: "si").map { item in
                item.elements(named: "t").compactMap(\.stringValue).joined()
            }
        }

        let dates = DateStyles(xl: xl)
        let sheetURL = firstSheet(in: xl) ?? xl.appendingPathComponent("worksheets/sheet1.xml")
        let sheet = try XMLDocument(contentsOf: sheetURL, options: [])
        var rows: [[String]] = []
        for (fallbackIndex, row) in sheet.elements(named: "row").enumerated() {
            let rowNumber = row.attributeValue("r").flatMap { Int($0) } ?? fallbackIndex + 1
            while rows.count < rowNumber - 1 { rows.append([]) }
            var values: [String] = []
            for cell in row.children(named: "c") {
                let column = cell.attributeValue("r").map(columnIndex) ?? values.count
                let raw = cell.firstElement(named: "v")?.stringValue ?? ""
                let value: String
                switch cell.attributeValue("t") {
                case "s": value = Int(raw).flatMap { shared.indices.contains($0) ? shared[$0] : nil } ?? ""
                case "inlineStr": value = cell.elements(named: "t").compactMap(\.stringValue).joined()
                case "b": value = raw == "1" ? "TRUE" : "FALSE"
                case nil, "n": value = dates.text(for: raw, style: cell.attributeValue("s")) ?? raw
                default: value = raw
                }
                while values.count < column { values.append("") }
                if values.count == column { values.append(value) } else { values[column] = value }
            }
            rows.append(values)
        }
        let width = rows.map(\.count).max() ?? 0
        return rows.map { $0 + Array(repeating: "", count: width - $0.count) }
    }

    /// The cell styles that show a number as a date or a time. Excel keeps dates as day counts, so without these
    /// a birthday came out as "45123" in the CSV.
    struct DateStyles {
        enum Kind: Equatable { case date, time, dateTime }

        /// By cell style, the `s` attribute: nil where the style shows a plain number.
        var kinds: [Kind?] = []
        var uses1904 = false

        init(kinds: [Kind?], uses1904: Bool = false) {
            self.kinds = kinds
            self.uses1904 = uses1904
        }

        init(xl: URL) {
            if let workbook = try? XMLDocument(contentsOf: xl.appendingPathComponent("workbook.xml"), options: []),
               let flag = workbook.firstElement(named: "workbookPr")?.attributeValue("date1904") {
                uses1904 = flag == "1" || flag == "true"
            }
            guard let styles = try? XMLDocument(contentsOf: xl.appendingPathComponent("styles.xml"), options: []) else { return }
            var custom: [Int: String] = [:]
            for format in styles.elements(named: "numFmt") {
                if let id = format.attributeValue("numFmtId").flatMap({ Int($0) }), let code = format.attributeValue("formatCode") {
                    custom[id] = code
                }
            }
            let formats = styles.firstElement(named: "cellXfs")?.children(named: "xf") ?? []
            kinds = formats.map { format -> Kind? in
                guard let id = format.attributeValue("numFmtId").flatMap({ Int($0) }) else { return nil }
                if let code = custom[id] { return Self.kind(of: code) }
                return Self.builtIn[id]
            }
        }

        /// Excel's own number formats that show dates and times. 46, "[h]:mm:ss", counts hours past a day and stays a number.
        static let builtIn: [Int: Kind] = [
            14: .date, 15: .date, 16: .date, 17: .date,
            18: .time, 19: .time, 20: .time, 21: .time, 45: .time, 47: .time,
            22: .dateTime,
        ]

        /// What a custom format code like "dd.mm.yyyy" or "h:mm AM/PM" shows.
        static func kind(of code: String) -> Kind? {
            var code = code.lowercased()
            // Elapsed time, like "[h]:mm", is a duration rather than a time of day.
            if code.range(of: #"\[(h+|m+|s+)\]"#, options: .regularExpression) != nil { return nil }
            // Quoted text, escaped characters, padding ("_)" and "* "), and [colors] or [conditions] aren't part of the date.
            for pattern in [#""[^"]*""#, #"\\."#, #"_."#, #"\*."#, #"\[[^\]]*\]"#] {
                code = code.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            }
            // Only the first section counts: "0;-0" style formats keep numbers in the others.
            code = String(code.prefix { $0 != ";" })
            let date = code.contains("y") || code.contains("d")
            let time = code.contains("h") || code.contains("s")
            switch (date, time) {
            case (true, true): return .dateTime
            case (true, false): return .date
            case (false, true): return .time
            // A month on its own, like "mmmm".
            case (false, false): return code.contains("m") ? .date : nil
            }
        }

        /// The cell's value as an ISO 8601 date or time, when its style shows one.
        func text(for raw: String, style: String?) -> String? {
            guard let style, let index = Int(style), kinds.indices.contains(index), let kind = kinds[index],
                  let serial = Double(raw), serial.isFinite, serial >= 0, serial < 2_958_466
            else { return nil }
            // Day zero is 30 December 1899, or 1 January 1904. Before March 1900 Excel counts a 29 February that
            // never was, so those days are one off.
            let days = uses1904 || serial >= 60 ? serial : serial + 1
            let epoch: TimeInterval = uses1904 ? -2_082_844_800 : -2_209_161_600
            let date = Date(timeIntervalSince1970: epoch + (days * 86_400).rounded())
            let formatter = Self.formatters[kind]
            return formatter?.string(from: date)
        }

        private static let formatters: [Kind: DateFormatter] = {
            func make(_ format: String) -> DateFormatter {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.timeZone = TimeZone(identifier: "UTC")
                formatter.dateFormat = format
                return formatter
            }
            return [.date: make("yyyy-MM-dd"), .time: make("HH:mm:ss"), .dateTime: make("yyyy-MM-dd HH:mm:ss")]
        }()
    }

    private static func firstSheet(in xl: URL) -> URL? {
        guard let workbook = try? XMLDocument(contentsOf: xl.appendingPathComponent("workbook.xml"), options: []),
              let id = workbook.firstElement(named: "sheet")?.attributeValue("id"),
              let rels = try? XMLDocument(contentsOf: xl.appendingPathComponent("_rels/workbook.xml.rels"), options: []),
              let target = rels.elements(named: "Relationship").first(where: { $0.attributeValue("Id") == id })?.attributeValue("Target")
        else { return nil }
        if target.hasPrefix("/") {
            return xl.deletingLastPathComponent().appendingPathComponent(String(target.dropFirst()))
        }
        return xl.appendingPathComponent(target)
    }

    static func columnName(_ index: Int) -> String {
        var index = index + 1
        var name = ""
        while index > 0 {
            let remainder = (index - 1) % 26
            name = String(UnicodeScalar(UInt8(65 + remainder))) + name
            index = (index - 1) / 26
        }
        return name
    }

    static func columnIndex(_ reference: String) -> Int {
        var index = 0
        for scalar in reference.unicodeScalars {
            guard scalar.value >= 65 && scalar.value <= 90 else { break }
            index = index * 26 + Int(scalar.value - 64)
        }
        return max(0, index - 1)
    }

    /// Plain decimal numbers only, so ZIP codes like "00501" stay text.
    static func isNumber(_ value: String) -> Bool {
        guard Double(value) != nil, !value.hasPrefix("+") else { return false }
        let digits = value.hasPrefix("-") ? String(value.dropFirst()) : value
        if digits.count > 1, digits.hasPrefix("0"), !digits.hasPrefix("0.") { return false }
        return digits.allSatisfy { $0.isNumber || $0 == "." } && digits.count <= 15
    }
}

/// Converts between table formats.
public enum Spreadsheet {
    public static func read(_ url: URL) async throws -> [[String]] {
        switch FileFormat.detect(url) {
        case .xlsx:
            return try await XLSX.read(url)
        case .tsv:
            return CSV.parse(try readText(url), delimiter: "\t")
        case .csv:
            let text = try readText(url)
            return CSV.parse(text, delimiter: guessDelimiter(text))
        case .ods:
            return try await ODS.read(url)
        case .xls:
            return try XLS.read(url)
        case .numbers:
            return try await OfficeEngine.withIntermediate(url, as: .xlsx) { try await XLSX.read($0) }
        case .pdf:
            return try PDFEngine.tableRows(url)
        default:
            throw OperationError.unsupported("This spreadsheet")
        }
    }

    public static func convert(_ url: URL, to format: FileFormat, context: OperationContext) async throws -> URL {
        let rows = try await read(url)
        let output = context.destination(for: url, extension: format.primaryExtension)
        do {
            switch format {
            case .xlsx: try await XLSX.write(rows, to: output)
            case .ods: try await ODS.write(rows, to: output)
            case .numbers:
                let workbook = output.deletingLastPathComponent().appendingPathComponent(".\(url.baseName)-kumquat-\(UUID().uuidString.prefix(8)).xlsx")
                defer { try? FileManager.default.removeItem(at: workbook) }
                try await XLSX.write(rows, to: workbook)
                try await OfficeEngine.convert(workbook, to: .numbers, output: output)
            case .csv: try CSV.write(rows).write(to: output, atomically: true, encoding: .utf8)
            case .tsv: try CSV.write(rows, delimiter: "\t").write(to: output, atomically: true, encoding: .utf8)
            case .json: try json(rows).write(to: output, atomically: true, encoding: .utf8)
            case .markdown: try markdownTable(rows).write(to: output, atomically: true, encoding: .utf8)
            case .html: try htmlDocument(rows, title: url.baseName).write(to: output, atomically: true, encoding: .utf8)
            case .pdf: try TablePDF.write(rows, to: output)
            default: throw OperationError.unsupported(format.displayName)
            }
        } catch {
            // A zip stopped halfway left an .xlsx or .ods that no app opens.
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        return output
    }

    static func guessDelimiter(_ text: String) -> Unicode.Scalar {
        let firstLine = text.prefix { $0 != "\n" && $0 != "\r" }
        let candidates: [Unicode.Scalar] = [",", ";", "\t"]
        let counts: [(Unicode.Scalar, Int)] = candidates.map { delimiter in
            (delimiter, firstLine.unicodeScalars.filter { $0 == delimiter }.count)
        }
        return counts.max { $0.1 < $1.1 }.flatMap { $0.1 > 0 ? $0.0 : nil } ?? ","
    }

    static func json(_ rows: [[String]]) -> String {
        guard let header = rows.first else { return "[]\n" }
        // Every column gets its own key: a row longer than the header used to lose its extra cells, and two
        // columns with the same title made duplicate keys, of which a JSON reader keeps only the last.
        let width = rows.map(\.count).max() ?? 0
        var used = Set<String>()
        let keys = (0..<width).map { index -> String in
            let title = index < header.count ? header[index] : ""
            let base = title.isEmpty ? "column\(index + 1)" : title
            var key = base
            var number = 2
            while !used.insert(key).inserted {
                key = "\(base) \(number)"
                number += 1
            }
            return key
        }
        let objects = rows.dropFirst().map { row -> String in
            let pairs = keys.enumerated().map { index, key -> String in
                let value = index < row.count ? row[index] : ""
                let encoded = isJSONNumber(value) ? value : jsonString(value)
                return "    \(jsonString(key)): \(encoded)"
            }
            return "  {\n" + pairs.joined(separator: ",\n") + "\n  }"
        }
        return "[\n" + objects.joined(separator: ",\n") + "\n]\n"
    }

    /// A number JSON accepts as is. Spreadsheets allow ".5" and "5.", which JSON doesn't, so those stay strings
    /// rather than making the whole file unreadable.
    static func isJSONNumber(_ value: String) -> Bool {
        XLSX.isNumber(value) && value.range(of: #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?$"#, options: .regularExpression) != nil
    }

    static func jsonString(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case _ where scalar.value < 0x20: result += String(format: "\\u%04x", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    static func markdownTable(_ rows: [[String]]) -> String {
        guard let header = rows.first else { return "" }
        // As wide as the widest row, since Markdown drops cells past the header's.
        let width = rows.map(\.count).max() ?? 0
        func line(_ cells: [String]) -> String {
            let padded = cells + Array(repeating: "", count: max(0, width - cells.count))
            return "| " + padded.map {
                $0.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
            }.joined(separator: " | ") + " |"
        }
        var lines = [line(header), "|" + String(repeating: " --- |", count: width)]
        lines += rows.dropFirst().map(line)
        return lines.joined(separator: "\n") + "\n"
    }

    static func htmlDocument(_ rows: [[String]], title: String) -> String {
        var html = """
        <!DOCTYPE html><html><head><meta charset="utf-8"/><title>\(title.xmlEscaped)</title>
        <style>
        body { font-family: -apple-system, 'Helvetica Neue', Helvetica, sans-serif; font-size: 10pt; }
        table { border-collapse: collapse; width: 100%; }
        th { background: #f2f2f4; text-align: left; }
        td, th { border: 1px solid #d0d0d6; padding: 3pt 6pt; }
        </style></head><body><table>
        """
        for (index, row) in rows.enumerated() {
            let tag = index == 0 ? "th" : "td"
            html += "\n<tr>" + row.map { "<\(tag)>\($0.xmlEscaped)</\(tag)>" }.joined() + "</tr>"
        }
        return html + "\n</table></body></html>\n"
    }
}

func readText(_ url: URL) throws -> String {
    if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
    var encoding = String.Encoding.utf8
    if let text = try? String(contentsOf: url, usedEncoding: &encoding) { return text }
    if let text = try? String(contentsOf: url, encoding: .windowsCP1252) { return text }
    throw OperationError.unreadable(url.lastPathComponent)
}
