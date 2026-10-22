import CoreGraphics
import Foundation
import PDFKit

/// Reads a page's content stream for what PDFKit doesn't expose: where pictures are drawn, and the filled and
/// stroked shapes (rules, underlines, shaded boxes). Coordinates are the page's own, from the bottom left.
final class GraphicsScan {
    struct ImageHit {
        var rect: CGRect
        /// The picture's JPEG file, when it can be used as is.
        var jpeg: Data?
        var pixelSize: CGSize
    }

    private struct State {
        var ctm = CGAffineTransform.identity
        var fill = PDFLayout.Color.black
        var stroke = PDFLayout.Color.black
        var lineWidth: CGFloat = 1
    }

    private(set) var fills: [(CGRect, PDFLayout.Color)] = []
    private(set) var strokes: [(CGRect, PDFLayout.Color)] = []
    private(set) var images: [ImageHit] = []

    private let page: PDFPage
    private var state = State()
    private var saved: [State] = []
    /// Rectangles (from `re`) and other subpaths of the path being built, already in page space.
    private var rects: [CGRect] = []
    private var subpaths: [[CGPoint]] = []
    private var streams: [CGPDFContentStreamRef] = []
    private var depth = 0
    /// A page can draw thousands of tiny shapes (charts, maps); past this many the rest are ignored.
    private let shapeLimit = 20_000

    init(page: PDFPage) {
        self.page = page
    }

    func scan() {
        guard let reference = page.pageRef else { return }
        let stream = CGPDFContentStreamCreateWithPage(reference)
        run(stream)
        CGPDFContentStreamRelease(stream)
    }

    private func run(_ stream: CGPDFContentStreamRef) {
        guard depth < 12 else { return }
        depth += 1
        streams.append(stream)
        let table = GraphicsScan.operators
        let scanner = CGPDFScannerCreate(stream, table, Unmanaged.passUnretained(self).toOpaque())
        CGPDFScannerScan(scanner)
        CGPDFScannerRelease(scanner)
        streams.removeLast()
        depth -= 1
    }

    // MARK: Operators

