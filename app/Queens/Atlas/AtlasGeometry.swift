import Foundation

// The journey maps' hand-drawn geometry, ported from the mockup (`realm-template.html`). Pure
// functions on points in map units (390 wide), so they can be checked without UI.

/// SplitMix64. Each feature gets its own seed, so a hill keeps its shape between launches.
struct AtlasRandom {
    private var state: UInt64

    init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) }

    /// A value in 0..<1.
    mutating func next() -> CGFloat {
        state &+= 0x9e37_79b9_7f4a_7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
        z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
        z ^= z >> 31
        return CGFloat(z >> 11) / CGFloat(UInt64(1) << 53)
    }

    mutating func next(_ range: ClosedRange<CGFloat>) -> CGFloat {
        range.lowerBound + (range.upperBound - range.lowerBound) * next()
    }
}

/// Smooth value noise in 0...1, three octaves: the mockup's `noise2`. Drives coast wiggle, blob
/// outlines, pen wobble and where forests grow.
struct AtlasNoise {
    private let table: [CGFloat]

    init(seed: Int) {
        var rng = AtlasRandom(seed: seed)
        table = (0..<1024).map { _ in rng.next() }
    }

    /// The pen cycles through 40 fields so neighbouring strokes never wobble in step.
    static let fields = (1...40).map { AtlasNoise(seed: $0) }

    private func hash(_ a: Int, _ b: Int) -> CGFloat {
        let h = UInt32(truncatingIfNeeded: a) &* 73_856_093 ^ UInt32(truncatingIfNeeded: b) &* 19_349_663
        return table[Int(h % 1024)]
    }

    private func layer(_ x: CGFloat, _ y: CGFloat) -> CGFloat {
        let xi = Int(x.rounded(.down)), yi = Int(y.rounded(.down))
        func s(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }
        let u = s(x - CGFloat(xi)), v = s(y - CGFloat(yi))
        let top = hash(xi, yi) * (1 - u) + hash(xi + 1, yi) * u
        let bottom = hash(xi, yi + 1) * (1 - u) + hash(xi + 1, yi + 1) * u
        return top * (1 - v) + bottom * v
    }

    func callAsFunction(_ x: CGFloat, _ y: CGFloat) -> CGFloat {
        layer(x, y) * 0.57 + layer(x * 2.1 + 7, y * 2.1) * 0.29 + layer(x * 4.3, y * 4.3 + 3) * 0.14
    }
}

