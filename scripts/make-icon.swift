// Draws the 1024 px app icon: a kumquat slice, whose segments double as the wheel.
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
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowBlurRadius = 30
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()
color(0x1E6B45).setFill()
squircle.fill()
NSGraphicsContext.restoreGraphicsState()
// Leaf green, lighter at the top.
NSGradient(colors: [color(0x3FA06A), color(0x1E6B45), color(0x124A30)])!.draw(in: squircle, angle: -90)

func circle(_ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: 512 - radius, y: 512 - radius, width: radius * 2, height: radius * 2))
}

// The slice: rind, pith, then juicy segments around a pale core.
NSGraphicsContext.saveGraphicsState()
let sliceShadow = NSShadow()
sliceShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
sliceShadow.shadowBlurRadius = 36
sliceShadow.shadowOffset = NSSize(width: 0, height: -18)
sliceShadow.set()
color(0xFF8A1C).setFill()
circle(338).fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [color(0xFFB13B), color(0xFF7A12)])!.draw(in: circle(338), angle: -90)
NSGradient(colors: [color(0xFFF8E8), color(0xFFE9C4)])!.draw(in: circle(312), angle: -90)

let center = NSPoint(x: 512, y: 512)
let inner: CGFloat = 64
let outer: CGFloat = 292
let segments = 8
let gap: CGFloat = 9
for index in 0..<segments {
    let span = 360 / CGFloat(segments)
    let mid = 90 - CGFloat(index) * span
    let path = NSBezierPath()
    let outerPad = gap / outer * 180 / .pi
    let innerPad = gap / inner * 180 / .pi
    path.appendArc(withCenter: center, radius: outer, startAngle: mid + span / 2 - outerPad, endAngle: mid - span / 2 + outerPad, clockwise: true)
    path.appendArc(withCenter: center, radius: inner, startAngle: mid - span / 2 + innerPad, endAngle: mid + span / 2 - innerPad, clockwise: false)
    path.close()
    let lit = index == 1
    let colors = lit ? [color(0xFFF1B0), color(0xFFC94A)] : [color(0xFFB547), color(0xFF8A1F)]
    NSGradient(colors: colors)!.draw(in: path, angle: -90)
}
NSGradient(colors: [color(0xFFFBF0), color(0xFFEBC8)])!.draw(in: circle(54), angle: -90)

// A glassy sheen across the top half.
let sheen = NSBezierPath(roundedRect: body.insetBy(dx: 6, dy: 6), xRadius: 180, yRadius: 180)
NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)])!.draw(in: sheen, angle: -90)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
