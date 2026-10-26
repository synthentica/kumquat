import Foundation

/// Reads the first sheet of an Excel 97–2003 workbook (.xls), values only.
///
/// An .xls file is a Compound File (a small FAT file system) holding a "Workbook" stream of BIFF8 records.
public enum XLS {
    public static func read(_ url: URL) throws -> [[String]] {
        let file = try CompoundFile(data: Data(contentsOf: url))
        guard let workbook = file.stream(named: "Workbook") ?? file.stream(named: "Book") else {
            throw OperationError.unreadable(url.lastPathComponent)
        }
        return try sheet(from: workbook)
    }

    // MARK: BIFF8

    struct Record {
        var type: UInt16
        var data: Data
    }

    static func records(in stream: Data, from start: Int = 0) -> [Record] {
        var result: [Record] = []
        var offset = start
        while offset + 4 <= stream.count {
            let type = stream.uint16(at: offset)
            let length = Int(stream.uint16(at: offset + 2))
            let end = min(offset + 4 + length, stream.count)
            result.append(Record(type: type, data: stream.subdata(in: offset + 4..<end)))
            offset = end
        }
        return result
    }

    static func sheet(from stream: Data) throws -> [[String]] {
        let globals = records(in: stream)
        var sheetOffset: Int?
        var strings: [String] = []
        var index = 0
        while index < globals.count {
            let record = globals[index]
            switch record.type {
            case 0x0085 where sheetOffset == nil && record.data.count >= 6 && record.data[record.data.startIndex + 5] == 0:
                sheetOffset = Int(record.data.uint32(at: 0))
            case 0x00FC:
                // The shared string table continues in CONTINUE records that follow it.
                var segments = [record.data]
                while index + 1 < globals.count, globals[index + 1].type == 0x003C {
                    index += 1
                    segments.append(globals[index].data)
                }
                strings = sharedStrings(segments)
            case 0x000A:
                index = globals.count
                continue
            default:
                break
            }
            index += 1
        }
        guard let sheetOffset else { throw OperationError.failed("The workbook has no worksheet.") }

        var cells: [Int: [Int: String]] = [:]
        func set(_ row: Int, _ column: Int, _ value: String) {
            cells[row, default: [:]][column] = value
        }
        var pendingFormula: (row: Int, column: Int)?
        for record in records(in: stream, from: sheetOffset).dropFirst() {
            let data = record.data
            switch record.type {
            case 0x000A:
                break
            case 0x00FD where data.count >= 10: // LABELSST
                let string = Int(data.uint32(at: 6))
                set(Int(data.uint16(at: 0)), Int(data.uint16(at: 2)), strings.indices.contains(string) ? strings[string] : "")
            case 0x0203 where data.count >= 14: // NUMBER
                set(Int(data.uint16(at: 0)), Int(data.uint16(at: 2)), format(data.double(at: 6)))
            case 0x027E where data.count >= 10: // RK
                set(Int(data.uint16(at: 0)), Int(data.uint16(at: 2)), format(rk(data.uint32(at: 6))))
            case 0x00BD where data.count >= 6: // MULRK
                let row = Int(data.uint16(at: 0))
                var column = Int(data.uint16(at: 2))
                var offset = 4
                while offset + 6 <= data.count - 2 {
                    set(row, column, format(rk(data.uint32(at: offset + 2))))
                    offset += 6
                    column += 1
                }
            case 0x0204 where data.count >= 8: // LABEL
                var reader = StringReader(segments: [data.subdata(in: data.startIndex + 6..<data.endIndex)])
                set(Int(data.uint16(at: 0)), Int(data.uint16(at: 2)), reader.readString(lengthBytes: 2))
            case 0x0205 where data.count >= 8: // BOOLERR
                let value = data[data.startIndex + 6]
                let isError = data[data.startIndex + 7] != 0
                set(Int(data.uint16(at: 0)), Int(data.uint16(at: 2)), isError ? "#ERROR" : (value != 0 ? "TRUE" : "FALSE"))
            case 0x0006 where data.count >= 14: // FORMULA: keep the cached result
                let row = Int(data.uint16(at: 0))
                let column = Int(data.uint16(at: 2))
                if data.uint16(at: 12) == 0xFFFF {
                    switch data[data.startIndex + 6] {
                    case 0: pendingFormula = (row, column) // the text follows in a STRING record
                    case 1: set(row, column, data[data.startIndex + 8] != 0 ? "TRUE" : "FALSE")
                    case 2: set(row, column, "#ERROR")
                    default: break
                    }
                } else {
                    set(row, column, format(data.double(at: 6)))
                }
            case 0x0207: // STRING
                if let cell = pendingFormula {
                    var reader = StringReader(segments: [data])
                    set(cell.row, cell.column, reader.readString(lengthBytes: 2))
                    pendingFormula = nil
                }
            default:
                continue
            }
            if record.type == 0x000A { break }
        }

        guard let lastRow = cells.keys.max() else { return [] }
        let width = (cells.values.compactMap { $0.keys.max() }.max() ?? 0) + 1
        return (0...lastRow).map { row in
            (0..<width).map { cells[row]?[$0] ?? "" }
        }
    }

