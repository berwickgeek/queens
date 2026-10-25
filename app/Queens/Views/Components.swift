import SwiftUI

/// Rounded pill used for every game command.
struct PillButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.labelMd)
            .foregroundStyle(prominent ? Theme.paper : Theme.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(Capsule().fill(prominent ? Theme.ink : Theme.card))
            .overlay(Capsule().strokeBorder(prominent ? Color.clear : Theme.border, lineWidth: 1))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Difficulty as five small dots.
struct TierDots: View {
    let tier: Int
    var dot: CGFloat = 6

    var body: some View {
        HStack(spacing: dot * 0.6) {
            ForEach(1...5, id: \.self) { k in
                Circle()
                    .fill(k <= tier ? Theme.ink : Theme.border)
                    .frame(width: dot, height: dot)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Difficulty \(tier) of 5")
    }
}

/// Small static rendering of a puzzle for cards.
struct MiniBoard: View {
    let puzzle: Puzzle

    var body: some View {
        Canvas { ctx, size in
            let n = puzzle.size
            let side = min(size.width, size.height)
            let cell = side / CGFloat(n)
            for i in 0..<n * n {
                let rect = CGRect(x: CGFloat(i % n) * cell, y: CGFloat(i / n) * cell, width: cell + 0.5, height: cell + 0.5)
                ctx.fill(Path(rect), with: .color(Theme.region(puzzle.regionOf[i]).opacity(Theme.washUnclaimed)))
            }
            ctx.stroke(PencilGrid(n: n).path(in: CGRect(x: 0, y: 0, width: side, height: side)), with: .color(Theme.pencil), lineWidth: 0.5)
            ctx.stroke(RegionBorders(puzzle: puzzle).path(in: CGRect(x: 0, y: 0, width: side, height: side)), with: .color(Theme.ink), lineWidth: 1.2)
            ctx.stroke(Path(CGRect(x: 0, y: 0, width: side, height: side)), with: .color(Theme.ink), lineWidth: 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Banner with notched tails, unfurled on a solve.
struct Ribbon: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.height * 0.32
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

struct SolvedBanner: View {
    let time: Double
    let newBest: Bool
    let hinted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var unfurled = false

    var body: some View {
        VStack(spacing: 2) {
            Text("Crowned in \(formatTime(time))")
                .font(.headlineSm)
            if newBest || hinted {
                Text(newBest ? "A new best" : "With a hint")
                    .font(.bodySm)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(Theme.paper)
        .padding(.horizontal, 44)
        .padding(.vertical, 12)
        .background(Ribbon().fill(Theme.success).shadow(color: Theme.ink.opacity(0.18), radius: 6, y: 3))
        .scaleEffect(x: unfurled ? 1 : 0.05, y: 1)
        .opacity(unfurled ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.7, bounce: 0.35).delay(0.5)) {
                unfurled = true
            }
        }
        .accessibilityElement(children: .combine)
    }
}
