import SwiftUI

/// The storybook board: watercolour washes, pencil grid, wobbly ink borders, crowns and crosses.
struct BoardView: View {
    let game: GameModel
    /// False until the game screen has appeared; flipping it drops the sheet in and blooms the kingdoms.
    var entered = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var touching = false

    /// Keeps the outer frame stroke inside the view so it is not clipped.
    private let inset: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = (side - inset * 2) / CGFloat(game.n)
            ZStack(alignment: .topLeading) {
                WashLayer(puzzle: game.puzzle, claimed: game.claimedRegions, bloomed: entered, inset: inset, side: side)
                PencilGrid(n: game.n, inset: inset)
                    .stroke(Theme.pencil, lineWidth: 1)
                if !reduceMotion {
                    KingdomDust(puzzle: game.puzzle, trigger: entered, inset: inset, side: side)
                }
                // Celebration layers stay mounted and draw nothing at rest, so a trigger bump always animates.
                if !reduceMotion {
                    KingdomRipple(puzzle: game.puzzle, trigger: game.solveTrigger, inset: inset, side: side)
                }
                if let step = game.clueStep, !step.focus.isEmpty {
                    Spotlight(n: game.n, inset: inset, focus: game.clueFocusCells)
                        .fill(Theme.paper.opacity(0.62))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                InkLayer(puzzle: game.puzzle, inset: inset, gilded: game.gilded, gildDelay: SolveTiming.finale(rows: game.n))
                if let step = game.clueStep {
                    ForEach(step.cells.sorted(), id: \.self) { hint in
                        Group {
                            if step.dots { GhostCross(seed: hint + 1, cell: cell) } else { HintMarker(cell: cell) }
                        }
                            .offset(x: inset + CGFloat(hint % game.n) * cell, y: inset + CGFloat(hint / game.n) * cell)
                            .transition(.opacity)
                    }
                }
                if !reduceMotion {
                    RoyalRoad(puzzle: game.puzzle, trigger: game.solveTrigger, inset: inset, cell: cell)
                }
                if !reduceMotion {
                    KingdomSeal(puzzle: game.puzzle, region: game.lastSealed, trigger: game.sealTrigger, delay: game.sealDelay, inset: inset, side: side)
                    InkDrop(trigger: game.placeTrigger, strength: Double(game.queenCount) / Double(game.n), cell: cell)
                        .offset(x: inset + CGFloat(game.lastPlaced % game.n) * cell, y: inset + CGFloat(game.lastPlaced / game.n) * cell)
                }
                marks(cell: cell, side: side)
                if !reduceMotion {
                    Sheen(trigger: game.solveTrigger, delay: SolveTiming.finale(rows: game.n) - 0.1, side: side)
                        .allowsHitTesting(false)
                    if game.gilded {
                        CrownGlints(
                            puzzle: game.puzzle, inset: inset, side: side,
                            delay: game.solveTrigger > 0 ? SolveTiming.stamp(rows: game.n) + 0.6 : 0.8
                        )
                        .id(game.solveTrigger)
                    }
                    Lanterns(puzzle: game.puzzle, trigger: game.solveTrigger, flourish: game.flourish, inset: inset, side: side)
                    Comet(trigger: game.cometTrigger, rows: game.n, side: side)
                }
            }
            .frame(width: side, height: side)
            // The entrance: the sheet is laid down with a slight turn and settles.
            .opacity(entered ? 1 : 0)
            .scaleEffect(entered || reduceMotion ? 1 : 0.94)
            .rotationEffect(.degrees(entered || reduceMotion ? 0 : -1.2))
            .offset(y: entered || reduceMotion ? 0 : 22)
            .animation(
                reduceMotion ? .easeOut(duration: 0.25).delay(Entrance.delay) : .spring(duration: Entrance.drop, bounce: 0.2).delay(Entrance.delay),
                value: entered
            )
            .keyframeAnimator(initialValue: 1.0, trigger: game.solveTrigger) { view, scale in
                view.scaleEffect(scale)
            } keyframes: { _ in
                if reduceMotion {
                    LinearKeyframe(1.0, duration: 0.01)
                } else {
                    LinearKeyframe(1.0, duration: SolveTiming.finale(rows: game.n))
                    SpringKeyframe(1.04, duration: 0.14, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.6, spring: .bouncy)
                }
            }
            .contentShape(Rectangle())
            .gesture(drag(cell: cell))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Board, \(game.n) by \(game.n), \(game.queenCount) crowns placed")
    }

