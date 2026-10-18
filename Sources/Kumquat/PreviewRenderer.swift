import AppKit
import ImageIO
import KumquatCore
import SwiftUI
import UniformTypeIdentifiers

/// Renders the wheel for the README: `Kumquat --render-previews <folder>` writes a PNG per wheel
/// and an animated GIF of the wheel opening, following the pointer and switching wheels.
enum PreviewRenderer {
    private static let sample: URL = {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Holiday photo.heic")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }()

    static func render(into folder: String) {
        let directory = URL(fileURLWithPath: folder)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for (wheel, highlighted) in [(Wheel.convert, 1), (.tools, 3), (.actions, 0)] {
            let model = makeModel(wheel)
            select(highlighted, in: model)
            let stage = Stage(model: model, size: NSSize(width: 640, height: 560), scale: 2)
            stage.writePNG(to: directory.appendingPathComponent("wheel-\(wheel.title.lowercased()).png"))
        }
        renderAnimation(to: directory.appendingPathComponent("wheel.gif"))
    }

    private static func makeModel(_ wheel: Wheel) -> WheelModel {
        let model = WheelModel()
        model.isPreview = true
        model.isShown = true
        model.urls = [sample]
        load(wheel, into: model)
        return model
    }

    private static func load(_ wheel: Wheel, into model: WheelModel) {
        model.wheel = wheel
        model.operations = wheel == .actions
            ? FileActions.operations(for: model.urls)
            : OperationCatalog.operations(for: model.urls, wheel: wheel, context: OperationContext())
        model.highlighted = nil
        model.liftOverride = nil
    }

    private static func select(_ index: Int?, in model: WheelModel) {
        model.highlighted = index
        model.liftOverride = nil
        if let index, let segment = model.layout.segments.first(where: { $0.index == index }) {
            model.indicatorStart = segment.start
            model.indicatorEnd = segment.end
        }
    }

    // MARK: Animation

    private static let frameDelay = 1.0 / 25

    private static func renderAnimation(to url: URL) {
        let model = makeModel(.convert)
        let stage = Stage(model: model, size: NSSize(width: 520, height: 520), scale: 1)
        // Held frames are stored once with a longer delay, which keeps the file small.
        var frames: [(image: CGImage, delay: Double)] = []
        func capture(_ count: Int = 1) {
            guard let image = stage.snapshot() else { return }
            frames.append((image, Double(count) * frameDelay))
        }
        func frameCount(for duration: Double) -> Int { max(1, Int((duration / frameDelay).rounded())) }

        func bloom(appearing: Bool) {
            let count = frameCount(for: Motion.bloomDuration)
            for step in 0...count {
                let t = Double(step) / Double(count)
                model.bloom = t
                if appearing { model.appear = min(1, t * Motion.bloomDuration / Motion.appearDuration) }
                capture()
            }
        }

        /// Glides the highlight from one segment to another, the way the spring does.
        func glide(from: Int?, to: Int) {
            let segments = model.layout.segments
            guard let target = segments.first(where: { $0.index == to }) else { return }
            let origin = from.flatMap { index in segments.first { $0.index == index } }
            let count = frameCount(for: 0.22)
            for step in 1...count {
                let t = Motion.backOut(Double(step) / Double(count), overshoot: 1.2)
                var lifts = [to: min(1, t)]
                if let from { lifts[from] = max(0, 1 - t) }
                model.liftOverride = lifts
                model.highlighted = to
                if let origin {
                    model.indicatorStart = origin.start + (target.start - origin.start) * t
                    model.indicatorEnd = origin.end + (target.end - origin.end) * t
                } else {
                    model.indicatorStart = target.start
                    model.indicatorEnd = target.end
                }
                capture()
            }
            select(to, in: model)
        }

        func hold(_ seconds: Double) { capture(frameCount(for: seconds)) }

        model.appear = 0
        model.bloom = 0
        hold(0.3)
        bloom(appearing: true)
        hold(0.4)
        glide(from: nil, to: 0)
        hold(0.35)
        glide(from: 0, to: 1)
        hold(0.35)
        glide(from: 1, to: 2)
        hold(0.6)

        for wheel in [Wheel.tools, .actions] {
            load(wheel, into: model)
            bloom(appearing: false)
            hold(0.35)
            glide(from: nil, to: 1)
            hold(0.35)
            glide(from: 1, to: 2)
            hold(0.6)
        }

        // Drop: the segment flashes and the wheel takes the file in.
        model.pressed = model.highlighted
        hold(0.05)
        let closing = frameCount(for: 0.22)
        for step in 1...closing {
            let t = Double(step) / Double(closing)
            stage.closing = t * t
            capture()
        }
        stage.closing = 1
        model.pressed = nil
        hold(0.6)

        writeGIF(frames, to: url)
    }

    private static func writeGIF(_ frames: [(image: CGImage, delay: Double)], to url: URL) {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else { return }
        let fileProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]] as CFDictionary
        CGImageDestinationSetProperties(destination, fileProperties)
        for frame in frames {
            let properties = [kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frame.delay,
                kCGImagePropertyGIFUnclampedDelayTime as String: frame.delay,
            ]] as CFDictionary
            CGImageDestinationAddImage(destination, frame.image, properties)
        }
        if CGImageDestinationFinalize(destination) { print("Wrote \(url.path) (\(frames.count) frames)") }
    }
}

/// Hosts the wheel on a backdrop in an offscreen window and captures it.
private final class Stage: ObservableObject {
    let model: WheelModel
    let view: NSHostingView<AnyView>
    private let window: NSWindow
    /// 0 → 1 as the wheel swells and fades after a drop.
    @Published var closing: Double = 0

    init(model: WheelModel, size: NSSize, scale: CGFloat) {
        self.model = model
        let frame = NSRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)
        view = NSHostingView(rootView: AnyView(EmptyView()))
        view.frame = frame
        window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        view.rootView = AnyView(
            Backdrop(stage: self, model: model)
                .frame(width: size.width, height: size.height)
                .scaleEffect(scale)
                .frame(width: frame.width, height: frame.height)
        )
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    }

    func snapshot() -> CGImage? {
        // Let SwiftUI pick up the model changes before drawing.
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.cgImage
    }

    func writePNG(to url: URL) {
        guard let image = snapshot() else { return }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        print("Wrote \(url.path)")
    }
}

private struct Backdrop: View {
    @ObservedObject var stage: Stage
    @ObservedObject var model: WheelModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0F2A1E), Color(hex: 0x24603F), Color(hex: 0xC9822F)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            WheelView(model: model)
                .scaleEffect(1 + 0.07 * stage.closing)
                .opacity(1 - stage.closing)
        }
    }
}
