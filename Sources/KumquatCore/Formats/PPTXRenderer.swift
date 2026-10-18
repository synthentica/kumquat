import AppKit
import Foundation

/// Draws PowerPoint (.pptx) slides into a PDF without PowerPoint or Keynote.
///
/// Covers what most decks are made of: backgrounds, pictures, text boxes and placeholders inherited from
/// the layout and master, filled and outlined shapes, groups and tables, with the theme's colors and fonts.
/// Charts, SmartArt and effects are left out.
public enum PPTXRenderer {
    static let emuPerPoint: CGFloat = 12_700

    public static func toPDF(_ url: URL, context: OperationContext) async throws -> URL {
        let output = context.destination(for: url, extension: "pdf")
        do {
            try await render(url, to: output)
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        return output
    }

    public static func slideImages(_ url: URL, as format: FileFormat, context: OperationContext) async throws -> URL {
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        let pdf = work.appendingPathComponent("slides.pdf")
        // Drawing the slides is the first half of the work, turning them into images the second.
        try await WorkProgress.stage(0, 0.5) { try await render(url, to: pdf) }
        return try await WorkProgress.stage(0.5, 1) {
            try PDFEngine.renderPages(pdf, as: format, dpi: 200, naming: url, context: context)
        }
    }

    static func render(_ url: URL, to output: URL) async throws {
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        try await Zip.extract(url, to: work)
        let package = Package(root: work)
        let presentation = try package.xml("ppt/presentation.xml")
        let size = presentation.firstElement(named: "sldSz")
        let width = CGFloat(Double(size?.attributeValue("cx") ?? "") ?? 9_144_000) / emuPerPoint
        let height = CGFloat(Double(size?.attributeValue("cy") ?? "") ?? 6_858_000) / emuPerPoint
        let relationships = package.relationships(of: "ppt/presentation.xml")
        // Each slide is listed by its relationship id, the `r:id` attribute (not the plain `id`).
        let slides = presentation.elements(named: "sldId").compactMap { slide in
            slide.attributes?.first { $0.localName == "id" && $0.name != "id" }?.stringValue.flatMap { relationships[$0] }
        }
        guard !slides.isEmpty else { throw OperationError.failed("The presentation has no slides.") }

        guard let pdf = CGContext(output as CFURL, mediaBox: nil, nil) else { throw OperationError.failed("Couldn't create the PDF.") }
        for (number, slidePath) in slides.enumerated() {
            WorkProgress.report(number, of: slides.count)
            var box = CGRect(x: 0, y: 0, width: width, height: height)
            pdf.beginPage(mediaBox: &box)
            // Slides are laid out from the top left, so draw with y pointing down.
            pdf.translateBy(x: 0, y: height)
            pdf.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: pdf, flipped: true)
            do {
                let slide = try SlideContext(package: package, slidePath: slidePath)
                slide.draw(in: pdf, size: CGSize(width: width, height: height))
            } catch {
                // A slide we can't read stays blank rather than failing the whole deck.
            }
            NSGraphicsContext.restoreGraphicsState()
            pdf.endPage()
        }
        pdf.closePDF()
    }

    // MARK: Package

    /// The unzipped .pptx, with parsed parts and relationships cached.
    final class Package {
        let root: URL
        private var cache: [String: XMLDocument] = [:]

        init(root: URL) { self.root = root }

        func xml(_ path: String) throws -> XMLDocument {
            if let cached = cache[path] { return cached }
            let document = try XMLDocument(contentsOf: root.appendingPathComponent(path), options: [])
            cache[path] = document
            return document
        }

        /// Relationship id → package path, resolved against the part's folder.
        func relationships(of part: String) -> [String: String] {
            let folder = (part as NSString).deletingLastPathComponent
            let file = (part as NSString).lastPathComponent
            guard let rels = try? xml("\(folder)/_rels/\(file).rels") else { return [:] }
            var map: [String: String] = [:]
            for relationship in rels.elements(named: "Relationship") {
                guard let id = relationship.attributeValue("Id"), let target = relationship.attributeValue("Target"),
                      relationship.attributeValue("TargetMode") != "External" else { continue }
                map[id] = Self.resolve(target, from: folder)
            }
            return map
        }

