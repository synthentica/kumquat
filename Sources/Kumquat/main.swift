import AppKit

let app = NSApplication.shared

if let flag = CommandLine.arguments.firstIndex(of: "--render-previews") {
    let folder = CommandLine.arguments.indices.contains(flag + 1) ? CommandLine.arguments[flag + 1] : "previews"
    PreviewRenderer.render(into: folder)
    exit(0)
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
