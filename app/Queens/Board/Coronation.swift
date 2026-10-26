import SwiftUI

// The coronation: what happens on the board after the crowns are gilded.
// Every delay comes from SolveTiming so the haptic pattern lands with it.

private func crownCentre(_ puzzle: Puzzle, row: Int, inset: CGFloat, cell: CGFloat) -> CGPoint {
    CGPoint(x: inset + (CGFloat(puzzle.solution[row]) + 0.5) * cell, y: inset + (CGFloat(row) + 0.5) * cell)
}

private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

// MARK: Royal road

/// A dotted route drawn crown to crown, top row to bottom, like a journey marked on a map.
struct RoyalRoad: View {
    let puzzle: Puzzle
    let trigger: Int
    let inset: CGFloat
    let cell: CGFloat

    var body: some View {
        let n = puzzle.size
        let points = (0..<n).map { crownCentre(puzzle, row: $0, inset: inset, cell: cell) }
        // t counts legs travelled: 0 at the top crown, n - 1 at the last, n once faded. Below 0 nothing shows.
        Color.clear
            .keyframeAnimator(initialValue: -1.0, trigger: trigger) { _, t in
                ZStack(alignment: .topLeading) {
                    if t >= 0 && t < Double(n) {
                        let travelled = min(t, Double(n - 1))
                        RoadPath(points: points, upTo: travelled)
                            .stroke(Theme.goldDeep, style: StrokeStyle(lineWidth: max(2.4, cell * 0.06), lineCap: .round, dash: [0.1, max(6, cell * 0.16)]))
                        if t < Double(n - 1) {
                            let head = RoadPath.point(points, at: travelled)
                            Sparkle()
                                .fill(Theme.gold)
                                .overlay(Sparkle().stroke(Theme.goldDeep, lineWidth: 0.8))
                                .frame(width: cell * 0.34, height: cell * 0.34)
                                .rotationEffect(.radians(t * 2))
                                .position(head)
                        }
                    }
                }
                .opacity(t > Double(n - 1) ? Double(n) - t : 1)
            } keyframes: { _ in
                LinearKeyframe(-1.0, duration: SolveTiming.roadStart(rows: n))
                MoveKeyframe(0.0)
                LinearKeyframe(Double(n - 1), duration: Double(n - 1) * SolveTiming.roadLeg)
                LinearKeyframe(Double(n - 1), duration: SolveTiming.roadLinger)
                LinearKeyframe(Double(n), duration: 0.5)
            }
            .allowsHitTesting(false)
    }
}

/// Gentle alternating curves between crowns, partly drawn up to `upTo` legs.
private struct RoadPath: Shape {
    let points: [CGPoint]
    let upTo: Double

    static func control(_ points: [CGPoint], leg k: Int) -> CGPoint {
        let a = points[k], b = points[k + 1]
        let mid = lerp(a, b, 0.5)
        let bend: CGFloat = k.isMultiple(of: 2) ? 0.28 : -0.28
        return CGPoint(x: mid.x - (b.y - a.y) * bend, y: mid.y + (b.x - a.x) * bend)
    }

    static func point(_ points: [CGPoint], at t: Double) -> CGPoint {
        let k = min(Int(t), points.count - 2)
        let f = CGFloat(t - Double(k))
        let c = control(points, leg: k)
        return lerp(lerp(points[k], c, f), lerp(c, points[k + 1], f), f)
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        guard points.count > 1 else { return p }
        p.move(to: points[0])
        let full = Int(upTo)
        for k in 0..<min(full, points.count - 1) {
            p.addQuadCurve(to: points[k + 1], control: Self.control(points, leg: k))
        }
        let f = CGFloat(upTo - Double(full))
        if full < points.count - 1, f > 0 {
            // de Casteljau split: the first f of the leg is itself a quad curve.
            let c = Self.control(points, leg: full)
            let q0 = lerp(points[full], c, f)
            p.addQuadCurve(to: lerp(q0, lerp(c, points[full + 1], f), f), control: q0)
        }
        return p
    }
}

// MARK: Kingdom ripple

/// As the road reaches each crown, a ring of light washes out through that crown's kingdom.
struct KingdomRipple: View {
    let puzzle: Puzzle
    let trigger: Int
    let inset: CGFloat
    let side: CGFloat