    private func marks(cell: CGFloat, side: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
        ForEach(0..<game.n * game.n, id: \.self) { i in
            MarkView(
                mark: game.marks[i],
                seed: i + 1,
                clashing: game.clashes.contains(i),
                pencilled: game.pencilled(i),
                cell: cell,
                clashTrigger: game.clashTrigger,
                solveTrigger: game.solveTrigger,
                gilded: game.gilded,
                bounceDelay: Double(i / game.n) * SolveTiming.rowStagger,
                reduceMotion: reduceMotion
            )
            .frame(width: cell, height: cell)
            .offset(x: inset + CGFloat(i % game.n) * cell, y: inset + CGFloat(i / game.n) * cell)
            .allowsHitTesting(false)
        }
        }
        .frame(width: side, height: side, alignment: .topLeading)
        // A finer wobble than the borders, so crowns and crosses have a pen's ragged edge.
        .distortionEffect(
            ShaderLibrary.inkWobble(.float(0.2), .float(0.9)),
            maxSampleOffset: CGSize(width: 1, height: 1)
        )
    }

    private func drag(cell: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let i = index(at: value.location, cell: cell) else { return }
                if touching {
                    game.touchMoved(i)
                } else {
                    touching = true
                    game.touchBegan(i)
                }
            }
            .onEnded { _ in
                touching = false
                game.touchEnded()
            }
    }

    private func index(at p: CGPoint, cell: CGFloat) -> Int? {
        let c = Int(((p.x - inset) / cell).rounded(.down))
        let r = Int(((p.y - inset) / cell).rounded(.down))
        guard (0..<game.n).contains(c), (0..<game.n).contains(r) else { return nil }
        return r * game.n + c
    }
}

// MARK: Wash

private struct WashLayer: View {
    let puzzle: Puzzle
    let claimed: Set<Int>
    let bloomed: Bool
    let inset: CGFloat
    let side: CGFloat

    /// Each kingdom's place in the bloom order, top to bottom by its first cell.
    private var rank: [Int] {
        let first = (0..<puzzle.size).map { g in puzzle.regionOf.firstIndex(of: g) ?? 0 }
        var rank = Array(repeating: 0, count: puzzle.size)
        for (i, g) in (0..<puzzle.size).sorted(by: { first[$0] < first[$1] }).enumerated() { rank[g] = i }
        return rank
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let rank = rank
        ZStack {
            ForEach(0..<puzzle.size, id: \.self) { g in
                let wash = RegionShape(puzzle: puzzle, region: g, inset: inset)
                    .fill(Theme.region(g))
                    .opacity(bloomed ? (claimed.contains(g) ? 1 : Theme.washUnclaimed) : 0)
                    .animation(.easeOut(duration: 0.45), value: claimed.contains(g))
                if reduceMotion {
                    wash.animation(.easeOut(duration: Entrance.bloomFade).delay(Entrance.bloom(rank[g])), value: bloomed)
                } else {
                    wash.animation(nil, value: bloomed)
                        .modifier(WashDrop(trigger: bloomed, start: Entrance.bloom(rank[g]), anchor: centre(g)))
                }
            }
        }
        .compositingGroup()
        .colorEffect(ShaderLibrary.granulate(.float(0.045), .float(0.16)))
        .distortionEffect(
            ShaderLibrary.washBleed(.float2(side, side), .float(inset), .float(0.035), .float(4.5)),
            maxSampleOffset: CGSize(width: 6, height: 6)
        )
    }

