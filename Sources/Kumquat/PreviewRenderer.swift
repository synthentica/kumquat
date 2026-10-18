import AppKit
import KumquatCore
import SwiftUI

/// Renders the wheel to PNG files for the README: `Kumquat --render-previews <folder>`.
enum PreviewRenderer {
    static func render(into folder: String) {
        let directory = URL(fileURLWithPath: folder)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sample = FileManager.default.temporaryDirectory.appendingPathComponent("Holiday photo.heic")
        FileManager.default.createFile(atPath: sample.path, contents: Data())

        let cases: [(Wheel, Int)] = [(.convert, 1), (.tools, 3), (.actions, 0)]
        for (wheel, highlighted) in cases {
            let model = WheelModel()
            model.urls = [sample]
            model.wheel = wheel
            model.operations = wheel == .actions
                ? FileActions.operations(for: model.urls)
                : OperationCatalog.operations(for: model.urls, wheel: wheel, context: OperationContext())
            model.highlighted = highlighted
            model.isShown = true
            model.isPreview = true
            write(model, to: directory.appendingPathComponent("wheel-\(wheel.title.lowercased()).png"))
        }
    }

    private static func write(_ model: WheelModel, to url: URL) {
        let scale: CGFloat = 2
        let size = NSSize(width: 640, height: 560)
        let root = ZStack {
            LinearGradient(
                colors: [Color(hex: 0x2B1D4E), Color(hex: 0x7A3E6B), Color(hex: 0xE58A4E)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            WheelView(model: model)
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(scale)
        .frame(width: size.width * scale, height: size.height * scale)

        let view = NSHostingView(rootView: root)
        view.frame = NSRect(x: 0, y: 0, width: size.width * scale, height: size.height * scale)
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        print("Wrote \(url.path)")
    }
}
