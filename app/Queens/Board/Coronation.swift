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

// MARK: Inhabitants

/// The kingdom comes alive once the road reaches the last crown: a cottage pops up and puffs
/// smoke, a sheep hops along a field, two birds cross the board, and a small dragon loops the
/// board and lands beside the last queen. On a finished board the cottage, sheep and dragon stay.
struct Inhabitants: View {
    let puzzle: Puzzle
    let trigger: Int
    let shown: Bool
    let animate: Bool
    let inset: CGFloat
    let side: CGFloat

    var body: some View {
        let n = puzzle.size
        let cell = (side - inset * 2) / CGFloat(n)
        // Room around the board for the birds and the dragon to fly in from.
        let margin = cell * 1.5
        let start = SolveTiming.critters(rows: n)
        let end = SolveTiming.crittersEnd(rows: n)
        Color.clear
            .keyframeAnimator(initialValue: end, trigger: trigger) { _, now in
                Canvas { ctx, _ in
                    guard shown else { return }
                    var ctx = ctx
                    ctx.translateBy(x: margin, y: margin)
                    Village(puzzle: puzzle, inset: inset, side: side, margin: margin)
                        .draw(in: ctx, at: (animate ? now : end) - start)
                }
            } keyframes: { _ in
                MoveKeyframe(0.0)
                LinearKeyframe(end, duration: end)
            }
            .frame(width: side + margin * 2, height: side + margin * 2)
            // Lay out as the board's square and overflow on every side.
            .frame(width: side, height: side)
            .allowsHitTesting(false)
    }
}

/// Where everyone lives on this puzzle, and how they move. Times are seconds after `critters`.
private struct Village {
    let n: Int
    let cell: CGFloat
    let inset: CGFloat
    let side: CGFloat
    let margin: CGFloat
    let queen: Int
    let lair: Int
    let sheepFrom: Int
    let sheepTo: Int
    let cottage: Int

    init(puzzle: Puzzle, inset: CGFloat, side: CGFloat, margin: CGFloat) {
        let n = puzzle.size
        self.n = n
        self.inset = inset
        self.side = side
        self.margin = margin
        cell = (side - inset * 2) / CGFloat(n)
        let crowns = puzzle.solutionCells
        let lastCol = puzzle.solution[n - 1]
        let queen = (n - 1) * n + lastCol, lair = lastCol > 0 ? queen - 1 : queen + 1
        self.queen = queen
        self.lair = lair
        let near: Set<Int> = [queen - 1, queen + 1, queen - n, lair - n]
        func free(_ i: Int) -> Bool { !crowns.contains(i) && !near.contains(i) && i != lair }
        let seed = puzzle.solution[0] * 7 + puzzle.solution[1]
        // The sheep walks between two neighbouring cells of one kingdom, away from the edges.
        let fields = (0..<n * n).filter { i in
            let r = i / n, c = i % n
            return r >= 2 && r <= n - 3 && c + 1 < n && free(i) && free(i + 1) && puzzle.regionOf[i] == puzzle.regionOf[i + 1]
        }
        let field = fields.isEmpty ? (0..<n * n - 1).first { free($0) && free($0 + 1) && ($0 + 1) % n != 0 } ?? 0 : fields[seed % fields.count]
        (sheepFrom, sheepTo) = seed % 2 == 0 ? (field, field + 1) : (field + 1, field)
        // The cottage sits in the top half, so its smoke has room to rise, in another kingdom from the sheep.
        // The roof stands taller than its cell, so not under a crown, and not on the right edge where the smoke drifts.
        let plots = (n..<(n / 2) * n).filter {
            free($0) && !crowns.contains($0 - n) && $0 % n < n - 1 && abs($0 - field) > 1 && puzzle.regionOf[$0] != puzzle.regionOf[field]
        }
        cottage = plots.isEmpty ? (0..<n * n).first { free($0) && abs($0 - field) > 1 } ?? 0 : plots[(seed * 3) % plots.count]
    }

    private func centre(_ i: Int) -> CGPoint {
        CGPoint(x: inset + (CGFloat(i % n) + 0.5) * cell, y: inset + (CGFloat(i / n) + 0.5) * cell)
    }

