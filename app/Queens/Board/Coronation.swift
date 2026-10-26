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

// MARK: Lands

/// When the map and walls reach each cell on a solve: the road arrives at the kingdom's crown,
/// then they spread out through the kingdom from there.
struct Lands {
    /// Seconds after solveTrigger, per cell.
    let time: [Double]
    /// Everything has been drawn by this time.
    let end: Double

    init(puzzle: Puzzle) {
        let n = puzzle.size
        var crownRow = [Int: Int]()
        for r in 0..<n { crownRow[puzzle.regionOf[r * n + puzzle.solution[r]]] = r }
        time = (0..<n * n).map { i in
            let row = crownRow[puzzle.regionOf[i]] ?? 0
            let d = hypot(Double(i % n - puzzle.solution[row]), Double(i / n - row))
            return SolveTiming.roadReach(row, rows: n) + d * SolveTiming.landSpread
        }
        end = max(time.max() ?? 0, SolveTiming.outerWall(rows: n) + 0.12 + Double(n) * 0.02) + SolveTiming.landDraw + 0.3
    }
}

private func hash(_ x: Double) -> Double {
    let s = sin(x * 127.1 + 311.7) * 43758.5453
    return s - floor(s)
}

private func backOut(_ x: Double) -> Double {
    let c = 1.70158, y = x - 1
    return 1 + (c + 1) * y * y * y + c * y * y
}

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

// MARK: Map land

/// Map symbols, drawn in a unit cell to be stroked.
private enum Glyph {
    case tree, pine, hills, peak, field, cottage, reeds, waves

    var path: Path {
        var p = Path()
        switch self {
        case .tree:
            p.addEllipse(in: CGRect(x: 0.32, y: 0.24, width: 0.36, height: 0.34))
            p.move(to: pt(0.5, 0.58)); p.addLine(to: pt(0.5, 0.78))
        case .pine:
            p.move(to: pt(0.5, 0.2)); p.addLine(to: pt(0.68, 0.66)); p.addLine(to: pt(0.32, 0.66)); p.closeSubpath()
            p.move(to: pt(0.5, 0.66)); p.addLine(to: pt(0.5, 0.8))
        case .hills:
            p.move(to: pt(0.16, 0.7)); p.addQuadCurve(to: pt(0.56, 0.7), control: pt(0.36, 0.3))
            p.move(to: pt(0.48, 0.6)); p.addQuadCurve(to: pt(0.84, 0.7), control: pt(0.68, 0.36))
        case .peak:
            p.move(to: pt(0.18, 0.76)); p.addLine(to: pt(0.5, 0.22)); p.addLine(to: pt(0.82, 0.76))
            p.move(to: pt(0.38, 0.42)); p.addLine(to: pt(0.44, 0.48)); p.addLine(to: pt(0.5, 0.42))
            p.addLine(to: pt(0.56, 0.48)); p.addLine(to: pt(0.62, 0.42))
        case .field:
            p.addRect(CGRect(x: 0.24, y: 0.3, width: 0.52, height: 0.42))
            for k in 1...3 {
                let y = 0.3 + 0.42 * CGFloat(k) / 4
                p.move(to: pt(0.24, y)); p.addLine(to: pt(0.76, y))
            }
        case .cottage:
            p.move(to: pt(0.3, 0.76)); p.addLine(to: pt(0.3, 0.5)); p.addLine(to: pt(0.5, 0.3))
            p.addLine(to: pt(0.7, 0.5)); p.addLine(to: pt(0.7, 0.76)); p.closeSubpath()
            p.move(to: pt(0.46, 0.76)); p.addLine(to: pt(0.46, 0.62)); p.addLine(to: pt(0.54, 0.62)); p.addLine(to: pt(0.54, 0.76))
        case .reeds:
            p.move(to: pt(0.5, 0.74)); p.addQuadCurve(to: pt(0.34, 0.4), control: pt(0.46, 0.5))
            p.move(to: pt(0.5, 0.74)); p.addLine(to: pt(0.5, 0.3))
            p.move(to: pt(0.5, 0.74)); p.addQuadCurve(to: pt(0.66, 0.4), control: pt(0.54, 0.5))
            p.move(to: pt(0.28, 0.78)); p.addLine(to: pt(0.72, 0.78))
        case .waves:
            for y: CGFloat in [0.42, 0.6] {
                p.move(to: pt(0.22, y))
                p.addQuadCurve(to: pt(0.5, y), control: pt(0.36, y - 0.1))
                p.addQuadCurve(to: pt(0.78, y), control: pt(0.64, y + 0.1))
            }
        }
        return p
    }