    static func sharedStrings(_ segments: [Data]) -> [String] {
        guard let first = segments.first, first.count >= 8 else { return [] }
        let count = Int(first.uint32(at: 4))
        var reader = StringReader(segments: [first.subdata(in: first.startIndex + 8..<first.endIndex)] + segments.dropFirst())
        var strings: [String] = []
        strings.reserveCapacity(min(count, 1_000_000))
        while strings.count < count, !reader.isAtEnd {
            strings.append(reader.readString(lengthBytes: 2))
        }
        return strings
    }

    /// RK values pack an integer or the top 30 bits of a double, optionally divided by 100.
    static func rk(_ raw: UInt32) -> Double {
        var value: Double
        if raw & 0x02 != 0 {
            value = Double(Int32(bitPattern: raw) >> 2)
        } else {
            value = Double(bitPattern: UInt64(raw & 0xFFFF_FFFC) << 32)
        }
        if raw & 0x01 != 0 { value /= 100 }
        return value
    }

    static func format(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1e15 { return String(Int64(value)) }
        return String(value)
    }

    /// Reads BIFF8 Unicode strings, which may continue across record boundaries.
    struct StringReader {
        var segments: [Data]
        var segment = 0
        var offset = 0

        var isAtEnd: Bool {
            var index = segment
            var position = offset
            while index < segments.count {
                if position < segments[index].count { return false }
                index += 1
                position = 0
            }
            return true
        }

        private mutating func normalize() {
            while segment < segments.count, offset >= segments[segment].count {
                segment += 1
                offset = 0
            }
        }

        mutating func byte() -> UInt8 {
            normalize()
            guard segment < segments.count else { return 0 }
            let data = segments[segment]
            defer { offset += 1 }
            return data[data.startIndex + offset]
        }

        mutating func uint16() -> UInt16 { UInt16(byte()) | UInt16(byte()) << 8 }

        mutating func uint32() -> UInt32 { UInt32(uint16()) | UInt32(uint16()) << 16 }

        /// Moves past `count` bytes, stopping at the end: a damaged length of four billion would otherwise
        /// spin through that many empty reads.
        mutating func skip(_ count: Int) {
            var remaining = count
            while remaining > 0 {
                normalize()
                guard segment < segments.count else { return }
                let step = min(remaining, segments[segment].count - offset)
                offset += step
                remaining -= step
            }
        }

        mutating func readString(lengthBytes: Int) -> String {
            let length = lengthBytes == 2 ? Int(uint16()) : Int(byte())
            let flags = byte()
            var wide = flags & 0x01 != 0
            let runs = flags & 0x08 != 0 ? Int(uint16()) : 0
            let extended = flags & 0x04 != 0 ? Int(uint32()) : 0
            var units: [UInt16] = []
            units.reserveCapacity(length)
            while units.count < length {
                normalize()
                guard segment < segments.count else { break }
                if offset == 0, !units.isEmpty {
                    // A string split across records starts the next one with a fresh flags byte.
                    wide = byte() & 0x01 != 0
                }
                units.append(wide ? uint16() : UInt16(byte()))
            }
            skip(runs * 4 + extended)
            return String(decoding: units, as: UTF16.self)
        }
    }
}

/// A minimal reader for Microsoft's Compound File Binary format.
struct CompoundFile {
    let data: Data
    let sectorSize: Int
    let miniSectorSize: Int
    let miniCutoff: Int
    let fat: [UInt32]
    let miniFAT: [UInt32]
    let entries: [(name: String, start: UInt32, size: Int)]
    let miniStream: Data

    static let endOfChain: UInt32 = 0xFFFF_FFFE

    init(data: Data) throws {
        self.data = data
        guard data.count >= 512, data.prefix(8) == Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) else {
            throw OperationError.failed("This isn't an Excel 97–2003 file.")
        }
        // Sectors are 512 or 4,096 bytes and mini sectors 64. A damaged header with a tiny sector size made the
        // DIFAT loop below build a negative range, which crashed the whole app.
        let sectorShift = Int(data.uint16(at: 0x1E))
        let miniShift = Int(data.uint16(at: 0x20))
        guard (7...16).contains(sectorShift), (2...sectorShift).contains(miniShift) else {
            throw OperationError.failed("This Excel 97–2003 file is damaged.")
        }
        // Locals rather than properties, so the helpers below can use them before `self` is complete.
        let sectorSize = 1 << sectorShift
        self.sectorSize = sectorSize
        miniSectorSize = 1 << miniShift
        miniCutoff = Int(data.uint32(at: 0x38))