    var body: some View {
        let n = puzzle.size
        let cell = (side - inset * 2) / CGFloat(n)
        ZStack {
            ForEach(0..<n, id: \.self) { row in
                let region = puzzle.regionOf[row * n + puzzle.solution[row]]
                let centre = crownCentre(puzzle, row: row, inset: inset, cell: cell)
                let reach = farthestCell(region: region, from: centre, cell: cell) + cell * 0.6
                Color.clear
                    .keyframeAnimator(initialValue: 1.0, trigger: trigger) { _, p in
                        Canvas { ctx, size in
                            guard p < 1 else { return }
                            ctx.clip(to: RegionShape(puzzle: puzzle, region: region, inset: inset).path(in: CGRect(origin: .zero, size: size)))
                            ctx.addFilter(.blur(radius: cell * 0.12))
                            let r = cell * 0.3 + reach * p
                            let ring = Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
                            ctx.stroke(ring, with: .color(.white.opacity(0.75 * (1 - p))), lineWidth: cell * (0.55 - 0.3 * p))
                            ctx.fill(ring, with: .color(Theme.region(region).opacity(0.35 * (1 - p))))
                        }
                    } keyframes: { _ in
                        LinearKeyframe(1.0, duration: SolveTiming.roadReach(row, rows: n))
                        MoveKeyframe(0.0)
                        CubicKeyframe(1.0, duration: 0.8)
                    }
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }

    private func farthestCell(region: Int, from c: CGPoint, cell: CGFloat) -> CGFloat {
        let n = puzzle.size
        var best: CGFloat = 0
        for i in 0..<n * n where puzzle.regionOf[i] == region {
            let x = inset + (CGFloat(i % n) + 0.5) * cell, y = inset + (CGFloat(i / n) + 0.5) * cell
            best = max(best, hypot(x - c.x, y - c.y))
        }
        return best
    }
}

// MARK: Lanterns

/// Small gold lanterns drift up from every crown and out over the title, swaying as they rise.
struct Lanterns: View {
    let puzzle: Puzzle
    let trigger: Int
    let inset: CGFloat
    let side: CGFloat

    /// Room above the board the lanterns can rise into.
    private var headroom: CGFloat { side * 0.4 }

    var body: some View {
        let n = puzzle.size
        let cell = (side - inset * 2) / CGFloat(n)
        Color.clear
            .keyframeAnimator(initialValue: 1.0, trigger: trigger) { _, p in
                Canvas { ctx, _ in
                    guard p < 1 else { return }
                    for row in 0..<n {
                        let c = crownCentre(puzzle, row: row, inset: inset, cell: cell)
                        for k in 0..<3 {
                            let seed = Double(row * 3 + k)
                            let start = hash(seed) * 0.35
                            let q = min(max((p - start) / 0.6, 0), 1)
                            guard q > 0 && q < 1 else { continue }
                            let rise = cell * 1.6 + (side * 0.25 + headroom * 0.6) * hash(seed + 7)
                            let x = c.x + sin(q * .pi * 2.2 + seed) * cell * 0.22 + (hash(seed + 3) - 0.5) * cell * 1.4 * q
                            let y = c.y + headroom - rise * easeOut(q)
                            let r = cell * (0.07 + 0.04 * hash(seed + 11))
                            let alpha = sin(.pi * q)
                            let halo = CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)
                            ctx.fill(Path(ellipseIn: halo), with: .radialGradient(
                                Gradient(colors: [Theme.gold.opacity(0.45 * alpha), Theme.gold.opacity(0)]),
                                center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 3))
                            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Theme.gold.opacity(alpha)))
                            ctx.fill(Path(ellipseIn: CGRect(x: x - r * 0.4, y: y - r * 0.4, width: r * 0.8, height: r * 0.8)), with: .color(Theme.paper.opacity(alpha)))
                        }
                    }
                }
            } keyframes: { _ in
                LinearKeyframe(1.0, duration: SolveTiming.lanterns(rows: n))
                MoveKeyframe(0.0)
                LinearKeyframe(1.0, duration: 3.4)
            }
            .frame(width: side, height: side + headroom)
            // Lay out as the board's square and overflow upward, so the board frame keeps its size.
            .frame(width: side, height: side, alignment: .bottom)
            .allowsHitTesting(false)
    }

    private func hash(_ x: Double) -> Double {
        let s = sin(x * 127.1 + 311.7) * 43758.5453
        return s - floor(s)
    }

    private func easeOut(_ q: Double) -> Double { 1 - (1 - q) * (1 - q) }
}

// MARK: Glints

/// On a gilded board, now and then a crown catches the light.
struct CrownGlints: View {
    let puzzle: Puzzle
    let inset: CGFloat
    let side: CGFloat
    /// Hold off until the coronation has finished.
    let delay: Double
    @State private var start = Date()

    private let period = 1.7

    var body: some View {
        let n = puzzle.size
        let cell = (side - inset * 2) / CGFloat(n)
        TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
            let t = ctx.date.timeIntervalSince(start) - delay
            let beat = Int(max(t, 0) / period)
            let f = t / period - Double(beat)
            let s = t > 0 && f < 0.45 ? sin(f / 0.45 * .pi) : 0
            // Hop around the board rather than marching down it.
            let row = (beat * 5 + 2) % n
            let c = crownCentre(puzzle, row: row, inset: inset, cell: cell)
            Sparkle()
                .fill(Theme.paper)
                .overlay(Sparkle().stroke(Theme.gold, lineWidth: 0.8))
                .frame(width: cell * 0.3, height: cell * 0.3)
                .scaleEffect(s)
                .rotationEffect(.degrees(f * 120))
                .position(x: c.x + cell * 0.2, y: c.y - cell * 0.2)
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }
}

// MARK: Ink drop

/// A ring of ink spreads from a crown as it lands, like a drop on wet paper.
struct InkDrop: View {
    let trigger: Int
    let cell: CGFloat

    var body: some View {
        Color.clear
            .keyframeAnimator(initialValue: 1.0, trigger: trigger) { _, p in
                Circle()
                    .stroke(Theme.ink.opacity(0.4 * (1 - p)), lineWidth: 0.6 + 2 * (1 - p))
                    .frame(width: cell * (0.55 + 0.75 * p), height: cell * (0.55 + 0.75 * p))
                    .opacity(p >= 1 ? 0 : 1)
            } keyframes: { _ in
                MoveKeyframe(0.0)
                CubicKeyframe(1.0, duration: 0.5)
            }
            .frame(width: cell, height: cell)
            .allowsHitTesting(false)
    }
}