    /// One land per kingdom: forest, highland, farmland, marsh. Repeats weight the mix.
    static let terrains: [[Glyph]] = [
        [.tree, .tree, .pine, .pine, .pine],
        [.peak, .peak, .hills, .hills, .pine],
        [.field, .field, .field, .cottage, .tree],
        [.reeds, .reeds, .waves, .waves, .tree],
    ]
}

/// A squat tower with three merlons for a crown to sit on.
private let keepPath: Path = {
    var p = Path()
    p.move(to: pt(0.28, 0.92))
    for (x, y) in [(0.28, 0.63), (0.36, 0.63), (0.36, 0.69), (0.46, 0.69), (0.46, 0.63), (0.54, 0.63),
                   (0.54, 0.69), (0.64, 0.69), (0.64, 0.63), (0.72, 0.63), (0.72, 0.92)] as [(CGFloat, CGFloat)] {
        p.addLine(to: pt(x, y))
    }
    p.closeSubpath()
    return p
}()

/// On a solved board the cartographer finishes the map: every cell without a crown is drawn in as
/// land, one kind per kingdom, and each crown gets a keep. Spreads out from each crown as the road
/// reaches it; the crosses fade as the land replaces them.
struct MapLand: View {
    let puzzle: Puzzle
    let trigger: Int
    let shown: Bool
    let animate: Bool
    let inset: CGFloat

    var body: some View {
        let n = puzzle.size
        let lands = Lands(puzzle: puzzle)
        let crowns = puzzle.solutionCells
        let seed = puzzle.solution[0]
        Color.clear
            .keyframeAnimator(initialValue: lands.end, trigger: trigger) { _, t in
                Canvas { ctx, size in
                    guard shown else { return }
                    let cell = (min(size.width, size.height) - inset * 2) / CGFloat(n)
                    let line = max(1, cell * 0.035)
                    for i in 0..<n * n {
                        let q = animate ? min(max((t - lands.time[i]) / SolveTiming.landDraw, 0), 1) : 1
                        guard q > 0 else { continue }
                        let origin = pt(inset + CGFloat(i % n) * cell, inset + CGFloat(i / n) * cell)
                        if crowns.contains(i) {
                            let keep = keepPath.applying(CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: cell, y: cell))
                            ctx.fill(keep, with: .color(Theme.paper.opacity(q)))
                            ctx.stroke(keep.trimmedPath(from: 0, to: q), with: .color(Theme.ink.opacity(0.8)), style: StrokeStyle(lineWidth: line * 1.3, lineJoin: .round))
                            continue
                        }
                        let s = Double(i) + Double(seed) * 31
                        let terrain = Glyph.terrains[(puzzle.regionOf[i] + seed) % Glyph.terrains.count]
                        let glyph = terrain[Int(hash(s) * Double(terrain.count)) % terrain.count]
                        let scale = cell * (0.78 + 0.17 * hash(s + 5))
                        let flip: CGFloat = hash(s + 9) < 0.5 ? -1 : 1
                        let shift = pt((hash(s + 2) - 0.5) * 0.12 * cell, (hash(s + 4) - 0.5) * 0.12 * cell)
                        let place = CGAffineTransform(translationX: origin.x + cell / 2 + shift.x, y: origin.y + cell / 2 + shift.y)
                            .scaledBy(x: scale * flip, y: scale)
                            .translatedBy(x: -0.5, y: -0.5)
                        ctx.stroke(glyph.path.applying(place).trimmedPath(from: 0, to: q), with: .color(Theme.ink.opacity(0.5)),
                                   style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
                    }
                }
            } keyframes: { _ in
                MoveKeyframe(0.0)
                LinearKeyframe(lands.end, duration: lands.end)
            }
            .allowsHitTesting(false)
    }
}

// MARK: Battlements

/// On a solved board the borders between kingdoms become castle walls. Battlements rise along each
/// border from the crown that reaches it first, facing away from that crown, and the frame becomes
/// a curtain wall with a tower at each corner. Drawn inside the ink layer so it wobbles with the ink.
struct Battlements: View {
    let puzzle: Puzzle
    let trigger: Int
    let shown: Bool
    let animate: Bool
    let inset: CGFloat

    private struct Tooth {
        let at: CGPoint
        let out: CGVector
        let time: Double
    }

