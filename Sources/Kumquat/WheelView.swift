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

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<Double, Double>> {
        get { AnimatablePair(AnimatablePair(inner, outer), AnimatablePair(start, end)) }
        set {
            inner = newValue.first.first
            outer = newValue.first.second
            start = newValue.second.first
            end = newValue.second.second
        }
    }

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

    var body: some View {
        ZStack(alignment: .top) {
            wheel
                .frame(width: WheelLayout.canvas, height: WheelLayout.canvas)
            // Sits just under the wheel's outer edge, however many rings there are.
            HintBar(active: model.wheel, keyboard: model.isKeyboardMode, isPreview: model.isPreview)
                .modifier(RiseEffect(progress: model.appear))
                .position(x: WheelLayout.canvas / 2, y: WheelLayout.canvas / 2 + model.layout.outerRadius + 34)
        }
        .frame(width: WheelPanel.size.width, height: WheelPanel.size.height, alignment: .top)
        .scaleEffect(model.isShown ? 1 : model.exitScale, anchor: UnitPoint(x: 0.5, y: WheelLayout.canvas / 2 / WheelPanel.size.height))
        .opacity(model.isShown ? 1 : 0)
        .environment(\.colorScheme, .dark)
    }

    private var wheel: some View {
        let layout = model.layout
        let radius = layout.outerRadius + 10
        let center = CGPoint(x: WheelLayout.canvas / 2, y: WheelLayout.canvas / 2)
        let count = layout.segments.count
        return ZStack {
            // Soft shadow under the glass, as a gradient: a blur filter here had to be redrawn on every opening.
            Circle()
                .fill(RadialGradient(
                    colors: [Color.black.opacity(0.3), Color.black.opacity(0.22), Color.black.opacity(0)],
                    center: .center, startRadius: radius - 50, endRadius: radius + 22
                ))
                .frame(width: radius * 2 + 44, height: radius * 2 + 44)
                .offset(y: 12)

            Disc(radius: radius, isPreview: model.isPreview)
                .modifier(PopEffect(progress: model.appear, from: 0.86))

            // A light on the rind that glides to whichever segment is under the pointer.
            SegmentShape(inner: radius - 5.5, outer: radius - 0.5, start: model.indicatorStart, end: model.indicatorEnd, gap: 0)
                .fill(Palette.pith)
                .shadow(color: Color.white.opacity(0.9), radius: 3)
                .shadow(color: model.wheel.tint, radius: 10)
                .opacity(model.highlighted == nil ? 0 : 1)
                .frame(width: WheelLayout.canvas, height: WheelLayout.canvas)

            // Pale membranes between the segments, like a real slice.
            SegmentShape(inner: WheelLayout.hubRadius, outer: layout.outerRadius, start: 0, end: 360, gap: 0)
                .fill(Palette.pith.opacity(0.13))
                .frame(width: WheelLayout.canvas, height: WheelLayout.canvas)
                .modifier(PopEffect(progress: model.bloom, from: 0.7))

            // Juice ring: spreads out from the hub when a wheel opens.
            Circle()
                .strokeBorder(Palette.pith, lineWidth: 2)
                .modifier(RippleEffect(progress: model.bloom, from: WheelLayout.hubRadius, to: radius))

            ForEach(layout.segments, id: \.index) { segment in
                SegmentView(segment: segment, wheel: model.wheel, lift: lift(segment.index), pressed: model.pressed == segment.index)
                    .frame(width: WheelLayout.canvas, height: WheelLayout.canvas)
                    .modifier(BloomEffect(progress: model.bloom, index: segment.index, count: count))
            }

            // Labels get their own canvas-sized layer: with two rings the shadow above is wider than the canvas,
            // which grows this ZStack, and `.position` would then measure from the corner of the larger square
            // (every label sat 16 points up and to the left of its segment).
            ZStack {
                ForEach(layout.segments, id: \.index) { segment in
                    if model.operations.indices.contains(segment.index) {
                        let amount = lift(segment.index)
                        SegmentLabel(
                            operation: model.operations[segment.index],
                            wheel: model.wheel,
                            lift: amount,
                            showsSymbol: model.wheel != .convert
                        )
                        .position(layout.labelPoint(segment, center: center, outward: 2.5 * CGFloat(amount)))
                        .modifier(BloomEffect(progress: model.bloom, index: segment.index, count: count))
                    }
                }
            }
            .frame(width: WheelLayout.canvas, height: WheelLayout.canvas)

            Hub(model: model)
                .modifier(PopEffect(progress: model.appear))
        }
        .frame(width: WheelLayout.canvas, height: WheelLayout.canvas)
    }

    private func lift(_ index: Int) -> Double {
        if let override = model.liftOverride { return override[index] ?? 0 }
        return model.highlighted == index ? 1 : 0
    }
}

