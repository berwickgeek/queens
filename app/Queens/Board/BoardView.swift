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
                InkLayer(puzzle: game.puzzle, inset: inset)
                if let hint = game.hintCell {
                    HintMarker(cell: cell)
                        .offset(x: inset + CGFloat(hint % game.n) * cell, y: inset + CGFloat(hint / game.n) * cell)
                        .transition(.opacity)
                }
                marks(cell: cell)
            }
            .frame(width: side, height: side)
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
                cell: cell,
                clashTrigger: game.clashTrigger,
                solveTrigger: game.solveTrigger,
                bounceDelay: Double(i / game.n) * 0.07,
                reduceMotion: reduceMotion
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

    var body: some View {
        ZStack {
            RegionBorders(puzzle: puzzle, inset: inset)
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: puzzle.size > 8 ? 2.2 : 2.6, lineCap: .round, lineJoin: .round))
            Rectangle()
                .inset(by: inset)
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 3.6, lineJoin: .round))
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
    let cell: CGFloat
    let clashTrigger: Int
    let solveTrigger: Int
    let bounceDelay: Double
    let reduceMotion: Bool

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
            case .queen:
                CrownMark(color: clashing ? Theme.error : Theme.ink)
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
        .frame(width: cell, height: cell)
    }
}

/// Ink crown with three jewels, drawn on a 24-unit grid.
private struct CrownMark: View {
    let color: Color

    var body: some View {
        ZStack {
            Crown().fill(color)
            CrownJewels().fill(Theme.paper)
        }
        .animation(.easeOut(duration: 0.2), value: color)
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