    /// The middle of kingdom `g`'s cells, as a point in the board, so it drops and shudders about itself.
    private func centre(_ g: Int) -> UnitPoint {
        let n = puzzle.size
        let cells = (0..<n * n).filter { puzzle.regionOf[$0] == g }
        guard !cells.isEmpty else { return .center }
        let x = cells.reduce(CGFloat(0)) { $0 + CGFloat($1 % n) + 0.5 } / CGFloat(cells.count)
        let y = cells.reduce(CGFloat(0)) { $0 + CGFloat($1 / n) + 0.5 } / CGFloat(cells.count)
        let cell = (side - inset * 2) / CGFloat(n)
        return UnitPoint(x: (inset + x * cell) / side, y: (inset + y * cell) / side)
    }
}

/// One kingdom's wash in the entrance: held off the sheet until `start`, then it falls from a little
/// above and larger, lands with a squash, and shudders side to side. Rests at the landed values, so a
/// board shown without an entrance draws flat.
private struct WashDrop: ViewModifier {
    let trigger: Bool
    let start: Double
    let anchor: UnitPoint

    private struct Pose {
        var lift: CGFloat = 0
        var shake: CGFloat = 0
        var scale: CGFloat = 1
        var opacity: Double = 1
    }

    func body(content: Content) -> some View {
        let s = Entrance.shudder / 6
        return content.keyframeAnimator(initialValue: Pose(), trigger: trigger) { view, pose in
            view
                .opacity(pose.opacity)
                .scaleEffect(pose.scale, anchor: anchor)
                .offset(x: pose.shake, y: -pose.lift)
        } keyframes: { _ in
            KeyframeTrack(\.opacity) {
                MoveKeyframe(0)
                LinearKeyframe(0, duration: start)
                LinearKeyframe(1, duration: Entrance.fall * 0.6)
            }
            KeyframeTrack(\.lift) {
                MoveKeyframe(30)
                LinearKeyframe(30, duration: start)
                LinearKeyframe(0, duration: Entrance.fall, timingCurve: .easeIn)
                LinearKeyframe(3, duration: 0.05, timingCurve: .easeOut)
                LinearKeyframe(0, duration: 0.06, timingCurve: .easeIn)
                LinearKeyframe(0.8, duration: 0.04)
                LinearKeyframe(0, duration: 0.04)
            }
            KeyframeTrack(\.scale) {
                MoveKeyframe(1.14)
                LinearKeyframe(1.14, duration: start)
                LinearKeyframe(1, duration: Entrance.fall, timingCurve: .easeIn)
                LinearKeyframe(0.97, duration: 0.04)
                SpringKeyframe(1, duration: 0.2, spring: .bouncy)
            }
            KeyframeTrack(\.shake) {
                MoveKeyframe(0)
                LinearKeyframe(0, duration: start + Entrance.fall)
                LinearKeyframe(2.4, duration: s)
                LinearKeyframe(-2.0, duration: s)
                LinearKeyframe(1.5, duration: s)
                LinearKeyframe(-1.0, duration: s)
                LinearKeyframe(0.5, duration: s)
                LinearKeyframe(0, duration: s)
            }
        }
    }
}

// MARK: Dust

/// The puff where each kingdom's wash hits the sheet: flecks of its colour and pencil grey thrown out from
/// its outline, and a soft cloud drifting off each side. One clock for the whole entrance; draws nothing at rest.
private struct KingdomDust: View {
    let puzzle: Puzzle
    let trigger: Bool
    let inset: CGFloat
    let side: CGFloat
    /// Each kingdom's outer edges: a point on the edge's start, its direction, and its outward normal.
    private let edges: [[(from: CGPoint, along: CGVector, out: CGVector)]]
    private let rank: [Int]

