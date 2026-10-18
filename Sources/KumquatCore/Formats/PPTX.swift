import Foundation
import PDFKit

/// Writes PowerPoint files with one full-slide picture per page, so PDFs open in PowerPoint and Keynote as decks.
public enum PPTX {
    public static func fromPDF(_ url: URL, context: OperationContext) async throws -> URL {
        let document = try PDFEngine.open(url)
        guard document.pageCount > 0 else { throw OperationError.failed("The PDF has no pages.") }
        var pictures: [(jpeg: Data, size: CGSize)] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let image = try PDFEngine.render(page, dpi: 200)
            pictures.append((jpeg: try jpeg(image, quality: context.imageQuality), size: CGSize(width: image.width, height: image.height)))
        }
        guard let first = pictures.first else { throw OperationError.failed("The PDF has no pages.") }
        // The deck takes the first page's shape, 13.33 inches wide.
        let width = 12_192_000
        let height = max(1, Int(Double(width) * Double(first.size.height) / Double(max(first.size.width, 1))))
        let output = context.destination(for: url, extension: "pptx")
        do {
            try await write(pictures: pictures, slideWidth: width, slideHeight: height, to: output)
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
        return output
    }

    static func jpeg(_ image: CGImage, quality: Double) throws -> Data {
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        let file = work.appendingPathComponent("slide.jpg")
        try ImageEngine.write(image, to: file, format: .jpeg, quality: quality)
        return try Data(contentsOf: file)
    }