    /// Outline width in points, whatever the drawing scale.
    private func outline(_ scale: CGFloat) -> CGFloat { 1.6 / max(scale, 0.01) }

    func draw(in ctx: GraphicsContext, at t: Double) {
        guard t > 0 else { return }
        drawCottage(ctx, t)
        drawSheep(ctx, t)
        drawDragon(ctx, t)
        drawBirds(ctx, t)
    }

    // MARK: Cottage

    private func drawCottage(_ ctx: GraphicsContext, _ t: Double) {
        let s = cell * 1.25 * backOut(clamp(t / 0.35))
        guard s > 0.5 else { return }
        let base = centre(cottage)
        var c = ctx
        c.translateBy(x: base.x, y: base.y + cell * 0.5)
        c.scaleBy(x: s, y: s)
        c.translateBy(x: -0.5, y: -1)
        let ow = outline(s)
        c.blob(Path(CGRect(x: 0.6, y: 0.2, width: 0.11, height: 0.24)), Theme.roof, ow)
        c.blob(Path(roundedRect: CGRect(x: 0.24, y: 0.48, width: 0.52, height: 0.38), cornerRadius: 0.04), Theme.cream, ow)
        var roof = Path()
        roof.move(to: pt(0.14, 0.53)); roof.addLine(to: pt(0.5, 0.2)); roof.addLine(to: pt(0.86, 0.53)); roof.closeSubpath()
        c.blob(roof, Theme.roof, ow)
        c.blob(Path(roundedRect: CGRect(x: 0.45, y: 0.66, width: 0.13, height: 0.2), cornerRadii: .init(topLeading: 0.06, topTrailing: 0.06)), Theme.door, ow)
        c.blob(Path(roundedRect: CGRect(x: 0.29, y: 0.6, width: 0.11, height: 0.1), cornerRadius: 0.02), Theme.gold, ow)
        // Smoke puffs drift up and to one side, then the chimney goes quiet.
        for k in 0..<5 {
            let a = (t - 0.35 - Double(k) * 0.4) / 1.5
            guard a > 0 && a < 1 else { continue }
            var puff = c
            puff.opacity = 1 - a
            let r = 0.06 + 0.09 * a
            puff.blob(ellipse(0.66 + 0.3 * a + 0.05 * sin(a * 7), 0.14 - 0.85 * a, r * 2, r * 1.8), Theme.paper, ow)
        }
    }

    // MARK: Sheep