    init(puzzle: Puzzle, trigger: Bool, inset: CGFloat, side: CGFloat) {
        self.puzzle = puzzle
        self.trigger = trigger
        self.inset = inset
        self.side = side
        let n = puzzle.size
        let cell = (side - inset * 2) / CGFloat(n)
        var edges = Array(repeating: [(from: CGPoint, along: CGVector, out: CGVector)](), count: n)
        for i in 0..<n * n {
            let g = puzzle.regionOf[i], r = i / n, c = i % n
            let x = inset + CGFloat(c) * cell, y = inset + CGFloat(r) * cell
            func other(_ rr: Int, _ cc: Int) -> Bool {
                !(0..<n).contains(rr) || !(0..<n).contains(cc) || puzzle.regionOf[rr * n + cc] != g
            }
            if other(r - 1, c) { edges[g].append((CGPoint(x: x, y: y), CGVector(dx: cell, dy: 0), CGVector(dx: 0, dy: -1))) }
            if other(r + 1, c) { edges[g].append((CGPoint(x: x, y: y + cell), CGVector(dx: cell, dy: 0), CGVector(dx: 0, dy: 1))) }
            if other(r, c - 1) { edges[g].append((CGPoint(x: x, y: y), CGVector(dx: 0, dy: cell), CGVector(dx: -1, dy: 0))) }
            if other(r, c + 1) { edges[g].append((CGPoint(x: x + cell, y: y), CGVector(dx: 0, dy: cell), CGVector(dx: 1, dy: 0))) }
        }
        self.edges = edges
        let first = (0..<n).map { g in puzzle.regionOf.firstIndex(of: g) ?? 0 }
        var rank = Array(repeating: 0, count: n)
        for (k, g) in (0..<n).sorted(by: { first[$0] < first[$1] }).enumerated() { rank[g] = k }
        self.rank = rank
    }

    var body: some View {
        let n = puzzle.size
        let cell = (side - inset * 2) / CGFloat(n)
        let end = Entrance.end(kingdoms: n)
        let pad = cell
        Color.clear
            .keyframeAnimator(initialValue: end, trigger: trigger) { _, t in
                Canvas { ctx, _ in
                    guard t < end else { return }
                    ctx.translateBy(x: pad, y: pad)
                    for g in 0..<n where !edges[g].isEmpty {
                        let q = (t - Entrance.landing(rank[g])) / Entrance.dust
                        guard q > 0 && q < 1 else { continue }
                        let tint = Theme.region(g)
                        let spread = easeOut(q)
                        // Flecks, more for a bigger kingdom.
                        let flecks = min(10 + edges[g].count, 26)
                        for k in 0..<flecks {
                            let seed = Double(g * 97 + k)
                            let e = edges[g][Int(hash(seed) * Double(edges[g].count)) % edges[g].count]
                            let a = hash(seed + 1)
                            let reach = cell * (0.2 + 0.45 * hash(seed + 2))
                            let drift = (hash(seed + 3) - 0.5) * cell * 0.5
                            let x = e.from.x + e.along.dx * a + (e.out.dx * reach + e.out.dy * drift) * spread
                            // Flecks rise a little, then fall as they slow.
                            let y = e.from.y + e.along.dy * a + (e.out.dy * reach + e.out.dx * drift) * spread
                                - cell * 0.18 * sin(.pi * q) + cell * 0.12 * q * q
                            let r = cell * (0.025 + 0.035 * hash(seed + 4)) * (1 - 0.5 * q)
                            let alpha = 0.85 * pow(1 - q, 1.4)
                            let colour = hash(seed + 5) < 0.35 ? Theme.ink.opacity(0.35 * alpha) : tint.opacity(alpha)
                            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(colour))
                        }
                        // A few soft clouds that swell and thin out.
                        for k in 0..<4 {
                            let seed = Double(g * 131 + k + 500)
                            let e = edges[g][Int(hash(seed) * Double(edges[g].count)) % edges[g].count]
                            let a = hash(seed + 1)
                            let c = CGPoint(
                                x: e.from.x + e.along.dx * a + e.out.dx * cell * 0.25 * spread,
                                y: e.from.y + e.along.dy * a + e.out.dy * cell * 0.25 * spread - cell * 0.1 * spread
                            )
                            let r = cell * (0.18 + 0.3 * spread)
                            let alpha = 0.3 * (1 - q)
                            ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .radialGradient(
                                Gradient(colors: [tint.opacity(alpha), tint.opacity(0)]),
                                center: c, startRadius: 0, endRadius: r))
                        }
                    }
                }
            } keyframes: { _ in
                MoveKeyframe(0.0)
                LinearKeyframe(end, duration: end)
            }
            // Room past the board's edge for the dust off the outer kingdoms, overflowing the board's square.
            .frame(width: side + pad * 2, height: side + pad * 2)
            .frame(width: side, height: side)
            .allowsHitTesting(false)
    }

    private func hash(_ x: Double) -> Double {
        let s = sin(x * 127.1 + 311.7) * 43758.5453
        return s - floor(s)
    }

    private func easeOut(_ q: Double) -> Double { 1 - (1 - q) * (1 - q) }
}