        static func resolve(_ target: String, from folder: String) -> String {
            if target.hasPrefix("/") { return String(target.dropFirst()) }
            var parts = folder.split(separator: "/").map(String.init)
            for piece in target.split(separator: "/") {
                if piece == ".." { _ = parts.popLast() } else if piece != "." { parts.append(String(piece)) }
            }
            return parts.joined(separator: "/")
        }

        func image(_ path: String) -> CGImage? {
            let url = root.appendingPathComponent(path)
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                return image
            }
            // EMF, WMF and PDF pictures go through AppKit.
            guard let picture = NSImage(contentsOf: url) else { return nil }
            var rect = CGRect(origin: .zero, size: picture.size)
            return picture.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
    }

    // MARK: Slide

    struct Part {
        var path: String
        var document: XMLDocument
        var relationships: [String: String]
    }

    struct SlideContext {
        let package: Package
        let slide: Part
        let layout: Part?
        let master: Part?
        let theme: Theme

        init(package: Package, slidePath: String) throws {
            self.package = package
            func part(_ path: String) throws -> Part {
                Part(path: path, document: try package.xml(path), relationships: package.relationships(of: path))
            }
            func related(_ part: Part, type: String) -> String? {
                guard let rels = try? package.xml("\((part.path as NSString).deletingLastPathComponent)/_rels/\((part.path as NSString).lastPathComponent).rels") else { return nil }
                let id = rels.elements(named: "Relationship").first { ($0.attributeValue("Type") ?? "").hasSuffix("/\(type)") }?.attributeValue("Id")
                return id.flatMap { part.relationships[$0] }
            }
            let slide = try part(slidePath)
            let layout = related(slide, type: "slideLayout").flatMap { try? part($0) }
            let master = layout.flatMap { related($0, type: "slideMaster") }.flatMap { try? part($0) }
            let themeDocument = master.flatMap { related($0, type: "theme") }.flatMap { try? package.xml($0) }
            self.slide = slide
            self.layout = layout
            self.master = master
            theme = Theme(document: themeDocument, colorMap: master?.document.firstElement(named: "clrMap"))
        }

        func draw(in context: CGContext, size: CGSize) {
            let bounds = CGRect(origin: .zero, size: size)
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(bounds)
            // The first background found, from the slide down to the master.
            for part in [slide, layout, master].compactMap({ $0 }) {
                if let background = part.document.firstElement(named: "bg") {
                    drawBackground(background, part: part, in: context, bounds: bounds)
                    break
                }
            }
            let showsMasterShapes = slide.document.rootElement()?.attributeValue("showMasterSp") != "0"
                && layout?.document.rootElement()?.attributeValue("showMasterSp") != "0"
            if showsMasterShapes, let master { drawTree(of: master, placeholders: false, in: context) }
            if let layout { drawTree(of: layout, placeholders: false, in: context) }
            drawTree(of: slide, placeholders: true, in: context)
        }

        private func drawBackground(_ background: XMLElement, part: Part, in context: CGContext, bounds: CGRect) {
            if let properties = background.firstElement(named: "bgPr") {
                if let blip = properties.firstElement(named: "blip"), let id = blip.attributeValue("embed"),
                   let path = part.relationships[id], let image = package.image(path) {
                    drawImage(image, in: bounds, context: context)
                } else if let color = theme.fill(of: properties) {
                    context.setFillColor(color)
                    context.fill(bounds)
                }
            } else if let reference = background.firstElement(named: "bgRef"), let color = theme.color(in: reference) {
                context.setFillColor(color)
                context.fill(bounds)
            }
        }

        private func drawTree(of part: Part, placeholders: Bool, in context: CGContext) {
            guard let tree = part.document.firstElement(named: "spTree") else { return }
            for child in tree.childElements {
                drawShape(child, part: part, placeholders: placeholders, transform: .identity, in: context)
            }
        }