    /// Each picture is centered and fitted on its own slide.
    static func write(pictures: [(jpeg: Data, size: CGSize)], slideWidth: Int, slideHeight: Int, to output: URL) async throws {
        let work = try FileManager.default.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: work) }
        let fm = FileManager.default
        for folder in ["_rels", "ppt/_rels", "ppt/slides/_rels", "ppt/slideLayouts/_rels", "ppt/slideMasters/_rels", "ppt/theme", "ppt/media"] {
            try fm.createDirectory(at: work.appendingPathComponent(folder), withIntermediateDirectories: true)
        }

        let header = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#
        let ns = #"xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main""#
        let rel = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
        let pkg = "http://schemas.openxmlformats.org/package/2006/relationships"
        let emptyTree = #"<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>"#

        var files: [String: String] = [:]
        var slideTypes = ""
        var slideIDs = ""
        var presentationRels = #"<Relationship Id="rId1" Type="\#(rel)/slideMaster" Target="slideMasters/slideMaster1.xml"/><Relationship Id="rId2" Type="\#(rel)/theme" Target="theme/theme1.xml"/>"#

        for (offset, picture) in pictures.enumerated() {
            let number = offset + 1
            try picture.jpeg.write(to: work.appendingPathComponent("ppt/media/image\(number).jpeg"))
            let scale = min(Double(slideWidth) / Double(max(picture.size.width, 1)), Double(slideHeight) / Double(max(picture.size.height, 1)))
            let cx = Int(Double(picture.size.width) * scale)
            let cy = Int(Double(picture.size.height) * scale)
            let x = (slideWidth - cx) / 2
            let y = (slideHeight - cy) / 2
            files["ppt/slides/slide\(number).xml"] = header + """
            <p:sld \(ns)><p:cSld><p:spTree>\(emptyTree)\
            <p:pic><p:nvPicPr><p:cNvPr id="2" name="Page \(number)"/><p:cNvPicPr><a:picLocks noChangeAspect="1"/></p:cNvPicPr><p:nvPr/></p:nvPicPr>\
            <p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill>\
            <p:spPr><a:xfrm><a:off x="\(x)" y="\(y)"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>\
            </p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>
            """
            files["ppt/slides/_rels/slide\(number).xml.rels"] = header + """
            <Relationships xmlns="\(pkg)">\
            <Relationship Id="rId1" Type="\(rel)/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\
            <Relationship Id="rId2" Type="\(rel)/image" Target="../media/image\(number).jpeg"/>\
            </Relationships>
            """
            slideTypes += #"<Override PartName="/ppt/slides/slide\#(number).xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>"#
            slideIDs += #"<p:sldId id="\#(255 + number)" r:id="rId\#(number + 2)"/>"#
            presentationRels += #"<Relationship Id="rId\#(number + 2)" Type="\#(rel)/slide" Target="slides/slide\#(number).xml"/>"#
        }

        files["[Content_Types].xml"] = header + """
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/>\
        <Default Extension="jpeg" ContentType="image/jpeg"/>\
        <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>\
        <Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/>\
        <Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/>\
        <Override PartName="/ppt/theme/theme1.xml" ContentType="application/vnd.openxmlformats-officedocument.theme+xml"/>\
        \(slideTypes)</Types>
        """
        files["_rels/.rels"] = header + """
        <Relationships xmlns="\(pkg)"><Relationship Id="rId1" Type="\(rel)/officeDocument" Target="ppt/presentation.xml"/></Relationships>
        """
        files["ppt/presentation.xml"] = header + """
        <p:presentation \(ns) saveSubsetFonts="1">\
        <p:sldMasterIdLst><p:sldMasterId id="2147483648" r:id="rId1"/></p:sldMasterIdLst>\
        <p:sldIdLst>\(slideIDs)</p:sldIdLst>\
        <p:sldSz cx="\(slideWidth)" cy="\(slideHeight)"/><p:notesSz cx="6858000" cy="9144000"/>\
        </p:presentation>
        """
        files["ppt/_rels/presentation.xml.rels"] = header + #"<Relationships xmlns="\#(pkg)">\#(presentationRels)</Relationships>"#
        files["ppt/slideMasters/slideMaster1.xml"] = header + """
        <p:sldMaster \(ns)><p:cSld><p:bg><p:bgRef idx="1001"><a:schemeClr val="bg1"/></p:bgRef></p:bg><p:spTree>\(emptyTree)</p:spTree></p:cSld>\
        <p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>\
        <p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst>\
        <p:txStyles><p:titleStyle/><p:bodyStyle/><p:otherStyle/></p:txStyles></p:sldMaster>
        """
        files["ppt/slideMasters/_rels/slideMaster1.xml.rels"] = header + """
        <Relationships xmlns="\(pkg)">\
        <Relationship Id="rId1" Type="\(rel)/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>\
        <Relationship Id="rId2" Type="\(rel)/theme" Target="../theme/theme1.xml"/>\
        </Relationships>
        """
        files["ppt/slideLayouts/slideLayout1.xml"] = header + """
        <p:sldLayout \(ns) type="blank" preserve="1"><p:cSld name="Blank"><p:spTree>\(emptyTree)</p:spTree></p:cSld>\
        <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>
        """
        files["ppt/slideLayouts/_rels/slideLayout1.xml.rels"] = header + """
        <Relationships xmlns="\(pkg)"><Relationship Id="rId1" Type="\(rel)/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>
        """
        files["ppt/theme/theme1.xml"] = header + theme

        for (path, contents) in files {
            try contents.write(to: work.appendingPathComponent(path), atomically: true, encoding: .utf8)
        }
        try await Zip.create(output, from: work, entries: ["[Content_Types].xml", "_rels", "ppt"])
    }

    /// The smallest complete Office theme: colors, fonts and the three-level style matrix.
    static let theme: String = {
        let colors = [
            ("dk1", #"<a:sysClr val="windowText" lastClr="000000"/>"#),
            ("lt1", #"<a:sysClr val="window" lastClr="FFFFFF"/>"#),
            ("dk2", #"<a:srgbClr val="1F2937"/>"#), ("lt2", #"<a:srgbClr val="F3F4F6"/>"#),
            ("accent1", #"<a:srgbClr val="FF8A1C"/>"#), ("accent2", #"<a:srgbClr val="3FA06A"/>"#),
            ("accent3", #"<a:srgbClr val="FFC94A"/>"#), ("accent4", #"<a:srgbClr val="1E6B45"/>"#),
            ("accent5", #"<a:srgbClr val="D9620A"/>"#), ("accent6", #"<a:srgbClr val="6CCB8E"/>"#),
            ("hlink", #"<a:srgbClr val="0563C1"/>"#), ("folHlink", #"<a:srgbClr val="954F72"/>"#),
        ].map { "<a:\($0.0)>\($0.1)</a:\($0.0)>" }.joined()
        let fonts = #"<a:latin typeface="Helvetica Neue"/><a:ea typeface=""/><a:cs typeface=""/>"#
        let fill = #"<a:solidFill><a:schemeClr val="phClr"/></a:solidFill>"#
        let line = #"<a:ln w="9525"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln>"#
        let effect = "<a:effectStyle><a:effectLst/></a:effectStyle>"
        return #"<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Kumquat"><a:themeElements>"#
            + #"<a:clrScheme name="Kumquat">\#(colors)</a:clrScheme>"#
            + #"<a:fontScheme name="Kumquat"><a:majorFont>\#(fonts)</a:majorFont><a:minorFont>\#(fonts)</a:minorFont></a:fontScheme>"#
            + #"<a:fmtScheme name="Kumquat"><a:fillStyleLst>\#(fill)\#(fill)\#(fill)</a:fillStyleLst>"#
            + "<a:lnStyleLst>\(line)\(line)\(line)</a:lnStyleLst>"
            + "<a:effectStyleLst>\(effect)\(effect)\(effect)</a:effectStyleLst>"
            + #"<a:bgFillStyleLst>\#(fill)\#(fill)\#(fill)</a:bgFillStyleLst></a:fmtScheme>"#
            + "</a:themeElements><a:objectDefaults/><a:extraClrSchemeLst/></a:theme>"
    }()
}