/// All cells of one region as a single path.
struct RegionShape: Shape {
    let puzzle: Puzzle
    let region: Int
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let n = puzzle.size
        let cell = (min(rect.width, rect.height) - inset * 2) / CGFloat(n)
        var p = Path()
        for i in 0..<n * n where puzzle.regionOf[i] == region {
            p.addRect(CGRect(x: inset + CGFloat(i % n) * cell, y: inset + CGFloat(i / n) * cell, width: cell, height: cell))
        }
        return p
    }
}

// MARK: Lines

/// A fine graphite line between every cell, so rows and columns read at a glance.
struct PencilGrid: Shape {
    let n: Int
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height) - inset * 2
        let cell = side / CGFloat(n)
        var p = Path()
        for k in 1..<n {
            let o = inset + CGFloat(k) * cell
            p.move(to: CGPoint(x: o, y: inset))
            p.addLine(to: CGPoint(x: o, y: inset + side))
            p.move(to: CGPoint(x: inset, y: o))
            p.addLine(to: CGPoint(x: inset + side, y: o))
        }
        return p
    }
}

/// Edges where neighbouring cells belong to different regions.
struct RegionBorders: Shape {
    let puzzle: Puzzle
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let n = puzzle.size
        let cell = (min(rect.width, rect.height) - inset * 2) / CGFloat(n)
        func pt(_ c: Int, _ r: Int) -> CGPoint { CGPoint(x: inset + CGFloat(c) * cell, y: inset + CGFloat(r) * cell) }
        var p = Path()
        for r in 0..<n {
            for c in 0..<n {
                let g = puzzle.regionOf[r * n + c]
                if c + 1 < n, puzzle.regionOf[r * n + c + 1] != g {
                    p.move(to: pt(c + 1, r))
                    p.addLine(to: pt(c + 1, r + 1))
                }
                if r + 1 < n, puzzle.regionOf[(r + 1) * n + c] != g {
                    p.move(to: pt(c, r + 1))
                    p.addLine(to: pt(c + 1, r + 1))
                }
            }
        }
        return p
    }
}

private struct InkLayer: View {
    let puzzle: Puzzle
    let inset: CGFloat
    let gilded: Bool
    let gildDelay: Double

    var body: some View {
        ZStack {
            RegionBorders(puzzle: puzzle, inset: inset)
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: puzzle.size > 8 ? 2.2 : 2.6, lineCap: .round, lineJoin: .round))
            Rectangle()
                .inset(by: inset)
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 3.6, lineJoin: .round))
            // A gold line inside the frame once the board is solved.
            Rectangle()
                .inset(by: inset + 3.2)
                .stroke(Theme.gold, lineWidth: 2.4)
                .opacity(gilded ? 1 : 0)
                .animation(gilded ? .easeOut(duration: 0.5).delay(gildDelay) : .easeOut(duration: 0.2), value: gilded)
        }
        .distortionEffect(
            ShaderLibrary.inkWobble(.float(0.05), .float(1.6)),
            maxSampleOffset: CGSize(width: 2, height: 2)
        )
    }
}

// MARK: Marks