        private func drawShape(_ element: XMLElement, part: Part, placeholders: Bool, transform: CGAffineTransform, in context: CGContext) {
            let placeholder = element.firstElement(named: "nvPr")?.children(named: "ph").first
            // Layout and master placeholders are only templates for the slide's own.
            if placeholder != nil, !placeholders { return }

            switch element.localName ?? "" {
            case "sp", "cxnSp":
                guard let frame = self.frame(of: element, placeholder: placeholder)?.applying(transform) else { return }
                let properties = element.children(named: "spPr").first
                let geometry = properties?.firstElement(named: "prstGeom")?.attributeValue("prst") ?? "rect"
                let path = shapePath(geometry, in: frame)
                if let properties, let fill = theme.fill(of: properties) {
                    context.addPath(path)
                    context.setFillColor(fill)
                    context.fillPath()
                } else if properties?.firstElement(named: "noFill") == nil,
                          let reference = element.firstElement(named: "fillRef"), let fill = theme.color(in: reference),
                          (reference.attributeValue("idx") ?? "0") != "0" {
                    context.addPath(path)
                    context.setFillColor(fill)
                    context.fillPath()
                }
                if let line = properties?.children(named: "ln").first, line.firstElement(named: "noFill") == nil,
                   let color = theme.fill(of: line) {
                    context.addPath(path)
                    context.setStrokeColor(color)
                    context.setLineWidth(max(0.5, CGFloat(Double(line.attributeValue("w") ?? "") ?? 12_700) / emuPerPoint))
                    context.strokePath()
                }
                if let body = element.children(named: "txBody").first {
                    drawText(body, in: frame, placeholder: placeholder, context: context)
                }

            case "pic":
                guard let frame = self.frame(of: element, placeholder: placeholder)?.applying(transform),
                      let id = element.firstElement(named: "blip")?.attributeValue("embed"),
                      let path = part.relationships[id], let image = package.image(path) else { return }
                drawImage(image, in: frame, context: context)

            case "grpSp":
                guard let xfrm = element.children(named: "grpSpPr").first?.firstElement(named: "xfrm") else { return }
                let outer = rect(xfrm, offset: "off", size: "ext")
                let inner = rect(xfrm, offset: "chOff", size: "chExt")
                // Children are placed in the group's own coordinate space.
                var group = CGAffineTransform.identity
                if let outer, let inner, inner.width > 0, inner.height > 0 {
                    group = CGAffineTransform(translationX: outer.minX, y: outer.minY)
                        .scaledBy(x: outer.width / inner.width, y: outer.height / inner.height)
                        .translatedBy(x: -inner.minX, y: -inner.minY)
                }
                for child in element.childElements {
                    drawShape(child, part: part, placeholders: placeholders, transform: group.concatenating(transform), in: context)
                }

            case "graphicFrame":
                guard let table = element.firstElement(named: "tbl"),
                      let xfrm = element.children(named: "xfrm").first,
                      let frame = rect(xfrm, offset: "off", size: "ext")?.applying(transform) else { return }
                drawTable(table, in: frame, context: context)

            default:
                break
            }
        }

        // MARK: Geometry

        func rect(_ xfrm: XMLElement, offset: String, size: String) -> CGRect? {
            guard let off = xfrm.children(named: offset).first, let ext = xfrm.children(named: size).first else { return nil }
            func value(_ element: XMLElement, _ name: String) -> CGFloat {
                CGFloat(Double(element.attributeValue(name) ?? "") ?? 0) / emuPerPoint
            }
            return CGRect(x: value(off, "x"), y: value(off, "y"), width: value(ext, "cx"), height: value(ext, "cy"))
        }

        /// A shape's own position, or the one of the matching placeholder on the layout or master.
        func frame(of element: XMLElement, placeholder: XMLElement?) -> CGRect? {
            if let xfrm = element.children(named: "spPr").first?.children(named: "xfrm").first
                ?? element.children(named: "xfrm").first,
               let rect = rect(xfrm, offset: "off", size: "ext") {
                return rect
            }
            guard let placeholder else { return nil }
            for part in [layout, master].compactMap({ $0 }) {
                if let template = matchingPlaceholder(placeholder, in: part),
                   let xfrm = template.children(named: "spPr").first?.children(named: "xfrm").first,
                   let rect = rect(xfrm, offset: "off", size: "ext") {
                    return rect
                }
            }
            return nil
        }

