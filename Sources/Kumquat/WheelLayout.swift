import CoreGraphics
import Foundation

/// Geometry of the radial menu: up to two rings of segments around a hub.
/// Angles are degrees clockwise from twelve o'clock.
struct WheelLayout {
    static let hubRadius: CGFloat = 66
    static let ringWidth: CGFloat = 64
    static let ringGap: CGFloat = 5
    static let segmentGap: CGFloat = 3
    /// Square area the wheel is drawn in.
    static let canvas: CGFloat = 440
    static let maxSegments = 24

    struct Segment {
        var index: Int
        var inner: CGFloat
        var outer: CGFloat
        var start: Double
        var end: Double

        var midAngle: Double { (start + end) / 2 }
        var midRadius: CGFloat { (inner + outer) / 2 }
    }

    let segments: [Segment]
    let outerRadius: CGFloat

    init(count: Int) {
        let count = min(count, Self.maxSegments)
        let firstRing = count <= 8 ? count : min(8, count / 2)
        var segments: [Segment] = []
        var inner = Self.hubRadius + Self.ringGap
        var placed = 0
        for ringCount in [firstRing, count - firstRing] where ringCount > 0 {
            let outer = inner + Self.ringWidth
            let span = 360 / Double(ringCount)
            for position in 0..<ringCount {
                let mid = Double(position) * span
                segments.append(Segment(index: placed, inner: inner, outer: outer, start: mid - span / 2, end: mid + span / 2))
                placed += 1
            }
            inner = outer + Self.ringGap
        }
        self.segments = segments
        outerRadius = segments.last?.outer ?? Self.hubRadius
    }

    /// The segment under a point given relative to the center, with y pointing up.
    func segment(atX dx: CGFloat, y dy: CGFloat) -> Int? {
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance > Self.hubRadius else { return nil }
        // A little slack outside the outer ring makes the edge easy to hit.
        guard distance <= outerRadius + 28 else { return nil }
        var angle = atan2(Double(dx), Double(dy)) * 180 / .pi
        if angle < 0 { angle += 360 }
        let ringSegments = segments.filter { distance >= $0.inner - Self.ringGap && distance <= $0.outer + Self.ringGap }
        let candidates = ringSegments.isEmpty ? segments.filter { $0.outer == outerRadius } : ringSegments
        return candidates.first { segment in
            let start = segment.start
            var relative = angle - start
            relative = relative.truncatingRemainder(dividingBy: 360)
            if relative < 0 { relative += 360 }
            return relative < segment.end - start
        }?.index
    }

    /// Point for a segment's label in a y-down view space centered at `center`.
    func labelPoint(_ segment: Segment, center: CGPoint) -> CGPoint {
        let radians = segment.midAngle * .pi / 180
        return CGPoint(
            x: center.x + segment.midRadius * CGFloat(sin(radians)),
            y: center.y - segment.midRadius * CGFloat(cos(radians))
        )
    }
}