private struct MarkView: View {
    let mark: Mark
    /// The cell index, so each hand-drawn mark keeps its own small quirks.
    let seed: Int
    let clashing: Bool
    let pencilled: Bool
    let cell: CGFloat
    let clashTrigger: Int
    let solveTrigger: Int
    let gilded: Bool
    let bounceDelay: Double
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            switch mark {
            case .empty:
                Color.clear
            case .cross:
                InkCross(seed: seed)
                    .fill(Theme.muted)
                    .frame(width: cell * 0.3, height: cell * 0.3)
            case .queen:
                if !reduceMotion {
                    SparkleBurst(trigger: solveTrigger, delay: bounceDelay + SolveTiming.peak - 0.04, cell: cell)
                }
                CrownMark(
                    seed: seed,
                    color: clashing ? Theme.error : gilded ? Theme.gold : Theme.ink,
                    gilded: gilded,
                    colorDelay: gilded ? bounceDelay + SolveTiming.peak : 0
                )
                    .frame(width: cell * 0.72, height: cell * 0.72)
                    .modifier(Shake(amplitude: clashing && !reduceMotion ? 4 : 0, animatableData: CGFloat(clashTrigger)))
                    .keyframeAnimator(initialValue: 1.0, trigger: solveTrigger) { view, scale in
                        view.scaleEffect(scale)
                    } keyframes: { _ in
                        if reduceMotion {
                            LinearKeyframe(1.0, duration: 0.01)
                        } else {
                            // A zero-length keyframe leaves the scale invalid and the row 0 crown vanishes.
                            LinearKeyframe(1.0, duration: max(bounceDelay, 0.01))
                            SpringKeyframe(1.28, duration: 0.18, spring: .snappy)
                            SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
                        }
                    }
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.3).combined(with: .opacity))
            }
        }
        // Marks made since the pin are pencilled in; a clash still shows at full strength.
        .opacity(pencilled && !clashing ? Theme.pencilMark : 1)
        .frame(width: cell, height: cell)
    }
}

/// Ink crown with three jewels, drawn on a 24-unit grid.
private struct CrownMark: View {
    var seed = 0
    let color: Color
    var gilded = false
    var colorDelay = 0.0

    var body: some View {
        ZStack {
            Crown(seed: seed).fill(color)
            // A dark edge keeps a gold crown readable on the pale yellow and orange kingdoms.
            Crown(seed: seed).stroke(Theme.goldDeep, style: StrokeStyle(lineWidth: 1, lineJoin: .round)).opacity(gilded ? 1 : 0)
            CrownJewels(seed: seed).fill(Theme.paper)
        }
        // Drawn freehand, so never quite straight.
        .rotationEffect(.degrees(5 * handJitter(seed, 90)))
        .animation(.easeOut(duration: 0.2).delay(colorDelay), value: color)
        .animation(.easeOut(duration: 0.2).delay(colorDelay), value: gilded)
    }
}

/// Gold four-point stars and a ring thrown out from a crown at the top of its solve bounce.
private struct SparkleBurst: View {
    let trigger: Int
    let delay: Double
    let cell: CGFloat

    var body: some View {
        // Progress runs 0 to 1 once per trigger; at rest it sits at 1, which draws nothing.
        Color.clear
            .keyframeAnimator(initialValue: 1.0, trigger: trigger) { _, p in
                ZStack {
                    Circle()
                        .stroke(Theme.gold, lineWidth: 2.5 * (1 - p))
                        .frame(width: cell * (0.5 + 1.1 * p), height: cell * (0.5 + 1.1 * p))
                    ForEach(0..<8, id: \.self) { k in
                        let angle = Double(k) * .pi / 4 + .pi / 8
                        let reach = cell * (0.25 + (k.isMultiple(of: 2) ? 0.75 : 0.55) * p)
                        Sparkle()
                            .fill(k.isMultiple(of: 2) ? Theme.gold : Theme.paper)
                            .overlay(Sparkle().stroke(Theme.goldDeep.opacity(0.5), lineWidth: 0.6))
                            .frame(width: cell * 0.22, height: cell * 0.22)
                            .scaleEffect(0.4 + 0.8 * sin(.pi * min(p * 1.4, 1)))
                            .rotationEffect(.radians(angle + p * 1.5))
                            .offset(x: cos(angle) * reach, y: sin(angle) * reach)
                    }
                }
                .opacity(p >= 1 ? 0 : 1 - p * p)
            } keyframes: { _ in
                LinearKeyframe(1.0, duration: max(delay, 0.01))
                MoveKeyframe(0.0)
                CubicKeyframe(1.0, duration: 0.75)
            }
            .frame(width: cell, height: cell)
            .allowsHitTesting(false)
    }
}

struct Sparkle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let w = r * 0.28
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + w, y: c.y - w))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + w, y: c.y + w))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - w, y: c.y + w))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - w, y: c.y - w))
        p.closeSubpath()
        return p
    }
}