        func matchingPlaceholder(_ placeholder: XMLElement, in part: Part) -> XMLElement? {
            let type = placeholder.attributeValue("type") ?? "body"
            let index = placeholder.attributeValue("idx")
            let shapes = part.document.elements(named: "sp")
            func placeholderOf(_ shape: XMLElement) -> XMLElement? { shape.firstElement(named: "nvPr")?.children(named: "ph").first }
            if let index, let match = shapes.first(where: { placeholderOf($0)?.attributeValue("idx") == index }) { return match }
            let kinds: Set<String> = type == "ctrTitle" ? ["ctrTitle", "title"] : type == "subTitle" ? ["subTitle", "body"] : [type]
            return shapes.first { kinds.contains(placeholderOf($0)?.attributeValue("type") ?? "body") && placeholderOf($0) != nil }
        }

        func shapePath(_ geometry: String, in frame: CGRect) -> CGPath {
            switch geometry {
            case "ellipse":
                return CGPath(ellipseIn: frame, transform: nil)
            case "roundRect":
                let radius = min(frame.width, frame.height) * 0.1667
                return CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
            case "line", "straightConnector1":
                let path = CGMutablePath()
                path.move(to: CGPoint(x: frame.minX, y: frame.minY))
                path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
                return path
            default:
                return CGPath(rect: frame, transform: nil)
            }
        }

        func drawImage(_ image: CGImage, in frame: CGRect, context: CGContext) {
            context.saveGState()
            // Undo the page flip for the picture itself.
            context.translateBy(x: frame.minX, y: frame.maxY)
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(origin: .zero, size: frame.size))
            context.restoreGState()
        }

        // MARK: Text

        /// Default text size by placeholder kind, when neither the slide nor its templates set one.
        func defaultSize(for placeholder: XMLElement?) -> CGFloat {
            switch placeholder?.attributeValue("type") {
            case "ctrTitle": 44
            case "title": 36
            case "subTitle": 24
            case nil: 18
            default: 20
            }
        }

        /// The size and alignment a placeholder's text inherits from its layout and master templates.
        func inherited(_ placeholder: XMLElement?) -> (size: CGFloat?, alignment: String?, anchor: String?) {
            guard let placeholder else { return (nil, nil, nil) }
            var size: CGFloat?
            var alignment: String?
            var anchor: String?
            for part in [layout, master].compactMap({ $0 }) {
                guard let template = matchingPlaceholder(placeholder, in: part) else { continue }
                if size == nil, let value = template.firstElement(named: "lvl1pPr")?.firstElement(named: "defRPr")?.attributeValue("sz") {
                    size = CGFloat(Double(value) ?? 1800) / 100
                }
                if alignment == nil { alignment = template.firstElement(named: "lvl1pPr")?.attributeValue("algn") }
                if anchor == nil { anchor = template.firstElement(named: "bodyPr")?.attributeValue("anchor") }
            }
            if size == nil, let master {
                let type = placeholder.attributeValue("type") ?? "body"
                let style = type == "title" || type == "ctrTitle" ? "titleStyle" : "bodyStyle"
                if let value = master.document.firstElement(named: style)?.firstElement(named: "lvl1pPr")?
                    .firstElement(named: "defRPr")?.attributeValue("sz") {
                    size = CGFloat(Double(value) ?? 1800) / 100
                }
            }
            return (size, alignment, anchor)
        }