enum AtlasGeometry {
    /// Points no more than `step` apart along the polyline, keeping both ends.
    static func resample(_ p: [CGPoint], step: CGFloat) -> [CGPoint] {
        guard p.count > 1 else { return p }
        var out: [CGPoint] = []
        for (a, b) in zip(p, p.dropFirst()) {
            let n = max(1, Int((hypot(b.x - a.x, b.y - a.y) / step).rounded(.up)))
            for k in 0..<n {
                let t = CGFloat(k) / CGFloat(n)
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }
        out.append(p[p.count - 1])
        return out
    }

    /// A pen line's slow wander (noise at frequency 0.045, up to `amp` either way) plus a little
    /// tremor. A closed shape repeats its first point so the outline meets itself.
    static func jitter(_ p: [CGPoint], amp: CGFloat, closed: Bool, step: CGFloat = 3.5,
                       noise: AtlasNoise, rng: inout AtlasRandom) -> [CGPoint] {
        let ox = rng.next() * 50
        let points = resample(closed && !p.isEmpty ? p + [p[0]] : p, step: step)
        return points.map { q in
            let dx = amp * 2 * (noise(q.x * 0.045 + ox, q.y * 0.045) - 0.5) + amp * 0.3 * (rng.next() - 0.5)
            let dy = amp * 2 * (noise(q.x * 0.045 + ox + 40, q.y * 0.045 + 9) - 0.5) + amp * 0.3 * (rng.next() - 0.5)
            return CGPoint(x: q.x + dx, y: q.y + dy)
        }
    }

    /// An open stroke starts and stops a little off its points: each end moves by -0.6 to 1.6
    /// along the line, so some strokes overshoot and some fall short.
    static func loosenEnds(_ p: [CGPoint], rng: inout AtlasRandom) -> [CGPoint] {
        guard p.count > 1 else { return p }
        func extend(_ a: CGPoint, from b: CGPoint, _ l: CGFloat) -> CGPoint {
            let dx = a.x - b.x, dy = a.y - b.y, len = max(hypot(dx, dy), 0.0001)
            return CGPoint(x: a.x + dx / len * l, y: a.y + dy / len * l)
        }
        var q = p
        q[0] = extend(p[0], from: p[1], rng.next() * 2.2 - 0.6)
        q[q.count - 1] = extend(p[p.count - 1], from: p[p.count - 2], rng.next() * 2.2 - 0.6)
        return q
    }

    /// A ring drawn in one motion: it starts anywhere and overshoots a full turn by 0.25 to 0.6 rad.
    static func ring(_ c: CGPoint, radius r: CGFloat, rng: inout AtlasRandom) -> [CGPoint] {
        let a0 = rng.next() * 2 * .pi
        let sweep = 2 * .pi + 0.25 + rng.next() * 0.35
        let n = max(10, Int((r * 2.2).rounded()))
        return (0...n).map { i in
            let t = CGFloat(i) / CGFloat(n), a = a0 + sweep * t
            let rr = r * (1 + 0.05 * sin(a * 2 + a0) + 0.05 * (t - 0.5))
            return CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
        }
    }

    /// A lumpy closed outline around `c`; `k` is how far the radius strays (0.12 is 12%).
    static func blob(_ c: CGPoint, radius r: CGFloat, k: CGFloat = 0.12, noise: AtlasNoise) -> [CGPoint] {
        stride(from: CGFloat(0), to: 6.28, by: 0.3).map { a in
            let rr = r * (1 + k * 2 * (noise(cos(a) * 1.5 + c.x, sin(a) * 1.5) - 0.5))
            return CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
        }
    }

    /// The polyline moved sideways by `d` (positive is to the left of the direction of travel).
    static func offset(_ p: [CGPoint], by d: CGFloat) -> [CGPoint] {
        p.indices.map { i in
            let a = p[max(0, i - 1)], b = p[min(p.count - 1, i + 1)]
            let dx = b.x - a.x, dy = b.y - a.y, len = max(hypot(dx, dy), 0.0001)
            return CGPoint(x: p[i].x + dy / len * d, y: p[i].y - dx / len * d)
        }
    }

    /// The thick second pass of a pressed pen line: six random on/off pairs, 8 to 32 on and 5 to
    /// 21 off, so the line seems to swell where the nib was pushed.
    static func pressDashes(rng: inout AtlasRandom) -> [CGFloat] {
        (0..<6).flatMap { _ in [8 + rng.next() * 24, 5 + rng.next() * 16] }
    }

    /// A road dashed by hand: dashes 5 to 8 long with gaps of 2.5 to 4.5, measured along `p`.
    static func handDashes(_ p: [CGPoint], rng: inout AtlasRandom) -> [[CGPoint]] {
        var out: [[CGPoint]] = [], current: [CGPoint] = []
        var acc: CGFloat = 0, on = true, len = 5 + rng.next() * 3
        for (a, b) in zip(p, p.dropFirst()) {
            acc += hypot(b.x - a.x, b.y - a.y)
            if on { current.append(a) }
            if acc >= len {
                if on {
                    current.append(b)
                    out.append(current)
                    current = []
                }
                on.toggle()
                acc = 0
                len = on ? 5 + rng.next() * 3 : 2.5 + rng.next() * 2
            }
        }
        return out
    }

    /// The bowed road between two stops: a quadratic through a midpoint pushed 10 to one side,
    /// alternating sides so the road wanders. Excludes `a`, includes `b`.
    static func roadSegment(_ a: CGPoint, _ b: CGPoint, index i: Int) -> [CGPoint] {
        let m = CGPoint(x: (a.x + b.x) / 2 + (i % 2 == 1 ? 10 : -10), y: (a.y + b.y) / 2)
        func quad(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ t: CGFloat) -> CGFloat {
            let u = 1 - t
            return u * u * p0 + 2 * u * t * p1 + t * t * p2
        }
        return (1...8).map { k in
            let t = CGFloat(k) / 8
            return CGPoint(x: quad(a.x, m.x, b.x, t), y: quad(a.y, m.y, b.y, t))
        }
    }

    /// The whole road through `stops`, bowing between each pair.
    static func road(through stops: [CGPoint]) -> [CGPoint] {
        guard let first = stops.first else { return [] }
        return [first] + zip(stops, stops.dropFirst()).enumerated().flatMap { i, pair in roadSegment(pair.0, pair.1, index: i) }
    }

    // MARK: Shapes

    /// A keep with two towers, 14 wide and 13.5 tall at scale 1, base at y + 4.
    static let castle: [CGPoint] = [
        (-7, 4), (-7, -3), (-5, -3), (-5, -5), (-3.5, -5), (-3.5, -3), (-2, -3), (-2, -8), (-0.8, -8),
        (-0.8, -9.5), (0.8, -9.5), (0.8, -8), (2, -8), (2, -3), (3.5, -3), (3.5, -5), (5, -5), (5, -3),
        (7, -3), (7, 4),
    ].map { CGPoint(x: $0.0, y: $0.1) }

    /// The crown pressed into the wax seal, 12 wide.
    static let sealCrown: [CGPoint] = [(-6, 3), (-6, -4), (-3, -1), (0, -6.5), (3, -1), (6, -4), (6, 3)]
        .map { CGPoint(x: $0.0, y: $0.1) }

    static func place(_ shape: [CGPoint], at c: CGPoint, scale: CGFloat = 1) -> [CGPoint] {
        shape.map { CGPoint(x: c.x + $0.x * scale, y: c.y + $0.y * scale) }
    }

    /// A mountain standing on (x, y), `h` tall: steep on the left, a shoulder on the right.
    static func mountain(x: CGFloat, y: CGFloat, height h: CGFloat, peakShift: CGFloat = 0) -> [CGPoint] {
        let w = h * 0.72
        return [CGPoint(x: x - w, y: y), CGPoint(x: x - w * 0.45, y: y - h * 0.55), CGPoint(x: x + peakShift, y: y - h),
                CGPoint(x: x + w * 0.35, y: y - h * 0.6), CGPoint(x: x + w, y: y)]
    }

    /// The shaded right flank of `mountain`, which takes the mountain wash.
    static func mountainFlank(_ outline: [CGPoint]) -> [CGPoint] {
        let base = outline[4], left = outline[0]
        return [outline[2], outline[3], base, CGPoint(x: left.x + (base.x - left.x) * 0.55, y: base.y)]
    }

    /// A low hill, 18 wide and 7 tall, sitting on (x, y).
    static func hill(x: CGFloat, y: CGFloat) -> [CGPoint] {
        [CGPoint(x: x - 9, y: y), CGPoint(x: x - 4.5, y: y - 5.5), CGPoint(x: x, y: y - 7),
         CGPoint(x: x + 4.5, y: y - 5.5), CGPoint(x: x + 9, y: y)]
    }
}