/// A band of gilded light that sweeps once across the board at the finale.
private struct Sheen: View {
    let trigger: Int
    let delay: Double
    let side: CGFloat

    var body: some View {
        Color.clear
            .keyframeAnimator(initialValue: 1.0, trigger: trigger) { _, p in
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white.opacity(0.75), location: 0.45),
                        .init(color: Theme.gold.opacity(0.35), location: 0.55),
                        .init(color: .white.opacity(0), location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: side * 0.45, height: side * 1.8)
                .rotationEffect(.degrees(20))
                .offset(x: -side * 0.7 + side * 1.4 * p)
                .opacity(p >= 1 ? 0 : 1)
            } keyframes: { _ in
                LinearKeyframe(1.0, duration: max(delay, 0.01))
                MoveKeyframe(0.0)
                CubicKeyframe(1.0, duration: 0.9)
            }
            .frame(width: side, height: side)
            .clipped()
    }
}

/// A stable value in -1...1 for jittering hand-drawn marks, so a mark keeps its shape between redraws.
func handJitter(_ seed: Int, _ k: Int) -> CGFloat {
    var h = UInt64(bitPattern: Int64(seed &* 7919 &+ k &* 104_729 &+ 1))
    h ^= h >> 33
    h &*= 0xff51_afd7_ed55_8ccd
    h ^= h >> 33
    return CGFloat(h % 2001) / 1000 - 1
}

/// A crown inked by hand on a 24-unit grid: slightly bowed sides, uneven points and a wavering band.
/// `seed` nudges each point a little, so crowns on different cells are never quite identical.
struct Crown: Shape {
    var seed = 0

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let amount: CGFloat = seed == 0 ? 0 : 0.6
        var k = 0
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            k += 2
            return CGPoint(x: rect.minX + (x + amount * handJitter(seed, k)) * s, y: rect.minY + (y + amount * handJitter(seed, k + 1)) * s)
        }
        var path = Path()
        let tips = Crown.tips(seed: seed).map { CGPoint(x: rect.minX + $0.x * s, y: rect.minY + $0.y * s) }
        path.move(to: p(3.1, 18.1))
        path.addQuadCurve(to: tips[0], control: p(3.2, 12.6))
        path.addQuadCurve(to: p(9.1, 12.2), control: p(7.2, 10.6))
        path.addQuadCurve(to: tips[1], control: p(11.0, 9.2))
        path.addQuadCurve(to: p(15.0, 11.8), control: p(13.3, 8.9))
        path.addQuadCurve(to: tips[2], control: p(16.9, 10.2))
        path.addQuadCurve(to: p(20.9, 17.9), control: p(20.9, 12.4))
        path.addQuadCurve(to: p(3.1, 18.1), control: p(12, 18.7))
        path.closeSubpath()
        // The band: a wavering top and bottom edge with rounded ends.
        path.move(to: p(3.6, 19.4))
        path.addQuadCurve(to: p(20.5, 19.2), control: p(12, 18.8))
        path.addQuadCurve(to: p(20.4, 21.8), control: p(21.6, 20.4))
        path.addQuadCurve(to: p(3.5, 21.9), control: p(12, 22.4))
        path.addQuadCurve(to: p(3.6, 19.4), control: p(2.4, 20.7))
        path.closeSubpath()
        for (i, c) in tips.enumerated() {
            let w = (3.8 + 0.3 * handJitter(seed, 40 + i)) * s
            let h = (3.6 + 0.3 * handJitter(seed, 50 + i)) * s
            path.addEllipse(in: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
        }
        return path
    }

    /// The three points of the crown in units, uneven on purpose; jewels sit on them.
    static func tips(seed: Int) -> [CGPoint] {
        let amount: CGFloat = seed == 0 ? 0 : 0.4
        return [(4.4, 7.8), (12.3, 4.8), (19.7, 7.3)].enumerated().map { i, t in
            CGPoint(x: t.0 + amount * handJitter(seed, 60 + i), y: t.1 + amount * handJitter(seed, 70 + i))
        }
    }
}

