import SwiftUI

/// The storybook board: watercolour washes, pencil grid, wobbly ink borders, crowns and crosses.
struct BoardView: View {
    let game: GameModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var touching = false

    /// Keeps the outer frame stroke inside the view so it is not clipped.
    private let inset: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = (side - inset * 2) / CGFloat(game.n)
            ZStack(alignment: .topLeading) {
                WashLayer(puzzle: game.puzzle, claimed: game.claimedRegions, inset: inset, side: side)
                PencilGrid(n: game.n, inset: inset)
                    .stroke(Theme.pencil, lineWidth: 1)
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
                            if step.dots { GhostCross(cell: cell) } else { HintMarker(cell: cell) }
                        }
                            .offset(x: inset + CGFloat(hint % game.n) * cell, y: inset + CGFloat(hint / game.n) * cell)
                            .transition(.opacity)
                    }
                }
                if !reduceMotion {
                    RoyalRoad(puzzle: game.puzzle, trigger: game.solveTrigger, inset: inset, cell: cell)
                }
                if !reduceMotion {
                    InkDrop(trigger: game.placeTrigger, cell: cell)
                        .offset(x: inset + CGFloat(game.lastPlaced % game.n) * cell, y: inset + CGFloat(game.lastPlaced / game.n) * cell)
                }
                marks(cell: cell)
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
                }
                Inhabitants(puzzle: game.puzzle, trigger: game.solveTrigger, shown: game.gilded, animate: !reduceMotion, inset: inset, side: side)
            }
            .frame(width: side, height: side)
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

    private func marks(cell: CGFloat) -> some View {
        ForEach(0..<game.n * game.n, id: \.self) { i in
            MarkView(
                mark: game.marks[i],
                clashing: game.clashes.contains(i),
                pencilled: game.pencilled(i),
                cell: cell,
                clashTrigger: game.clashTrigger,
                solveTrigger: game.solveTrigger,
                gilded: game.gilded,
                bounceDelay: Double(i / game.n) * SolveTiming.rowStagger,
                reduceMotion: reduceMotion,
                crossFade: reduceMotion ? 0 : SolveTiming.critters(rows: game.n)
            )
            .frame(width: cell, height: cell)
            .offset(x: inset + CGFloat(i % game.n) * cell, y: inset + CGFloat(i / game.n) * cell)
            .allowsHitTesting(false)
        }
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
    let inset: CGFloat
    let side: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<puzzle.size, id: \.self) { g in
                RegionShape(puzzle: puzzle, region: g, inset: inset)
                    .fill(Theme.region(g))
                    .opacity(claimed.contains(g) ? 1 : Theme.washUnclaimed)
                    .animation(.easeOut(duration: 0.45), value: claimed.contains(g))
            }
        }
        .compositingGroup()
        .colorEffect(ShaderLibrary.granulate(.float(0.045), .float(0.16)))
        .distortionEffect(
            ShaderLibrary.washBleed(.float2(side, side), .float(inset), .float(0.035), .float(4.5)),
            maxSampleOffset: CGSize(width: 6, height: 6)
        )
    }
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
    let clashing: Bool
    let pencilled: Bool
    let cell: CGFloat
    let clashTrigger: Int
    let solveTrigger: Int
    let gilded: Bool
    let bounceDelay: Double
    let reduceMotion: Bool
    /// Crosses clear off a solved board as the kingdom comes alive.
    let crossFade: Double

    var body: some View {
        ZStack {
            switch mark {
            case .empty:
                Color.clear
            case .cross:
                Text("×")
                    .font(.serif(cell * 0.5))
                    .foregroundStyle(Theme.muted)
                    .offset(y: -cell * 0.03)
                    .opacity(gilded ? 0 : 1)
                    .animation(gilded ? .easeOut(duration: 0.25).delay(crossFade) : nil, value: gilded)
            case .queen:
                if !reduceMotion {
                    SparkleBurst(trigger: solveTrigger, delay: bounceDelay + SolveTiming.peak - 0.04, cell: cell)
                }
                CrownMark(
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
    let color: Color
    var gilded = false
    var colorDelay = 0.0

    var body: some View {
        ZStack {
            Crown().fill(color)
            // A dark edge keeps a gold crown readable on the pale yellow and orange kingdoms.
            Crown().stroke(Theme.goldDeep, lineWidth: 1).opacity(gilded ? 1 : 0)
            CrownJewels().fill(Theme.paper)
        }
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

struct Crown: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(3, 18))
        path.addLine(to: p(4.5, 7.5))
        path.addLine(to: p(9, 12))
        path.addLine(to: p(12, 5))
        path.addLine(to: p(15, 12))
        path.addLine(to: p(19.5, 7.5))
        path.addLine(to: p(21, 18))
        path.closeSubpath()
        path.addRoundedRect(in: CGRect(origin: p(3, 19.2), size: CGSize(width: 18 * s, height: 2.6 * s)), cornerSize: CGSize(width: 1.2 * s, height: 1.2 * s))
        for (x, y) in [(4.5, 7.5), (12.0, 5.0), (19.5, 7.5)] {
            path.addEllipse(in: CGRect(x: rect.minX + (x - 1.9) * s, y: rect.minY + (y - 1.9) * s, width: 3.8 * s, height: 3.8 * s))
        }
        return path
    }
}

private struct CrownJewels: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()
        for (x, y) in [(4.5, 7.5), (12.0, 5.0), (19.5, 7.5)] {
            path.addEllipse(in: CGRect(x: rect.minX + (x - 0.8) * s, y: rect.minY + (y - 0.8) * s, width: 1.6 * s, height: 1.6 * s))
        }
        return path
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
    let cell: CGFloat
    @State private var pulse = false

    var body: some View {
        Text("×")
            .font(.serif(cell * 0.5))
            .foregroundStyle(Theme.ink)
            .offset(y: -cell * 0.03)
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