        func drawText(_ body: XMLElement, in frame: CGRect, placeholder: XMLElement?, context: CGContext) {
            let bodyProperties = body.children(named: "bodyPr").first
            let templateStyle = inherited(placeholder)
            let scale = CGFloat(Double(bodyProperties?.firstElement(named: "normAutofit")?.attributeValue("fontScale") ?? "") ?? 100_000) / 100_000
            let baseSize = (templateStyle.size ?? defaultSize(for: placeholder)) * scale
            let isTitle = ["title", "ctrTitle"].contains(placeholder?.attributeValue("type") ?? "")
            let isBody = placeholder != nil && !isTitle && placeholder?.attributeValue("type") != "subTitle"

            let text = NSMutableAttributedString()
            for (index, paragraph) in body.children(named: "p").enumerated() {
                if index > 0 { text.append(NSAttributedString(string: "\n")) }
                let paragraphProperties = paragraph.children(named: "pPr").first
                let style = NSMutableParagraphStyle()
                switch paragraphProperties?.attributeValue("algn") ?? templateStyle.alignment ?? (placeholder?.attributeValue("type") == "ctrTitle" || placeholder?.attributeValue("type") == "subTitle" ? "ctr" : "l") {
                case "ctr": style.alignment = .center
                case "r": style.alignment = .right
                case "just": style.alignment = .justified
                default: style.alignment = .left
                }
                style.paragraphSpacingBefore = baseSize * 0.2
                let level = Int(paragraphProperties?.attributeValue("lvl") ?? "") ?? 0
                let paragraphText = NSMutableAttributedString()
                for run in paragraph.childElements {
                    switch run.localName ?? "" {
                    case "r", "fld":
                        let properties = run.children(named: "rPr").first
                        paragraphText.append(NSAttributedString(string: run.firstElement(named: "t")?.stringValue ?? "",
                                                                attributes: attributes(properties, baseSize: baseSize, scale: scale, isTitle: isTitle)))
                    case "br":
                        paragraphText.append(NSAttributedString(string: "\u{2028}"))
                    default:
                        break
                    }
                }
                let hasBullet = paragraphProperties?.firstElement(named: "buNone") == nil
                    && (paragraphProperties?.firstElement(named: "buChar") != nil || (isBody && paragraphText.length > 0))
                if hasBullet {
                    let attributes = paragraphText.length > 0 ? paragraphText.attributes(at: 0, effectiveRange: nil) : [:]
                    let character = paragraphProperties?.firstElement(named: "buChar")?.attributeValue("char") ?? "•"
                    paragraphText.insert(NSAttributedString(string: "\(character)\t", attributes: attributes), at: 0)
                    let indent = CGFloat(level) * baseSize * 1.2
                    style.firstLineHeadIndent = indent
                    style.headIndent = indent + baseSize * 1.1
                    style.tabStops = [NSTextTab(textAlignment: .left, location: indent + baseSize * 1.1)]
                }
                paragraphText.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: paragraphText.length))
                if paragraphText.length == 0 {
                    paragraphText.append(NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: baseSize), .paragraphStyle: style]))
                }
                text.append(paragraphText)
            }
            guard text.string.contains(where: { !$0.isWhitespace }) else { return }

            func inset(_ name: String, _ fallback: Double) -> CGFloat {
                CGFloat(Double(bodyProperties?.attributeValue(name) ?? "") ?? fallback) / emuPerPoint
            }
            let box = CGRect(x: frame.minX + inset("lIns", 91_440), y: frame.minY + inset("tIns", 45_720),
                             width: max(1, frame.width - inset("lIns", 91_440) - inset("rIns", 91_440)),
                             height: max(1, frame.height - inset("tIns", 45_720) - inset("bIns", 45_720)))
            let needed = text.boundingRect(with: CGSize(width: box.width, height: .greatestFiniteMagnitude),
                                           options: [.usesLineFragmentOrigin, .usesFontLeading]).height
            var origin = box.minY
            switch bodyProperties?.attributeValue("anchor") ?? templateStyle.anchor ?? (isTitle ? "ctr" : "t") {
            case "ctr": origin = box.midY - needed / 2
            case "b": origin = box.maxY - needed
            default: break
            }
            text.draw(with: CGRect(x: box.minX, y: origin, width: box.width, height: max(needed, box.height)),
                      options: [.usesLineFragmentOrigin, .usesFontLeading])
        }

        func attributes(_ properties: XMLElement?, baseSize: CGFloat, scale: CGFloat, isTitle: Bool) -> [NSAttributedString.Key: Any] {
            let size = properties?.attributeValue("sz").flatMap { Double($0) }.map { CGFloat($0) / 100 * scale } ?? baseSize
            let typeface = properties?.firstElement(named: "latin")?.attributeValue("typeface")
            var font = theme.font(typeface, major: isTitle, size: size)
            var traits: NSFontTraitMask = []
            if properties?.attributeValue("b") == "1" { traits.insert(.boldFontMask) }
            if properties?.attributeValue("i") == "1" { traits.insert(.italicFontMask) }
            if !traits.isEmpty { font = NSFontManager.shared.convert(font, toHaveTrait: traits) }
            var attributes: [NSAttributedString.Key: Any] = [.font: font]
            let color = properties.flatMap { theme.fill(of: $0) } ?? theme.color(named: "tx1") ?? CGColor(gray: 0, alpha: 1)
            attributes[.foregroundColor] = NSColor(cgColor: color) ?? NSColor.black
            if properties?.attributeValue("u").map({ $0 != "none" }) == true { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            return attributes
        }

        // MARK: Tables

        func drawTable(_ table: XMLElement, in frame: CGRect, context: CGContext) {
            let columns = table.firstElement(named: "tblGrid")?.children(named: "gridCol")
                .map { CGFloat(Double($0.attributeValue("w") ?? "") ?? 0) / emuPerPoint } ?? []
            var y = frame.minY
            for row in table.children(named: "tr") {
                let height = CGFloat(Double(row.attributeValue("h") ?? "") ?? 0) / emuPerPoint
                var x = frame.minX
                for (index, cell) in row.children(named: "tc").enumerated() {
                    let width = index < columns.count ? columns[index] : 0
                    let rect = CGRect(x: x, y: y, width: width, height: height)
                    if let properties = cell.children(named: "tcPr").first, let fill = theme.fill(of: properties) {
                        context.setFillColor(fill)
                        context.fill(rect)
                    }
                    context.setStrokeColor(CGColor(gray: 0.6, alpha: 1))
                    context.setLineWidth(0.5)
                    context.stroke(rect)
                    if let body = cell.children(named: "txBody").first {
                        drawText(body, in: rect, placeholder: nil, context: context)
                    }
                    x += width
                }
                y += height
            }
        }
    }

    // MARK: Theme

    struct Theme {
        var colors: [String: CGColor] = [:]
        var majorFont = "Helvetica Neue"
        var minorFont = "Helvetica Neue"

        init(document: XMLDocument?, colorMap: XMLElement?) {
            if let scheme = document?.firstElement(named: "clrScheme") {
                for entry in scheme.childElements {
                    if let value = entry.firstElement(named: "srgbClr")?.attributeValue("val") ?? entry.firstElement(named: "sysClr")?.attributeValue("lastClr"),
                       let color = Theme.hex(value) {
                        colors[entry.localName ?? ""] = color
                    }
                }
            }
            // bg1, tx1… point at the scheme's light and dark colors through the master's color map.
            let defaults = ["bg1": "lt1", "tx1": "dk1", "bg2": "lt2", "tx2": "dk2"]
            for (alias, fallback) in defaults {
                let target = colorMap?.attributeValue(alias) ?? fallback
                if let color = colors[target] { colors[alias] = color }
            }
            if let fonts = document?.firstElement(named: "fontScheme") {
                if let major = fonts.firstElement(named: "majorFont")?.firstElement(named: "latin")?.attributeValue("typeface"), !major.isEmpty { majorFont = major }
                if let minor = fonts.firstElement(named: "minorFont")?.firstElement(named: "latin")?.attributeValue("typeface"), !minor.isEmpty { minorFont = minor }
            }
        }

        static func hex(_ hex: String) -> CGColor? {
            guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
            return CGColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                           blue: CGFloat(value & 0xFF) / 255, alpha: 1)
        }

        func color(named name: String) -> CGColor? { colors[name] }

        /// The color inside an element (srgbClr, schemeClr, sysClr or prstClr), with its tint and shade applied.
        func color(in element: XMLElement) -> CGColor? {
            for child in element.childElements {
                var base: CGColor?
                switch child.localName ?? "" {
                case "srgbClr": base = child.attributeValue("val").flatMap(Theme.hex)
                case "schemeClr": base = child.attributeValue("val").flatMap { colors[$0] ?? colors[$0 == "phClr" ? "accent1" : $0] }
                case "sysClr": base = (child.attributeValue("lastClr") ?? child.attributeValue("val")).flatMap(Theme.hex)
                case "prstClr": base = child.attributeValue("val") == "white" ? Theme.hex("FFFFFF") : Theme.hex("000000")
                default: continue
                }
                guard let base else { return nil }
                return Theme.adjust(base, with: child)
            }
            return nil
        }

        /// A solid fill's color; gradients use their first stop.
        func fill(of properties: XMLElement) -> CGColor? {
            for child in properties.childElements {
                switch child.localName ?? "" {
                case "solidFill": return color(in: child)
                case "gradFill": return child.firstElement(named: "gs").flatMap { color(in: $0) }
                case "noFill": return nil
                default: continue
                }
            }
            return nil
        }

        static func adjust(_ color: CGColor, with element: XMLElement) -> CGColor {
            guard let srgb = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
                  let components = srgb.components, components.count >= 3 else { return color }
            let (hue, saturation, baseLightness) = hsl(components[0], components[1], components[2])
            var lightness = baseLightness
            var alpha: CGFloat = 1
            func amount(_ name: String) -> CGFloat? {
                element.children(named: name).first?.attributeValue("val").flatMap { Double($0) }.map { CGFloat($0) / 100_000 }
            }
            if let modulation = amount("lumMod") { lightness *= modulation }
            if let offset = amount("lumOff") { lightness += offset }
            if let tint = amount("tint") { lightness = lightness * tint + (1 - tint) }
            if let shade = amount("shade") { lightness *= shade }
            if let value = amount("alpha") { alpha = value }
            let (red, green, blue) = rgb(hue: hue, saturation: saturation, lightness: min(max(lightness, 0), 1))
            return CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }

        static func hsl(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
            let high = max(r, g, b), low = min(r, g, b)
            let lightness = (high + low) / 2
            guard high != low else { return (0, 0, lightness) }
            let delta = high - low
            let saturation = lightness > 0.5 ? delta / (2 - high - low) : delta / (high + low)
            var hue: CGFloat
            if high == r { hue = (g - b) / delta + (g < b ? 6 : 0) } else if high == g { hue = (b - r) / delta + 2 } else { hue = (r - g) / delta + 4 }
            hue /= 6
            return (hue, saturation, lightness)
        }

        static func rgb(hue: CGFloat, saturation: CGFloat, lightness: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
            guard saturation > 0 else { return (lightness, lightness, lightness) }
            let q = lightness < 0.5 ? lightness * (1 + saturation) : lightness + saturation - lightness * saturation
            let p = 2 * lightness - q
            func channel(_ t: CGFloat) -> CGFloat {
                var t = t
                if t < 0 { t += 1 }
                if t > 1 { t -= 1 }
                if t < 1 / 6 { return p + (q - p) * 6 * t }
                if t < 1 / 2 { return q }
                if t < 2 / 3 { return p + (q - p) * (2 / 3 - t) * 6 }
                return p
            }
            return (channel(hue + 1 / 3), channel(hue), channel(hue - 1 / 3))
        }

        func font(_ typeface: String?, major: Bool, size: CGFloat) -> NSFont {
            var name = typeface ?? (major ? majorFont : minorFont)
            if name == "+mj-lt" { name = majorFont }
            if name == "+mn-lt" { name = minorFont }
            return NSFont(name: name, size: size) ?? NSFont(name: "Helvetica Neue", size: size) ?? NSFont.systemFont(ofSize: size)
        }
    }
}

extension XMLNode {
    var childElements: [XMLElement] { (children ?? []).compactMap { $0 as? XMLElement } }
}