private struct CrownJewels: Shape {
    var seed = 0

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()
        for c in Crown.tips(seed: seed) {
            path.addEllipse(in: CGRect(x: rect.minX + (c.x - 0.8) * s, y: rect.minY + (c.y - 0.75) * s, width: 1.6 * s, height: 1.5 * s))
        }
        return path
    }
}

/// A cross made of two pen strokes that start heavy and lift off thin, each bent and angled a little
/// differently per `seed`.
struct InkCross: Shape {
    var seed = 0

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        func q(_ x: CGFloat, _ y: CGFloat, _ k: Int) -> CGPoint {
            CGPoint(x: rect.minX + (x + 0.05 * handJitter(seed, k)) * w, y: rect.minY + (y + 0.05 * handJitter(seed, k + 1)) * h)
        }
        var path = Path()
        InkCross.stroke(&path, from: q(0.1, 0.1, 0), to: q(0.9, 0.88, 2), bend: 0.06 * handJitter(seed, 4) - 0.03, width: w * 0.15)
        InkCross.stroke(&path, from: q(0.88, 0.08, 5), to: q(0.12, 0.92, 7), bend: 0.06 * handJitter(seed, 9) + 0.03, width: w * 0.14)
        return path
    }

    /// One tapered stroke along a gentle curve, as a filled outline.
    private static func stroke(_ path: inout Path, from a: CGPoint, to b: CGPoint, bend: CGFloat, width: CGFloat) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(hypot(dx, dy), 0.001)
        let c = CGPoint(x: (a.x + b.x) / 2 - dy / len * bend * len, y: (a.y + b.y) / 2 + dx / len * bend * len)
        let steps = 14
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let u = 1 - t
            let pt = CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
            let tx = 2 * u * (c.x - a.x) + 2 * t * (b.x - c.x)
            let ty = 2 * u * (c.y - a.y) + 2 * t * (b.y - c.y)
            let tl = max(hypot(tx, ty), 0.001)
            // Pressed down at the start, lifting off towards the end.
            let half = width / 2 * (0.3 + 0.7 * pow(sin(.pi * t), 0.6)) * (1.1 - 0.35 * t)
            left.append(CGPoint(x: pt.x - ty / tl * half, y: pt.y + tx / tl * half))
            right.append(CGPoint(x: pt.x + ty / tl * half, y: pt.y - tx / tl * half))
        }
        path.move(to: left[0])
        for pt in left.dropFirst() { path.addLine(to: pt) }
        for pt in right.reversed() { path.addLine(to: pt) }
        path.closeSubpath()
    }
}

/// Three quick side-to-side swings per trigger increment.
struct Shake: GeometryEffect {
    var amplitude: CGFloat
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amplitude * sin(animatableData * .pi * 6), y: 0))
    }
}

/// Fades every cell outside a clue's rows, columns and kingdoms, so the ones to study stand out.
private struct Spotlight: Shape {
    let n: Int
    let inset: CGFloat
    let focus: Set<Int>

    func path(in rect: CGRect) -> Path {
        let cell = (rect.width - inset * 2) / CGFloat(n)
        var p = Path()
        for i in 0..<(n * n) where !focus.contains(i) {
            p.addRect(CGRect(x: inset + CGFloat(i % n) * cell, y: inset + CGFloat(i / n) * cell, width: cell, height: cell))
        }
        return p
    }
}

/// A faint pulsing cross on a cell a clue says to dot.
private struct GhostCross: View {
    let seed: Int
    let cell: CGFloat
    @State private var pulse = false

    var body: some View {
        InkCross(seed: seed)
            .fill(Theme.ink)
            .frame(width: cell * 0.3, height: cell * 0.3)
            .frame(width: cell, height: cell)
            .opacity(pulse ? 0.2 : 0.55)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
            }
            .allowsHitTesting(false)
    }
}

/// Pulsing dashed outline on the hinted cell.
private struct HintMarker: View {
    let cell: CGFloat
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(Theme.ink, style: StrokeStyle(lineWidth: 2.4, dash: [5, 4]))
            .frame(width: cell, height: cell)
            .scaleEffect(pulse ? 0.86 : 1)
            .opacity(pulse ? 0.6 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
            }
            .allowsHitTesting(false)
    }
}
