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

/// The colors of the app icon: a kumquat slice on a leaf.
enum Palette {
    static let rind = [Color(hex: 0xFFC14F), Color(hex: 0xFF9A2A), Color(hex: 0xFF7A12)]
    static let pith = Color(hex: 0xFFF3DC)
    static let core = [Color(hex: 0xFFFBF0), Color(hex: 0xFFEBC8)]
    static let leaf = [Color(hex: 0x6CCB8E), Color(hex: 0x3FA06A), Color(hex: 0x1E6B45)]
    /// Dark brown text for cream backgrounds.
    static let ink = Color(hex: 0x3A2408)
    /// The warm, almost black tint behind the glass.
    static let glass = Color(hex: 0x1C130B)

    static var rindRing: AngularGradient {
        AngularGradient(colors: rind + [rind[1], rind[0]], center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
    }
}

extension Wheel {
    /// Each wheel is a part of the kumquat, so you always know which one is open:
    /// orange flesh converts, the leaf holds the tools, the bright zest does quick actions.
    var colors: [Color] {
        switch self {
        case .convert: [Color(hex: 0xFFD25A), Color(hex: 0xFFA22E), Color(hex: 0xFF7A12)]
        case .tools: [Color(hex: 0x86DDA2), Color(hex: 0x3FA06A), Color(hex: 0x1E6B45)]
        case .actions: [Color(hex: 0xFFFBF0), Color(hex: 0xFFF1B0), Color(hex: 0xFFC94A)]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Lit from the hub outward, like light through a slice.
    func radial(from inner: CGFloat, to outer: CGFloat) -> RadialGradient {
        RadialGradient(colors: colors, center: .center, startRadius: inner, endRadius: outer)
    }

    var tint: Color {
        switch self {
        case .convert: Color(hex: 0xFF8A1C)
        case .tools: Color(hex: 0x3FA06A)
        case .actions: Color(hex: 0xFFC94A)
        }
    }

    /// A darker shade of the tint that reads well on the cream hub.
    var deepTint: Color {
        switch self {
        case .convert: Color(hex: 0xD9620A)
        case .tools: Color(hex: 0x1E6B45)
        case .actions: Color(hex: 0xA86A00)
        }
    }

    /// Text color on top of the wheel's own fill.
    var onFill: Color {
        self == .actions ? Palette.ink : .white
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
    /// `lit` picks the bright segment; cycling it makes the icon spin while Kumquat works.
    static func menuBarIcon(lit: Int = 1) -> NSImage {
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
                NSColor.black.withAlphaComponent(index == lit % segments ? 1 : 0.55).setFill()
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