        // The sectors that hold the FAT are listed in the header, then in a chain of DIFAT sectors.
        var fatSectors: [UInt32] = (0..<109).map { data.uint32(at: 0x4C + $0 * 4) }.filter { $0 < 0xFFFF_FFFA }
        var difat = data.uint32(at: 0x44)
        var guardCount = 0
        let perSector = sectorSize / 4
        while difat < 0xFFFF_FFFA, guardCount < 10_000 {
            let base = 512 + Int(difat) * sectorSize
            guard base + sectorSize <= data.count else { break }
            for index in 0..<(perSector - 1) {
                let sector = data.uint32(at: base + index * 4)
                if sector < 0xFFFF_FFFA { fatSectors.append(sector) }
            }
            difat = data.uint32(at: base + (perSector - 1) * 4)
            guardCount += 1
        }
        var fat: [UInt32] = []
        for sector in fatSectors {
            let base = 512 + Int(sector) * sectorSize
            guard base + sectorSize <= data.count else { continue }
            for index in 0..<perSector { fat.append(data.uint32(at: base + index * 4)) }
        }
        self.fat = fat

        let table = fat
        func chain(_ start: UInt32) -> [Int] {
            var sectors: [Int] = []
            var current = start
            while current < 0xFFFF_FFFA, Int(current) < table.count, sectors.count < table.count {
                sectors.append(Int(current))
                current = table[Int(current)]
            }
            return sectors
        }
        func read(_ start: UInt32) -> Data {
            var result = Data()
            for sector in chain(start) {
                let base = 512 + sector * sectorSize
                guard base < data.count else { break }
                result.append(data.subdata(in: base..<min(base + sectorSize, data.count)))
            }
            return result
        }

        let directory = read(data.uint32(at: 0x30))
        var entries: [(name: String, start: UInt32, size: Int)] = []
        var offset = 0
        while offset + 128 <= directory.count {
            let nameLength = max(0, Int(directory.uint16(at: offset + 0x40)) - 2)
            let nameData = directory.subdata(in: directory.startIndex + offset..<directory.startIndex + offset + min(nameLength, 64))
            let units = stride(from: 0, to: nameData.count - 1, by: 2).map { nameData.uint16(at: $0) }
            entries.append((String(decoding: units, as: UTF16.self), directory.uint32(at: offset + 0x74), Int(directory.uint32(at: offset + 0x78))))
            offset += 128
        }
        self.entries = entries

        let miniFATData = read(data.uint32(at: 0x3C))
        miniFAT = stride(from: 0, to: miniFATData.count - 3, by: 4).map { miniFATData.uint32(at: $0) }
        // The root entry's stream holds every small stream.
        let root = entries.first
        miniStream = root.map { $0.start < 0xFFFF_FFFA ? read($0.start) : Data() } ?? Data()
    }

    func stream(named name: String) -> Data? {
        guard let entry = entries.first(where: { $0.name == name }) else { return nil }
        if entry.size < miniCutoff {
            var result = Data()
            var current = entry.start
            while current < 0xFFFF_FFFA, Int(current) < miniFAT.count, result.count < entry.size {
                let base = Int(current) * miniSectorSize
                guard base + miniSectorSize <= miniStream.count else { break }
                result.append(miniStream.subdata(in: miniStream.startIndex + base..<miniStream.startIndex + base + miniSectorSize))
                current = miniFAT[Int(current)]
            }
            return result.prefix(entry.size)
        }
        var result = Data()
        var current = entry.start
        var steps = 0
        while current < 0xFFFF_FFFA, Int(current) < fat.count, result.count < entry.size, steps <= fat.count {
            let base = 512 + Int(current) * sectorSize
            guard base + sectorSize <= data.count else { break }
            result.append(data.subdata(in: base..<base + sectorSize))
            current = fat[Int(current)]
            steps += 1
        }
        return result.prefix(entry.size)
    }
}

extension Data {
    func uint16(at offset: Int) -> UInt16 {
        let base = startIndex + offset
        guard base + 1 < endIndex else { return 0 }
        return UInt16(self[base]) | UInt16(self[base + 1]) << 8
    }

    func uint32(at offset: Int) -> UInt32 {
        UInt32(uint16(at: offset)) | UInt32(uint16(at: offset + 2)) << 16
    }

    func double(at offset: Int) -> Double {
        let low = UInt64(uint32(at: offset))
        let high = UInt64(uint32(at: offset + 4))
        return Double(bitPattern: low | high << 32)
    }
}
