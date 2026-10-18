// Draws the 1024 px app icon: a warm squircle with the conversion wheel.
// Usage: swift scripts/make-icon.swift output.png
import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let size = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255, alpha: alpha
    )
}

// Body, on Apple's 824 pt grid with a soft drop shadow.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()
color(0xFF7A3D).setFill()
squircle.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(colors: [color(0xFFB347), color(0xFF6B4A), color(0xF0457A)])!.draw(in: squircle, angle: -62)
// Glassy top highlight.
NSGradient(colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0)])!
    .draw(in: NSBezierPath(roundedRect: body.insetBy(dx: 6, dy: 6), xRadius: 180, yRadius: 180), angle: -90)

// The wheel: six segments around a hub, one lit.
let center = NSPoint(x: 512, y: 512)
let inner: CGFloat = 168
let outer: CGFloat = 318
let segments = 6
let gap: CGFloat = 7
for index in 0..<segments {
    let span = 360 / CGFloat(segments)
    let mid = 90 - CGFloat(index) * span
    let path = NSBezierPath()
    let outerPad = gap / outer * 180 / .pi
    let innerPad = gap / inner * 180 / .pi
    path.appendArc(withCenter: center, radius: outer, startAngle: mid + span / 2 - outerPad, endAngle: mid - span / 2 + outerPad, clockwise: true)
    path.appendArc(withCenter: center, radius: inner, startAngle: mid - span / 2 + innerPad, endAngle: mid + span / 2 - innerPad, clockwise: false)
    path.close()
    (index == 1 ? NSColor.white : NSColor.white.withAlphaComponent(0.34)).setFill()
    path.fill()
}
let hub = NSBezierPath(ovalIn: NSRect(x: center.x - 128, y: center.y - 128, width: 256, height: 256))
NSColor.white.setFill()
hub.fill()
// Arrow in the hub, pointing at the lit segment.
let arrow = NSBezierPath()
arrow.lineWidth = 30
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 462, y: 462))
arrow.line(to: NSPoint(x: 566, y: 566))
arrow.move(to: NSPoint(x: 500, y: 572))
arrow.line(to: NSPoint(x: 570, y: 570))
arrow.line(to: NSPoint(x: 568, y: 500))
color(0xFF6B4A).setStroke()
arrow.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
