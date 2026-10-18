import AppKit
import KumquatCore
import SwiftUI
import UniformTypeIdentifiers

/// An annular sector, built from clockwise-from-top angles with constant-width gaps.
struct SegmentShape: Shape {
    var inner: CGFloat
    var outer: CGFloat
    var start: Double
    var end: Double
    var gap: CGFloat = WheelLayout.segmentGap

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Converts a radius into the angle that spans half the gap there, so gaps stay parallel.
        func pad(_ radius: CGFloat) -> Double { Double(gap / 2 / radius) * 180 / .pi }
        let singleSegment = end - start >= 359.9
        let outerPad = singleSegment ? 0 : pad(outer)
        let innerPad = singleSegment ? 0 : pad(inner)
        var path = Path()
        // SwiftUI measures from three o'clock and its y axis points down: subtract 90 degrees.
        path.addArc(center: center, radius: outer, startAngle: .degrees(start + outerPad - 90),
                    endAngle: .degrees(end - outerPad - 90), clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: .degrees(end - innerPad - 90),
                    endAngle: .degrees(start + innerPad - 90), clockwise: true)
        path.closeSubpath()
        return path
    }
}

struct WheelView: View {
    @ObservedObject var model: WheelModel
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        ZStack(alignment: .top) {
            wheel
                .frame(width: WheelLayout.canvas, height: WheelLayout.canvas)
            // Sits just under the wheel's outer edge, however many rings there are.
            HintBar(active: model.wheel, keyboard: model.isKeyboardMode)
                .position(x: WheelLayout.canvas / 2, y: WheelLayout.canvas / 2 + model.layout.outerRadius + 34)
        }
        .frame(width: WheelPanel.size.width, height: WheelPanel.size.height, alignment: .top)
        .scaleEffect(model.isShown ? 1 : 0.82)
        .opacity(model.isShown ? 1 : 0)
    }

    private var wheel: some View {
        let layout = model.layout
        let diameter = (layout.outerRadius + 10) * 2
        let center = CGPoint(x: WheelLayout.canvas / 2, y: WheelLayout.canvas / 2)
        return ZStack {
            // Soft shadow under the glass.
            Circle()
                .fill(Color.black.opacity(0.28))
                .frame(width: diameter - 16, height: diameter - 16)
                .blur(radius: 22)
                .offset(y: 12)

            VisualEffect(material: .hudWindow)
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(Circle().fill(Color(hex: 0x15131C).opacity(model.isPreview ? 0.82 : 0.28)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
                .overlay(Circle().strokeBorder(model.wheel.gradient, lineWidth: 1.5).opacity(0.75).padding(3))

            ForEach(layout.segments, id: \.index) { segment in
                let selected = model.highlighted == segment.index
                SegmentShape(inner: segment.inner, outer: segment.outer, start: segment.start, end: segment.end)
                    .fill(selected ? AnyShapeStyle(model.wheel.gradient) : AnyShapeStyle(Color.white.opacity(0.07)))
                    .overlay(
                        SegmentShape(inner: segment.inner, outer: segment.outer, start: segment.start, end: segment.end)
                            .stroke(Color.white.opacity(selected ? 0.35 : 0.08), lineWidth: 0.75)
                    )
                    .shadow(color: selected ? model.wheel.tint.opacity(0.55) : .clear, radius: 12)
                    .scaleEffect(selected ? 1.035 : 1)
                    .frame(width: WheelLayout.canvas, height: WheelLayout.canvas)
            }

            ForEach(layout.segments, id: \.index) { segment in
                if model.operations.indices.contains(segment.index) {
                    SegmentLabel(
                        operation: model.operations[segment.index],
                        selected: model.highlighted == segment.index,
                        showsSymbol: model.wheel != .convert
                    )
                    .position(layout.labelPoint(segment, center: center))
                }
            }

            Hub(model: model)
        }
        .frame(width: WheelLayout.canvas, height: WheelLayout.canvas)
        .environment(\.colorScheme, .dark)
    }
}

private struct SegmentLabel: View {
    let operation: FileOperation
    let selected: Bool
    let showsSymbol: Bool

    var body: some View {
        VStack(spacing: 2) {
            if showsSymbol {
                Image(systemName: operation.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(height: 17)
            }
            Text(operation.title)
                .font(.system(size: showsSymbol ? 10.5 : 13.5, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let subtitle = operation.subtitle, !showsSymbol {
                Text(subtitle)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .opacity(0.65)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Color.white.opacity(selected ? 1 : 0.88))
        .frame(width: 66)
        .scaleEffect(selected ? 1.1 : 1)
        .allowsHitTesting(false)
    }
}

private struct Hub: View {
    @ObservedObject var model: WheelModel

    var body: some View {
        let diameter = WheelLayout.hubRadius * 2 - 4
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75))
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 40, height: 40)
                    if model.urls.count > 1 {
                        Text("\(model.urls.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(model.wheel.tint))
                            .offset(x: 8, y: -4)
                    }
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: diameter - 22)
                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(model.highlightedOperation == nil ? Color.white.opacity(0.6) : model.wheel.tint)
                    .lineLimit(1)
                    .frame(width: diameter - 18)
            }
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
    }

    private var icon: NSImage {
        guard let first = model.urls.first else { return NSWorkspace.shared.icon(for: .data) }
        return NSWorkspace.shared.icon(forFile: first.path)
    }

    private var title: String {
        if model.urls.count == 1 { return model.urls[0].lastPathComponent }
        if model.urls.isEmpty { return model.wheel.title }
        return "\(model.urls.count) items"
    }

    private var subtitle: String {
        if let operation = model.highlightedOperation {
            return model.wheel == .convert ? "→ \(operation.title)" : operation.title
        }
        if model.operations.isEmpty, !model.urls.isEmpty { return "Nothing here" }
        return model.wheel.title
    }
}

private struct HintBar: View {
    let active: Wheel
    let keyboard: Bool
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Wheel.allCases, id: \.self) { wheel in
                let selected = wheel == active
                HStack(spacing: 4) {
                    Text(settings.key(for: wheel).glyph)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Text(wheel.title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.white.opacity(selected ? 1 : 0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(selected ? AnyShapeStyle(wheel.gradient) : AnyShapeStyle(Color.white.opacity(0.06))))
            }
            if keyboard {
                Text("↩ apply  esc cancel")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.horizontal, 6)
            }
        }
        .padding(4)
        .background(VisualEffect(material: .hudWindow).clipShape(Capsule()))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
        .environment(\.colorScheme, .dark)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: active)
    }
}