/// The glass slice: warm dark glass inside an orange rind with a thin line of pith.
private struct Disc: View {
    let radius: CGFloat
    let isPreview: Bool

    var body: some View {
        ZStack {
            if isPreview {
                // Offscreen rendering can't show live blur, so previews use solid glass.
                Circle().fill(Palette.glass.opacity(0.9))
            } else {
                VisualEffect(material: .hudWindow).clipShape(Circle())
                Circle().fill(Palette.glass.opacity(0.4))
            }
            Circle().strokeBorder(Palette.rindRing, lineWidth: 5)
            Circle().strokeBorder(Palette.pith.opacity(0.45), lineWidth: 1.2).padding(5.5)
            Circle()
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.55), .clear], startPoint: .top, endPoint: .center), lineWidth: 1)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}

private struct SegmentView: View {
    let segment: WheelLayout.Segment
    let wheel: Wheel
    let lift: Double
    let pressed: Bool

    var body: some View {
        // The highlighted segment swells out to the pith.
        let shape = SegmentShape(
            inner: segment.inner - 1.5 * CGFloat(lift),
            outer: segment.outer + 4.5 * CGFloat(lift),
            start: segment.start,
            end: segment.end
        )
        ZStack {
            shape.fill(wheel.radial(from: segment.inner - 20, to: segment.outer + 40)).opacity(0.24)
            // Only the highlighted segment carries its glow, so an opening builds one shadow instead of one per segment.
            if lift > 0 {
                shape
                    .fill(wheel.radial(from: segment.inner, to: segment.outer + 4.5))
                    .shadow(color: wheel.tint.opacity(0.7), radius: 14)
                    .opacity(lift)
                    .transition(.opacity)
            }
            shape.stroke(Palette.pith.opacity(0.12 + 0.4 * lift), lineWidth: 0.75)
            shape.fill(Color.white).opacity(pressed ? 0.55 : 0)
        }
    }
}

private struct SegmentLabel: View {
    let operation: FileOperation
    let wheel: Wheel
    let lift: Double
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
        .foregroundStyle(lift > 0.5 ? wheel.onFill : Color.white.opacity(0.9))
        .frame(width: 66)
        .scaleEffect(1 + 0.12 * lift)
        .allowsHitTesting(false)
    }
}

/// The core of the slice, holding the file you're dragging.
private struct Hub: View {
    @ObservedObject var model: WheelModel

    var body: some View {
        let diameter = WheelLayout.hubRadius * 2 - 4
        ZStack {
            Circle()
                .fill(RadialGradient(colors: Palette.core, center: .center, startRadius: 0, endRadius: diameter / 2))
                .overlay(Circle().strokeBorder(Palette.rindRing, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 40, height: 40)
                        .scaleEffect(model.highlighted == nil ? 1 : 1.08)
                        .rotationEffect(.degrees(model.highlighted == nil ? 0 : -4))
                    if model.urls.count > 1 {
                        Text("\(model.urls.count)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(model.wheel.deepTint))
                            .offset(x: 8, y: -4)
                    }
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: diameter - 22)
                // The target slides in from below each time the pointer moves to another segment.
                ZStack {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(model.highlightedOperation == nil ? Palette.ink.opacity(0.55) : model.wheel.deepTint)
                        .lineLimit(1)
                        .frame(width: diameter - 18)
                        .id(subtitle)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
                .frame(height: 13)
                .clipped()
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
    let isPreview: Bool
    @ObservedObject private var settings = Settings.shared
    @Namespace private var pill

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
                .foregroundStyle(selected ? wheel.onFill : Color.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background {
                    // One pill that slides to the active wheel.
                    if selected {
                        Capsule()
                            .fill(wheel.gradient)
                            .matchedGeometryEffect(id: "pill", in: pill)
                    } else {
                        Capsule().fill(Color.white.opacity(0.06))
                    }
                }
            }
            if keyboard {
                Text("↩ apply  esc cancel")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.horizontal, 6)
            }
        }
        .padding(4)
        .background {
            if isPreview {
                Capsule().fill(Palette.glass.opacity(0.9))
            } else {
                ZStack {
                    VisualEffect(material: .hudWindow).clipShape(Capsule())
                    Capsule().fill(Palette.glass.opacity(0.4))
                }
            }
        }
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
    }
}