    private static let operators: CGPDFOperatorTableRef = {
        let table = CGPDFOperatorTableCreate()!
        func on(_ name: String, _ body: @escaping CGPDFOperatorCallback) { CGPDFOperatorTableSetCallback(table, name, body) }
        on("q") { _, info in GraphicsScan.me(info).saved.append(GraphicsScan.me(info).state) }
        on("Q") { _, info in
            let scan = GraphicsScan.me(info)
            if let last = scan.saved.popLast() { scan.state = last }
        }
        on("cm") { scanner, info in
            guard let m = GraphicsScan.numbers(scanner, 6) else { return }
            let scan = GraphicsScan.me(info)
            scan.state.ctm = CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5]).concatenating(scan.state.ctm)
        }
        on("w") { scanner, info in
            if let w = GraphicsScan.numbers(scanner, 1) { GraphicsScan.me(info).state.lineWidth = w[0] }
        }
        on("g") { scanner, info in if let v = GraphicsScan.numbers(scanner, 1) { GraphicsScan.me(info).state.fill = GraphicsScan.gray(v[0]) } }
        on("G") { scanner, info in if let v = GraphicsScan.numbers(scanner, 1) { GraphicsScan.me(info).state.stroke = GraphicsScan.gray(v[0]) } }
        on("rg") { scanner, info in if let v = GraphicsScan.numbers(scanner, 3) { GraphicsScan.me(info).state.fill = PDFLayout.Color(red: v[0], green: v[1], blue: v[2]) } }
        on("RG") { scanner, info in if let v = GraphicsScan.numbers(scanner, 3) { GraphicsScan.me(info).state.stroke = PDFLayout.Color(red: v[0], green: v[1], blue: v[2]) } }
        on("k") { scanner, info in if let v = GraphicsScan.numbers(scanner, 4) { GraphicsScan.me(info).state.fill = GraphicsScan.cmyk(v) } }
        on("K") { scanner, info in if let v = GraphicsScan.numbers(scanner, 4) { GraphicsScan.me(info).state.stroke = GraphicsScan.cmyk(v) } }
        on("sc") { scanner, info in if let color = GraphicsScan.anyColor(scanner) { GraphicsScan.me(info).state.fill = color } }
        on("scn") { scanner, info in if let color = GraphicsScan.anyColor(scanner) { GraphicsScan.me(info).state.fill = color } }
        on("SC") { scanner, info in if let color = GraphicsScan.anyColor(scanner) { GraphicsScan.me(info).state.stroke = color } }
        on("SCN") { scanner, info in if let color = GraphicsScan.anyColor(scanner) { GraphicsScan.me(info).state.stroke = color } }
        on("re") { scanner, info in
            guard let v = GraphicsScan.numbers(scanner, 4) else { return }
            let scan = GraphicsScan.me(info)
            scan.rects.append(CGRect(x: v[0], y: v[1], width: v[2], height: v[3]).applying(scan.state.ctm).standardized)
        }
        on("m") { scanner, info in
            guard let v = GraphicsScan.numbers(scanner, 2) else { return }
            let scan = GraphicsScan.me(info)
            scan.subpaths.append([CGPoint(x: v[0], y: v[1]).applying(scan.state.ctm)])
        }
        on("l") { scanner, info in
            guard let v = GraphicsScan.numbers(scanner, 2) else { return }
            GraphicsScan.me(info).addPoint(CGPoint(x: v[0], y: v[1]))
        }
        on("c") { scanner, info in
            guard let v = GraphicsScan.numbers(scanner, 6) else { return }
            let scan = GraphicsScan.me(info)
            for i in stride(from: 0, to: 6, by: 2) { scan.addPoint(CGPoint(x: v[i], y: v[i + 1])) }
        }
        for name in ["v", "y"] {
            on(name) { scanner, info in
                guard let v = GraphicsScan.numbers(scanner, 4) else { return }
                let scan = GraphicsScan.me(info)
                scan.addPoint(CGPoint(x: v[0], y: v[1]))
                scan.addPoint(CGPoint(x: v[2], y: v[3]))
            }
        }
        for name in ["f", "F", "f*"] { on(name) { _, info in GraphicsScan.me(info).paint(fill: true, stroke: false) } }
        for name in ["B", "B*", "b", "b*"] { on(name) { _, info in GraphicsScan.me(info).paint(fill: true, stroke: true) } }
        for name in ["S", "s"] { on(name) { _, info in GraphicsScan.me(info).paint(fill: false, stroke: true) } }
        on("n") { _, info in GraphicsScan.me(info).clearPath() }
        on("Do") { scanner, info in
            var name: UnsafePointer<CChar>?
            guard CGPDFScannerPopName(scanner, &name), let name else { return }
            GraphicsScan.me(info).drawObject(String(cString: name))
        }
        return table
    }()

    private static func me(_ info: UnsafeMutableRawPointer?) -> GraphicsScan {
        Unmanaged<GraphicsScan>.fromOpaque(info!).takeUnretainedValue()
    }

    /// Pops `count` numbers, returned in the order they were written.
    private static func numbers(_ scanner: CGPDFScannerRef, _ count: Int) -> [CGFloat]? {
        var values: [CGFloat] = []
        for _ in 0..<count {
            var value: CGPDFReal = 0
            guard CGPDFScannerPopNumber(scanner, &value) else { return nil }
            values.append(value)
        }
        return values.reversed()
    }

    /// The color for `sc`/`scn`, by how many components it has (a pattern, named last, gives none).
    private static func anyColor(_ scanner: CGPDFScannerRef) -> PDFLayout.Color? {
        var values: [CGFloat] = []
        var object: CGPDFObjectRef?
        while values.count < 4, CGPDFScannerPopObject(scanner, &object), let object {
            var value: CGPDFReal = 0
            guard CGPDFObjectGetValue(object, .real, &value) else { return nil }
            values.append(value)
        }
        values.reverse()
        switch values.count {
        case 1: return gray(values[0])
        case 3: return PDFLayout.Color(red: values[0], green: values[1], blue: values[2])
        case 4: return cmyk(values)
        default: return nil
        }
    }

    private static func gray(_ value: CGFloat) -> PDFLayout.Color { PDFLayout.Color(red: value, green: value, blue: value) }

    private static func cmyk(_ v: [CGFloat]) -> PDFLayout.Color {
        PDFLayout.Color(red: (1 - v[0]) * (1 - v[3]), green: (1 - v[1]) * (1 - v[3]), blue: (1 - v[2]) * (1 - v[3]))
    }

    // MARK: Paths

    private func addPoint(_ point: CGPoint) {
        let mapped = point.applying(state.ctm)
        if subpaths.isEmpty { subpaths.append([mapped]) } else { subpaths[subpaths.count - 1].append(mapped) }
    }

    private func clearPath() {
        rects.removeAll(keepingCapacity: true)
        subpaths.removeAll(keepingCapacity: true)
    }

    private func paint(fill: Bool, stroke: Bool) {
        defer { clearPath() }
        guard fills.count + strokes.count < shapeLimit else { return }
        let shapes = rects + subpaths.filter { $0.count > 1 }.map { points -> CGRect in
            let xs = points.map(\.x), ys = points.map(\.y)
            return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        }
        if fill {
            for shape in shapes where shape.width > 0 && shape.height > 0 { fills.append((shape, state.fill)) }
        }
        if stroke {
            // A stroke's thickness, in page units.
            let scale = sqrt(abs(state.ctm.a * state.ctm.d - state.ctm.b * state.ctm.c))
            let thickness = max(state.lineWidth * scale, 0.25)
            for points in subpaths where points.count > 1 {
                for (start, end) in zip(points, points.dropFirst()) where abs(start.y - end.y) < 0.5 && abs(start.x - end.x) > 0.5 {
                    strokes.append((CGRect(x: min(start.x, end.x), y: start.y - thickness / 2, width: abs(end.x - start.x), height: thickness), state.stroke))
                }
            }
        }
    }

    // MARK: XObjects

    private func drawObject(_ name: String) {
        guard let stream = streams.last,
              let object = CGPDFContentStreamGetResource(stream, "XObject", name)
        else { return }
        var xobject: CGPDFStreamRef?
        guard CGPDFObjectGetValue(object, .stream, &xobject), let xobject, let dictionary = CGPDFStreamGetDictionary(xobject) else { return }
        var subtype: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetName(dictionary, "Subtype", &subtype), let subtype else { return }
        switch String(cString: subtype) {
        case "Image":
            image(xobject, dictionary)
        case "Form":
            var matrix = CGAffineTransform.identity
            var array: CGPDFArrayRef?
            if CGPDFDictionaryGetArray(dictionary, "Matrix", &array), let array, CGPDFArrayGetCount(array) == 6 {
                var m: [CGFloat] = []
                for index in 0..<6 {
                    var value: CGPDFReal = 0
                    if CGPDFArrayGetNumber(array, index, &value) { m.append(value) }
                }
                if m.count == 6 { matrix = CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5]) }
            }
            var resources: CGPDFDictionaryRef?
            CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources)
            let form = CGPDFContentStreamCreateWithStream(xobject, resources ?? CGPDFStreamGetDictionary(xobject)!, stream)
            let outer = state
            let outerRects = rects, outerPaths = subpaths
            saved.append(state)
            state.ctm = matrix.concatenating(state.ctm)
            clearPath()
            run(form)
            CGPDFContentStreamRelease(form)
            state = saved.popLast() ?? outer
            rects = outerRects
            subpaths = outerPaths
        default:
            break
        }
    }

    private func image(_ stream: CGPDFStreamRef, _ dictionary: CGPDFDictionaryRef) {
        guard images.count < 500 else { return }
        let ctm = state.ctm
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1).applying(ctm).standardized
        var width: CGPDFInteger = 0, height: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(dictionary, "Width", &width)
        CGPDFDictionaryGetInteger(dictionary, "Height", &height)
        var hit = ImageHit(rect: rect, jpeg: nil, pixelSize: CGSize(width: Int(width), height: Int(height)))
        // An upright JPEG in RGB or gray without a mask can go into the document exactly as it is.
        let upright = abs(ctm.b) < 1e-6 && abs(ctm.c) < 1e-6 && ctm.a > 0 && ctm.d > 0
        var mask: CGPDFObjectRef?
        let masked = CGPDFDictionaryGetObject(dictionary, "SMask", &mask) || CGPDFDictionaryGetObject(dictionary, "Mask", &mask)
            || CGPDFDictionaryGetObject(dictionary, "Decode", &mask)
        if upright, !masked, plainColorSpace(dictionary) {
            var format = CGPDFDataFormat.raw
            if let data = CGPDFStreamCopyData(stream, &format), format == .jpegEncoded {
                hit.jpeg = data as Data
            }
        }
        images.append(hit)
    }

    private func plainColorSpace(_ dictionary: CGPDFDictionaryRef) -> Bool {
        var name: UnsafePointer<CChar>?
        if CGPDFDictionaryGetName(dictionary, "ColorSpace", &name), let name {
            return ["DeviceRGB", "DeviceGray"].contains(String(cString: name))
        }
        var array: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dictionary, "ColorSpace", &array), let array, CGPDFArrayGetCount(array) == 2 else {
            // No color space: a JPEG says its own.
            var any: CGPDFObjectRef?
            return !CGPDFDictionaryGetObject(dictionary, "ColorSpace", &any)
        }
        var kind: UnsafePointer<CChar>?
        guard CGPDFArrayGetName(array, 0, &kind), let kind, String(cString: kind) == "ICCBased" else { return false }
        var profile: CGPDFStreamRef?
        guard CGPDFArrayGetStream(array, 1, &profile), let profile, let info = CGPDFStreamGetDictionary(profile) else { return false }
        var components: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(info, "N", &components)
        return components == 1 || components == 3
    }
}