    var body: some View {
        let lands = Lands(puzzle: puzzle)
        Color.clear
            .keyframeAnimator(initialValue: lands.end, trigger: trigger) { _, t in
                Canvas { ctx, size in
                    guard shown else { return }
                    let n = puzzle.size
                    let cell = (min(size.width, size.height) - inset * 2) / CGFloat(n)
                    let s = min(max(cell * 0.16, 4), 8)
                    let tower = s * 1.5
                    let wall = SolveTiming.outerWall(rows: n)
                    func grow(_ start: Double, over d: Double) -> Double {
                        animate ? backOut(min(max((t - start) / d, 0), 1)) : 1
                    }
                    for tooth in teeth(lands: lands, cell: cell, s: s, tower: tower) {
                        let g = grow(tooth.time, over: 0.18)
                        guard g > 0 else { continue }
                        let d = s * g
                        let b = pt(tooth.at.x + tooth.out.dx * d, tooth.at.y + tooth.out.dy * d)
                        let wide = tooth.out.dx == 0
                        let rect = CGRect(x: min(tooth.at.x, b.x) - (wide ? s / 2 : 0), y: min(tooth.at.y, b.y) - (wide ? 0 : s / 2),
                                          width: abs(b.x - tooth.at.x) + (wide ? s : 0), height: abs(b.y - tooth.at.y) + (wide ? 0 : s))
                        ctx.fill(Path(roundedRect: rect, cornerRadius: 0.8), with: .color(Theme.ink))
                    }
                    let corners = [pt(inset, inset), pt(size.width - inset, inset), pt(size.width - inset, size.height - inset), pt(inset, size.height - inset)]
                    for (k, c) in corners.enumerated() {
                        let r = tower * grow(wall + Double(k) * 0.05, over: 0.25)
                        guard r > 0 else { continue }
                        let centre = pt(c.x + (c.x < size.width / 2 ? 1 : -1) * tower * 0.8, c.y + (c.y < size.height / 2 ? 1 : -1) * tower * 0.8)
                        let ring = Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
                        ctx.fill(ring, with: .color(Theme.paper))
                        ctx.stroke(ring, with: .color(Theme.ink), lineWidth: 2)
                        let top = Path(ellipseIn: CGRect(x: centre.x - r * 0.6, y: centre.y - r * 0.6, width: r * 1.2, height: r * 1.2))
                        ctx.stroke(top, with: .color(Theme.ink), style: StrokeStyle(lineWidth: s * 0.5, dash: [s * 0.45, s * 0.4]))
                    }
                }
            } keyframes: { _ in
                MoveKeyframe(0.0)
                LinearKeyframe(lands.end, duration: lands.end)
            }
            .allowsHitTesting(false)
    }

    private func teeth(lands: Lands, cell: CGFloat, s: CGFloat, tower: CGFloat) -> [Tooth] {
        let n = puzzle.size
        let count = max(2, Int(cell / (s * 2)))
        func at(_ c: CGFloat, _ r: CGFloat) -> CGPoint { pt(inset + c * cell, inset + r * cell) }
        func along(_ k: Int) -> CGFloat { (CGFloat(k) + 0.5) / CGFloat(count) }
        var out: [Tooth] = []
        for r in 0..<n {
            for c in 0..<n {
                let i = r * n + c, g = puzzle.regionOf[i]
                for (j, vertical) in [(i + 1, true), (i + n, false)] {
                    guard vertical ? c + 1 < n : r + 1 < n, puzzle.regionOf[j] != g else { continue }
                    let sign: CGFloat = lands.time[i] <= lands.time[j] ? 1 : -1
                    let start = min(lands.time[i], lands.time[j])
                    for k in 0..<count {
                        out.append(Tooth(
                            at: vertical ? at(CGFloat(c + 1), CGFloat(r) + along(k)) : at(CGFloat(c) + along(k), CGFloat(r + 1)),
                            out: vertical ? CGVector(dx: sign, dy: 0) : CGVector(dx: 0, dy: sign),
                            time: start + Double(k) * 0.03))
                    }
                }
            }
        }
        // The curtain wall: teeth face inward along the frame, spreading out from the towers.
        let wall = SolveTiming.outerWall(rows: n) + 0.12
        for j in 0..<n {
            for k in 0..<count {
                let f = CGFloat(j) + along(k)
                let fromCorner = min(f, CGFloat(n) - f)
                guard fromCorner * cell > tower * 1.9 else { continue }
                let time = wall + Double(fromCorner) * 0.04
                out.append(Tooth(at: at(f, 0), out: CGVector(dx: 0, dy: 1), time: time))
                out.append(Tooth(at: at(f, CGFloat(n)), out: CGVector(dx: 0, dy: -1), time: time))
                out.append(Tooth(at: at(0, f), out: CGVector(dx: 1, dy: 0), time: time))
                out.append(Tooth(at: at(CGFloat(n), f), out: CGVector(dx: -1, dy: 0), time: time))
            }
        }
        return out
    }
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
