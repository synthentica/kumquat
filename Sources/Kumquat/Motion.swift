import AppKit
import SwiftUI

/// Timing and easing for every animation in the app.
///
/// Opening and switching wheels is driven by a single 0...1 progress value animated linearly;
/// each piece applies its own easing and delay to it. That keeps the choreography in one place and
/// lets the preview renderer draw any frame of it.
enum Motion {
    static let bloomDuration = 0.4
    static let appearDuration = 0.34
    static let highlight = Animation.spring(response: 0.26, dampingFraction: 0.68)
    static let switchWheel = Animation.spring(response: 0.3, dampingFraction: 0.8)

    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }

    static func cubicOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }

    /// Overshoots a little before settling, like a spring.
    static func backOut(_ t: Double, overshoot: Double = 1.7) -> Double {
        let t1 = t - 1
        return 1 + (overshoot + 1) * t1 * t1 * t1 + overshoot * t1 * t1
    }

    /// One item's own progress inside a staggered sequence of `count` items.
    static func stagger(_ progress: Double, index: Int, count: Int, spread: Double = 0.45) -> Double {
        let start = count > 1 ? spread * Double(index) / Double(count - 1) : 0
        return clamp((progress - start) / (1 - spread))
    }
}

/// Segments fly out of the hub one after another, turning into place with a small overshoot.
struct BloomEffect: AnimatableModifier {
    var progress: Double
    let index: Int
    let count: Int

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = Motion.stagger(progress, index: index, count: count)
        return content
            .scaleEffect(0.5 + 0.5 * Motion.backOut(t))
            .rotationEffect(.degrees(-24 * (1 - Motion.cubicOut(t))))
            .opacity(Motion.clamp(t * 2.5))
    }
}

/// Pops a view in from smaller, with an overshoot.
struct PopEffect: AnimatableModifier {
    var progress: Double
    var from: Double = 0.6

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = Motion.clamp(progress * 1.6)
        return content
            .scaleEffect(from + (1 - from) * Motion.backOut(t, overshoot: 2.2))
            .opacity(Motion.clamp(progress * 4))
    }
}

/// Slides a view up into place while it fades in.
struct RiseEffect: AnimatableModifier {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = Motion.clamp((progress - 0.25) / 0.75)
        return content
            .offset(y: 14 * (1 - Motion.cubicOut(t)))
            .opacity(t)
    }
}

/// A ring of light that spreads from the hub to the rind and fades out.
struct RippleEffect: AnimatableModifier {
    var progress: Double
    let from: CGFloat
    let to: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = Motion.cubicOut(Motion.clamp(progress * 1.25))
        let diameter = (from + (to - from) * CGFloat(t)) * 2
        let visible = progress > 0 && progress < 1
        return content
            .frame(width: diameter, height: diameter)
            .opacity(visible ? 0.55 * (1 - t) : 0)
    }
}

/// Shakes a view sideways, for errors.
struct ShakeEffect: GeometryEffect {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        // Only the fraction matters, so each whole step is one shake.
        let t = progress - progress.rounded(.down)
        let offset = 6 * sin(t * .pi * 6) * (1 - t)
        return ProjectionTransform(CGAffineTransform(translationX: offset, y: 0))
    }
}

/// A checkmark that can be drawn on with `trim`.
struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.27, y: rect.minY + rect.height * 0.53))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.44, y: rect.minY + rect.height * 0.70))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.75, y: rect.minY + rect.height * 0.34))
        return path
    }
}

/// The kumquat slice spinning while something converts: segments light up one after another.
struct SliceSpinner: View {
    var size: CGFloat = 22
    /// Stops the clock while nobody can see the spinner, so a hidden window costs nothing.
    var paused = false

    var body: some View {
        // The glow moves slowly, so 30 frames a second looks the same as 120 and costs a quarter.
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    let phase = (time * 1.6 - Double(index) / 6).truncatingRemainder(dividingBy: 1)
                    let glow = pow(1 - (phase < 0 ? phase + 1 : phase), 2.2)
                    SegmentShape(
                        inner: size * 0.2, outer: size * 0.5,
                        start: Double(index) * 60 - 30, end: Double(index) * 60 + 30,
                        gap: size * 0.07
                    )
                    .fill(LinearGradient(colors: Palette.rind, startPoint: .top, endPoint: .bottom))
                    .opacity(0.35 + 0.65 * glow)
                }
                Circle().fill(Palette.pith).frame(width: size * 0.22, height: size * 0.22)
            }
            .frame(width: size, height: size)
            .rotationEffect(.degrees(time * 90))
        }
    }
}
