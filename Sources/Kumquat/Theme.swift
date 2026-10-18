import AppKit
import KumquatCore
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Wheel {
    /// Each wheel has its own color, so you always know which one is open.
    var gradient: LinearGradient {
        let colors: [Color]
        switch self {
        case .convert: colors = [Color(hex: 0xFFA43A), Color(hex: 0xFF5F57), Color(hex: 0xF0457A)]
        case .tools: colors = [Color(hex: 0x8E7CFF), Color(hex: 0x5B6CFF), Color(hex: 0x3B8CFF)]
        case .actions: colors = [Color(hex: 0x2FD6A6), Color(hex: 0x17B8C8), Color(hex: 0x1C9BE0)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var tint: Color {
        switch self {
        case .convert: Color(hex: 0xFF6B4A)
        case .tools: Color(hex: 0x6E6CFF)
        case .actions: Color(hex: 0x1DB6B8)
        }
    }
}

/// Real behind-window blur, which SwiftUI materials can't do in a borderless panel.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

enum Glyphs {
    /// The menu bar icon: the wheel in miniature, as a template image.
    static func menuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let segments = 6
            let span = 360 / CGFloat(segments)
            for index in 0..<segments {
                let mid = 90 - CGFloat(index) * span
                let path = NSBezierPath()
                path.appendArc(withCenter: center, radius: 8, startAngle: mid + span / 2 - 7, endAngle: mid - span / 2 + 7, clockwise: true)
                path.appendArc(withCenter: center, radius: 4.6, startAngle: mid - span / 2 + 11, endAngle: mid + span / 2 - 11, clockwise: false)
                path.close()
                NSColor.black.withAlphaComponent(index == 1 ? 1 : 0.55).setFill()
                path.fill()
            }
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 2.6, y: center.y - 2.6, width: 5.2, height: 5.2)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