    private func drawSheep(_ ctx: GraphicsContext, _ t: Double) {
        let s = cell * 1.1 * backOut(clamp((t - 0.2) / 0.35))
        guard s > 0.5 else { return }
        let w = clamp((t - SolveTiming.sheepSets) / SolveTiming.sheepWalk)
        let a = centre(sheepFrom), b = centre(sheepTo)
        let hop = abs(sin(w * .pi * 3)) * cell * 0.16
        let flip: CGFloat = b.x > a.x ? 1 : -1
        var c = ctx
        c.translateBy(x: a.x + (b.x - a.x) * w, y: a.y + cell * 0.26 - hop)
        c.scaleBy(x: s * flip, y: s)
        c.translateBy(x: 0, y: -0.3)
        let ow = outline(s)
        let swing = w > 0 && w < 1 ? sin(w * .pi * 6) * 0.05 : 0
        for (x, d) in [(-0.17, swing), (-0.07, -swing), (0.07, swing), (0.17, -swing)] {
            var leg = Path()
            leg.move(to: pt(x, 0.1)); leg.addLine(to: pt(x + d, 0.3))
            c.stroke(leg, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 0.07, lineCap: .round))
        }
        let fleece = [(-0.18, 0.0), (-0.06, -0.1), (0.08, -0.08), (0.15, 0.03), (0.03, 0.09), (-0.12, 0.09)].map { ellipse($0.0, $0.1, 0.26, 0.26) }
        c.merged(fleece, Theme.paper, ow)
        c.blob(ellipse(0.2, -0.07, 0.12, 0.07).applying(CGAffineTransform(rotationAngle: 0.5)), Theme.ink, ow)
        c.blob(ellipse(0.28, -0.01, 0.17, 0.2), Theme.ink, ow)
        c.blob(ellipse(0.26, -0.12, 0.1, 0.08), Theme.paper, ow)
        c.fill(ellipse(0.31, -0.03, 0.045, 0.045), with: .color(Theme.paper))
        c.fill(ellipse(0.33, 0.04, 0.05, 0.03), with: .color(Theme.blush))
    }

    // MARK: Birds

    private func drawBirds(_ ctx: GraphicsContext, _ t: Double) {
        for k in 0..<2 {
            let q = (t - 0.3 - Double(k) * 0.25) / 2.4
            guard q > 0 && q < 1 else { continue }
            let x = -margin + (side + margin * 2) * q
            let y = side * 0.18 + CGFloat(k) * cell * 0.7 + sin(q * .pi * 3 + Double(k)) * cell * 0.2
            let s = cell * 0.85
            var c = ctx
            c.translateBy(x: x, y: y)
            c.scaleBy(x: s, y: s)
            let ow = outline(s)
            let flap = sin(t * 22 + Double(k) * 2)
            c.blob(ellipse(0, 0, 0.42, 0.3), Theme.bird, ow)
            var beak = Path()
            beak.move(to: pt(0.2, -0.06)); beak.addLine(to: pt(0.32, -0.01)); beak.addLine(to: pt(0.19, 0.03)); beak.closeSubpath()
            c.blob(beak, Theme.gold, ow)
            c.fill(ellipse(0.11, -0.05, 0.06, 0.06), with: .color(Theme.ink))
            var wing = Path()
            wing.move(to: pt(-0.12, -0.04))
            wing.addQuadCurve(to: pt(-0.02, -0.04 - 0.3 * flap), control: pt(-0.16, -0.04 - 0.3 * flap))
            wing.addQuadCurve(to: pt(0.08, -0.04), control: pt(0.08, -0.04 - 0.15 * flap))
            wing.closeSubpath()
            c.blob(wing, Theme.bird, ow)
        }
    }

    // MARK: Dragon

    /// Off the top right, once round the board, then down beside the last crown.
    private func flightPath(_ u: Double) -> CGPoint {
        let r = side * 0.28
        let mid = CGPoint(x: side / 2, y: side * 0.45)
        let top = CGPoint(x: mid.x, y: mid.y - r)
        if u < 0.5 {
            let q = u / 0.5
            let from = CGPoint(x: side + margin, y: top.y - cell * 1.2)
            return quad(from, CGPoint(x: side * 0.85, y: top.y - cell * 0.1), top, q)
        }
        if u < 1.8 {
            let a = -Double.pi / 2 - 2 * .pi * (u - 0.5) / 1.3
            return CGPoint(x: mid.x + r * cos(a), y: mid.y + r * sin(a))
        }
        let q = 1 - pow(1 - clamp((u - 1.8) / 0.6), 2)
        let land = landing
        let c1 = CGPoint(x: top.x - r * 0.9, y: top.y)
        let c2 = CGPoint(x: land.x, y: land.y - cell * 1.6)
        let m = 1 - q
        return CGPoint(
            x: m * m * m * top.x + 3 * m * m * q * c1.x + 3 * m * q * q * c2.x + q * q * q * land.x,
            y: m * m * m * top.y + 3 * m * m * q * c1.y + 3 * m * q * q * c2.y + q * q * q * land.y)
    }

    private var landing: CGPoint { CGPoint(x: centre(lair).x, y: centre(lair).y + cell * 0.04) }

    private func drawDragon(_ ctx: GraphicsContext, _ t: Double) {
        let u = t - SolveTiming.dragonSets
        guard u > 0 else { return }
        var c = ctx
        if u < SolveTiming.dragonFlight {
            let p = flightPath(u), ahead = flightPath(u + 0.02)
            let vx = ahead.x - p.x, vy = ahead.y - p.y
            let flip: CGFloat = vx < 0 ? -1 : 1
            let tilt = max(min(atan2(vy, abs(vx)), 0.6), -0.6) * 0.7
            let s = cell * 1.5
            c.translateBy(x: p.x, y: p.y)
            c.rotate(by: .radians(flip * tilt))
            c.scaleBy(x: s * flip, y: s)
            dragon(c, flap: sin(u * 16), flying: true, ow: outline(s))
        } else {
            // Lands with a squash, sits facing the queen, and sends her a heart.
            let q = clamp((u - SolveTiming.dragonFlight) / 0.3)
            let squash = sin(q * .pi) * 0.16
            let flip: CGFloat = centre(queen).x > centre(lair).x ? 1 : -1
            let s = cell * 1.25
            let feet = CGPoint(x: centre(lair).x, y: centre(lair).y + cell * 0.38)
            c.translateBy(x: feet.x, y: feet.y)
            c.scaleBy(x: s * flip * (1 + squash * 0.7), y: s * (1 - squash))
            c.translateBy(x: 0, y: -0.38)
            dragon(c, flap: 0.2, flying: false, ow: outline(s))
            let h = (u - SolveTiming.dragonFlight - 0.3) / 1.0
            if h > 0 && h < 1 {
                let from = centre(lair), to = centre(queen)
                var heart = ctx
                heart.opacity = h < 0.7 ? 1 : (1 - h) / 0.3
                let size = cell * 0.5 * backOut(clamp(h / 0.25))
                heart.translateBy(x: (from.x + to.x) / 2, y: from.y - cell * 0.35 - cell * 0.6 * h)
                heart.scaleBy(x: size, y: size)
                heart.blob(heartPath, Theme.heart, outline(size))
            }
        }
    }

    /// A chubby dragon facing right, centred on its body, with its feet at y 0.38.
    private func dragon(_ c: GraphicsContext, flap: Double, flying: Bool, ow: CGFloat) {
        var tail = Path()
        tail.move(to: pt(-0.18, 0.22))
        tail.addQuadCurve(to: pt(-0.47, -0.06), control: pt(-0.52, 0.3))
        c.stroke(tail, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 0.12 + ow * 2, lineCap: .round))
        c.stroke(tail, with: .color(Theme.dragon), style: StrokeStyle(lineWidth: 0.12, lineCap: .round))
        var tip = Path()
        tip.move(to: pt(-0.47, -0.19)); tip.addLine(to: pt(-0.38, -0.04)); tip.addLine(to: pt(-0.55, -0.02)); tip.closeSubpath()
        c.blob(tip, Theme.gold, ow)
        if flying { c.blob(wing(flap * 0.8).applying(CGAffineTransform(translationX: 0.08, y: -0.02)), Theme.dragonDeep, ow) }
        for (x, y) in [(-0.27, -0.03), (-0.17, -0.11), (-0.05, -0.15)] as [(CGFloat, CGFloat)] {
            let d = hypot(x + 0.02, y - 0.1), ux = (x + 0.02) / d, uy = (y - 0.1) / d
            var spike = Path()
            spike.move(to: pt(x - uy * 0.05, y + ux * 0.05))
            spike.addLine(to: pt(x + ux * 0.1, y + uy * 0.1))
            spike.addLine(to: pt(x + uy * 0.05, y - ux * 0.05))
            spike.closeSubpath()
            c.blob(spike, Theme.gold, ow)
        }
        c.blob(ellipse(-0.02, 0.1, 0.58, 0.48), Theme.dragon, ow)
        c.fill(ellipse(0.1, 0.14, 0.24, 0.3), with: .color(Theme.cream))
        if flying {
            c.blob(ellipse(0.04, 0.33, 0.12, 0.07), Theme.dragon, ow)
        } else {
            c.blob(ellipse(-0.14, 0.34, 0.15, 0.09), Theme.dragon, ow)
            c.blob(ellipse(0.1, 0.34, 0.15, 0.09), Theme.dragon, ow)
        }
        c.blob(wing(flying ? flap : 0.25), Theme.dragonDeep, ow)
        for (x, y) in [(0.07, -0.36), (0.2, -0.4)] as [(CGFloat, CGFloat)] {
            var horn = Path()
            horn.move(to: pt(x - 0.04, y + 0.06)); horn.addLine(to: pt(x - 0.03, y - 0.06)); horn.addLine(to: pt(x + 0.05, y + 0.05)); horn.closeSubpath()
            c.blob(horn, Theme.gold, ow)
        }
        c.merged([ellipse(0.15, -0.2, 0.4, 0.38), ellipse(0.35, -0.14, 0.24, 0.18)], Theme.dragon, ow)
        c.fill(ellipse(0.42, -0.17, 0.03, 0.03), with: .color(Theme.ink))
        c.fill(ellipse(0.27, -0.1, 0.09, 0.05), with: .color(Theme.blush))
        if flying {
            c.fill(ellipse(0.21, -0.24, 0.12, 0.13), with: .color(Theme.paper))
            c.fill(ellipse(0.23, -0.24, 0.07, 0.08), with: .color(Theme.ink))
            c.fill(ellipse(0.24, -0.26, 0.025, 0.025), with: .color(Theme.paper))
        } else {
            var eye = Path()
            eye.move(to: pt(0.16, -0.22)); eye.addQuadCurve(to: pt(0.26, -0.22), control: pt(0.21, -0.29))
            c.stroke(eye, with: .color(Theme.ink), style: StrokeStyle(lineWidth: ow * 1.4, lineCap: .round))
        }
        var smile = Path()
        smile.move(to: pt(0.33, -0.08)); smile.addQuadCurve(to: pt(0.42, -0.09), control: pt(0.38, -0.04))
        c.stroke(smile, with: .color(Theme.ink), style: StrokeStyle(lineWidth: ow, lineCap: .round))
    }

    /// A bat wing hinged at the shoulder: 1 is fully up, below 0 is the downstroke.
    private func wing(_ f: Double) -> Path {
        var w = Path()
        w.move(to: pt(0.02, -0.02))
        w.addLine(to: pt(-0.08, -0.1 - 0.46 * f))
        w.addQuadCurve(to: pt(-0.2, -0.06 - 0.28 * f), control: pt(-0.1, -0.04 - 0.26 * f))
        w.addQuadCurve(to: pt(-0.24, 0.02), control: pt(-0.18, -0.02 - 0.08 * f))
        w.closeSubpath()
        return w
    }

    private var heartPath: Path {
        var h = Path()
        h.move(to: pt(0, 0.35))
        h.addCurve(to: pt(-0.5, -0.1), control1: pt(-0.2, 0.2), control2: pt(-0.5, 0.1))
        h.addCurve(to: pt(0, -0.2), control1: pt(-0.5, -0.45), control2: pt(-0.05, -0.45))
        h.addCurve(to: pt(0.5, -0.1), control1: pt(0.05, -0.45), control2: pt(0.5, -0.45))
        h.addCurve(to: pt(0, 0.35), control1: pt(0.5, 0.1), control2: pt(0.2, 0.2))
        return h
    }
}

private extension GraphicsContext {
    /// A cartoon shape: flat fill, ink outline.
    func blob(_ p: Path, _ color: Color, _ ow: CGFloat) {
        fill(p, with: .color(color))
        stroke(p, with: .color(Theme.ink), style: StrokeStyle(lineWidth: ow, lineCap: .round, lineJoin: .round))
    }

    /// Overlapping shapes filled as one, outlined only around the outside.
    func merged(_ parts: [Path], _ color: Color, _ ow: CGFloat) {
        for p in parts { stroke(p, with: .color(Theme.ink), lineWidth: ow * 2) }
        for p in parts { fill(p, with: .color(color)) }
    }
}

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
}

private func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ q: Double) -> CGPoint {
    let m = 1 - q
    return CGPoint(x: m * m * a.x + 2 * m * q * c.x + q * q * b.x, y: m * m * a.y + 2 * m * q * c.y + q * q * b.y)
}

private func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }

private func backOut(_ x: Double) -> Double {
    let k = 1.70158, y = x - 1
    return 1 + (k + 1) * y * y * y + k * y * y
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
