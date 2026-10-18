import AppKit
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Image conversions and edits, all through ImageIO and Core Graphics.
public enum ImageEngine {
    private static let writableTypes: Set<String> = {
        Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
    }()

    static func utType(for format: FileFormat) -> UTType? {
        switch format {
        case .jpeg: .jpeg
        case .png: .png
        case .heic: .heic
        case .tiff: .tiff
        case .gif: .gif
        case .bmp: .bmp
        case .webp: .webP
        case .avif: UTType("public.avif")
        default: nil
        }
    }

    /// Whether this Mac can encode the format natively (AVIF and WebP vary by macOS version).
    public static func canWrite(_ format: FileFormat) -> Bool {
        guard let type = utType(for: format) else { return false }
        return writableTypes.contains(type.identifier)
    }

    struct Loaded {
        var image: CGImage
        var properties: [CFString: Any]
    }

    // MARK: Reading

    static func load(_ url: URL) throws -> Loaded {
        if FileFormat.detect(url) == .svg { return try loadVector(url) }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            throw OperationError.unreadable(url.lastPathComponent)
        }
        var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let image: CGImage?
        if orientation == 1 {
            image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        } else {
            // Bake the EXIF rotation into the pixels so every output format looks right.
            let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
            let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(width, height, 1),
                kCGImageSourceShouldCacheImmediately: true,
            ]
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        }
        guard let image else { throw OperationError.unreadable(url.lastPathComponent) }
        properties[kCGImagePropertyOrientation] = 1
        if var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            properties[kCGImagePropertyTIFFDictionary] = tiff
        }
        properties.removeValue(forKey: kCGImagePropertyPixelWidth)
        properties.removeValue(forKey: kCGImagePropertyPixelHeight)
        return Loaded(image: image, properties: properties)
    }

    private static func loadVector(_ url: URL) throws -> Loaded {
        guard let vector = NSImage(contentsOf: url) else { throw OperationError.unreadable(url.lastPathComponent) }
        var size = vector.size
        if size.width < 1 || size.height < 1 { size = CGSize(width: 1024, height: 1024) }
        let scale = max(2, 2048 / max(size.width, size.height))
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())
        guard let context = makeContext(width: width, height: height, alpha: true) else {
            throw OperationError.failed("Couldn't render \(url.lastPathComponent).")
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        vector.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        guard let image = context.makeImage() else { throw OperationError.failed("Couldn't render \(url.lastPathComponent).") }
        return Loaded(image: image, properties: [:])
    }

    // MARK: Writing

    static func write(_ image: CGImage, properties: [CFString: Any]? = nil, to url: URL, format: FileFormat, quality: Double) throws {
        guard let type = utType(for: format) else { throw OperationError.unsupported("Writing \(format.displayName)") }
        var image = image
        if !format.supportsAlpha && image.hasAlpha {
            image = try flatten(image)
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw OperationError.unsupported("Writing \(format.displayName)")
        }
        var options = properties ?? [:]
        options[kCGImageDestinationLossyCompressionQuality] = quality
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: url)
            throw OperationError.failed("Couldn't write \(format.displayName).")
        }
    }

    // MARK: Operations

    public static func convert(_ url: URL, to format: FileFormat, context: OperationContext) throws -> URL {
        let loaded = try load(url)
        let output = context.destination(for: url, extension: format.primaryExtension)
        try write(loaded.image, properties: loaded.properties, to: output, format: format, quality: context.imageQuality)
        return output
    }

    /// Re-encodes lossy images at a lower quality; lossless ones become JPEG (or HEIC when transparent).
    public static func compress(_ url: URL, context: OperationContext) throws -> URL {
        let loaded = try load(url)
        let source = FileFormat.detect(url) ?? .jpeg
        let target: FileFormat
        switch source {
        case .jpeg, .heic, .avif: target = source
        case .webp where canWrite(.webp): target = .webp
        default: target = loaded.image.hasAlpha && canWrite(.heic) ? .heic : .jpeg
        }
        var image = loaded.image
        let longSide = max(image.width, image.height)
        if longSide > 4096 {
            image = try scaled(image, by: 4096 / Double(longSide))
        }
        let output = context.destination(for: url, extension: target.primaryExtension, suffix: "compressed")
        try write(image, properties: loaded.properties, to: output, format: target, quality: min(0.6, context.imageQuality))
        return try keepIfSmaller(output, than: url)
    }

    public enum Edit: Sendable {
        case scale(Double)
        case fit(Int)
        case rotate(clockwise: Bool)
        case flipHorizontal
        case grayscale
        case stripMetadata
        case removeBackground

        var suffix: String {
            switch self {
            case .scale: "half"
            case .fit(let size): "\(size)px"
            case .rotate: "rotated"
            case .flipHorizontal: "flipped"
            case .grayscale: "mono"
            case .stripMetadata: "clean"
            case .removeBackground: "cutout"
            }
        }
    }

    public static func edit(_ url: URL, _ edit: Edit, context: OperationContext) throws -> URL {
        let loaded = try load(url)
        var format = FileFormat.detect(url) ?? .png
        if !canWrite(format) { format = .png }
        var properties: [CFString: Any]? = loaded.properties
        let image: CGImage
        switch edit {
        case .scale(let factor):
            image = try scaled(loaded.image, by: factor)
        case .fit(let size):
            let longSide = max(loaded.image.width, loaded.image.height)
            image = longSide > size ? try scaled(loaded.image, by: Double(size) / Double(longSide)) : loaded.image
        case .rotate(let clockwise):
            image = try rotated(loaded.image, clockwise: clockwise)
        case .flipHorizontal:
            image = try flipped(loaded.image)
        case .grayscale:
            image = try desaturated(loaded.image)
        case .stripMetadata:
            image = loaded.image
            properties = nil
        case .removeBackground:
            guard #available(macOS 14.0, *) else { throw OperationError.unsupported("Background removal before macOS 14") }
            image = try cutout(loaded.image)
            format = .png
        }
        let output = context.destination(for: url, extension: format.primaryExtension, suffix: edit.suffix)
        try write(image, properties: properties, to: output, format: format, quality: context.imageQuality)
        return output
    }

    /// One PDF page per image, in the given order.
    public static func makePDF(from urls: [URL], to output: URL) throws {
        guard let pdf = CGContext(output as CFURL, mediaBox: nil, nil) else {
            throw OperationError.failed("Couldn't create the PDF.")
        }
        for url in urls {
            let loaded = try load(url)
            let dpi = (loaded.properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 72
            var width = Double(loaded.image.width) * 72 / max(dpi, 1)
            var height = Double(loaded.image.height) * 72 / max(dpi, 1)
            let longest = max(width, height)
            if longest > 1440 {
                width *= 1440 / longest
                height *= 1440 / longest
            }
            var box = CGRect(x: 0, y: 0, width: width, height: height)
            pdf.beginPage(mediaBox: &box)
            pdf.interpolationQuality = .high
            pdf.draw(loaded.image, in: box)
            pdf.endPage()
        }
        pdf.closePDF()
    }

    public static func toPDF(_ url: URL, context: OperationContext) throws -> URL {
        let output = context.destination(for: url, extension: "pdf")
        try makePDF(from: [url], to: output)
        return output
    }

    // MARK: Pixel work

    static func makeContext(width: Int, height: Int, alpha: Bool, colorSpace: CGColorSpace? = nil) -> CGContext? {
        let space = colorSpace.flatMap { $0.model == .rgb ? $0 : nil } ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let info = alpha ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: info)
    }

    static func flatten(_ image: CGImage) throws -> CGImage {
        guard let context = makeContext(width: image.width, height: image.height, alpha: false, colorSpace: image.colorSpace) else {
            throw OperationError.failed("Couldn't process the image.")
        }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(rect)
        context.draw(image, in: rect)
        guard let result = context.makeImage() else { throw OperationError.failed("Couldn't process the image.") }
        return result
    }

    static func scaled(_ image: CGImage, by factor: Double) throws -> CGImage {
        let width = max(1, Int((Double(image.width) * factor).rounded()))
        let height = max(1, Int((Double(image.height) * factor).rounded()))
        return try redraw(image, width: width, height: height) { context in
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    static func rotated(_ image: CGImage, clockwise: Bool) throws -> CGImage {
        let width = image.height
        let height = image.width
        return try redraw(image, width: width, height: height) { context in
            if clockwise {
                context.translateBy(x: 0, y: CGFloat(height))
                context.rotate(by: -.pi / 2)
            } else {
                context.translateBy(x: CGFloat(width), y: 0)
                context.rotate(by: .pi / 2)
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
    }

    static func flipped(_ image: CGImage) throws -> CGImage {
        try redraw(image, width: image.width, height: image.height) { context in
            context.translateBy(x: CGFloat(image.width), y: 0)
            context.scaleBy(x: -1, y: 1)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
    }

    private static func redraw(_ image: CGImage, width: Int, height: Int, _ draw: (CGContext) -> Void) throws -> CGImage {
        guard let context = makeContext(width: width, height: height, alpha: image.hasAlpha, colorSpace: image.colorSpace) else {
            throw OperationError.failed("Couldn't process the image.")
        }
        context.interpolationQuality = .high
        draw(context)
        guard let result = context.makeImage() else { throw OperationError.failed("Couldn't process the image.") }
        return result
    }

    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    static func desaturated(_ image: CGImage) throws -> CGImage {
        let input = CIImage(cgImage: image)
        let output = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        guard let result = ciContext.createCGImage(output, from: input.extent) else {
            throw OperationError.failed("Couldn't process the image.")
        }
        return result
    }

    @available(macOS 14.0, *)
    static func cutout(_ image: CGImage) throws -> CGImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw OperationError.failed("No subject found in the image.")
        }
        let buffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: false
        )
        let masked = CIImage(cvPixelBuffer: buffer)
        guard let result = ciContext.createCGImage(masked, from: masked.extent) else {
            throw OperationError.failed("Couldn't process the image.")
        }
        return result
    }
}

extension CGImage {
    var hasAlpha: Bool {
        switch alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: false
        default: true
        }
    }
}
