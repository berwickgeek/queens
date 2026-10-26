import SwiftUI

/// Rounded pill used for every game command.
struct PillButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fixedSize()
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

/// Crowns placed out of the kingdoms on the board: a pencil outline per kingdom, inked as crowns go down.
struct CrownTally: View {
    let placed: Int
    let total: Int
    var gilded = false
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: size * 0.2) {
            ForEach(0..<total, id: \.self) { k in
                ZStack {
                    Crown().stroke(Theme.pencil, lineWidth: 1)
                    Crown().fill(gilded ? Theme.gold : Theme.ink)
                        .scaleEffect(k < placed ? 1 : 0.4)
                        .opacity(k < placed ? 1 : 0)
                }
                .frame(width: size, height: size)
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.4), value: placed)
        .animation(.easeOut(duration: 0.4), value: gilded)
        .accessibilityElement()
        .accessibilityLabel("\(placed) of \(total) crowned")
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
    /// Seconds to wait before unfurling, and before the seal stamps down.
    var unfurlDelay = 0.5
    var stampDelay = 1.2
    /// Count the time up from zero as the ribbon opens (only on a fresh solve).
    var countUp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var unfurled = false
    @State private var stampTick = 0

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // The final text sizes the ribbon so it does not grow while the digits count.
                Text("Crowned in \(formatTime(time))").hidden()
                Color.clear
                    .keyframeAnimator(initialValue: countUp && !reduceMotion ? 0.0 : time, trigger: stampTick) { _, shown in
                        Text("Crowned in \(formatTime(shown))")
                            .fixedSize()
                    } keyframes: { _ in
                        if countUp && !reduceMotion {
                            LinearKeyframe(0.0, duration: unfurlDelay + 0.15)
                            CubicKeyframe(time, duration: min(0.9, 0.3 + time / 120))
                        } else {
                            LinearKeyframe(time, duration: 0.01)
                        }
                    }
            }
            .font(.headlineSm)
            if newBest || hinted {
                HStack(spacing: 6) {
                    if newBest { BestSparkle(trigger: stampTick, delay: stampDelay + 0.15) }
                    Text(newBest ? "A new best" : "With a hint")
                        .font(.bodySm)
                        .opacity(0.85)
                    if newBest { BestSparkle(trigger: stampTick, delay: stampDelay + 0.25) }
                }
            }
        }
        .foregroundStyle(Theme.paper)
        .padding(.horizontal, 44)
        .padding(.vertical, 12)
        .background(Ribbon().fill(Theme.success).shadow(color: Theme.ink.opacity(0.18), radius: 6, y: 3))
        .scaleEffect(x: unfurled ? 1 : 0.05, y: 1)
        .opacity(unfurled ? 1 : 0)
        .overlay(alignment: .top) {
            StampedSeal(trigger: stampTick, delay: stampDelay, reduceMotion: reduceMotion)
                .offset(y: -28)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.7, bounce: 0.35).delay(unfurlDelay)) {
                unfurled = true
            }
            stampTick += 1
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Crowned in \(formatTime(time))\(newBest ? ", a new best" : hinted ? ", with a hint" : "")")
    }
}

/// A blob of sealing wax pressed with a gold crown.
struct WaxSeal: View {
    var body: some View {
        ZStack {
            WaxBlob().fill(Theme.wax)
            WaxBlob().stroke(Theme.waxDeep, lineWidth: 1)
            // The ring left by the seal's die, and light catching the wax.
            Circle().inset(by: 7).stroke(Theme.waxDeep.opacity(0.7), lineWidth: 1.2)
            WaxBlob().fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .topLeading, endPoint: .center))
            ZStack {
                Crown().fill(Theme.gold)
                Crown().stroke(Theme.goldDeep, lineWidth: 0.8)
            }
            .padding(11)
            .offset(y: -1)
        }
        .accessibilityHidden(true)
    }
}

/// An uneven round of wax, squeezed out at the edges.
struct WaxBlob: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        var p = Path()
        let steps = 90
        for i in 0...steps {
            let a = Double(i) / Double(steps) * 2 * .pi
            let wobble = 0.05 * sin(a * 9) + 0.03 * sin(a * 5 + 1.3) + 0.015 * sin(a * 14 + 0.4)
            let point = CGPoint(x: c.x + cos(a) * r * (0.92 + wobble), y: c.y + sin(a) * r * (0.92 + wobble))
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

private struct SealPose {
    var scale = 2.6
    var rotation = -40.0
    var opacity = 0.0
    /// Flecks of wax and dust thrown out on impact, 0 to 1.
    var puff = 0.0
}

/// The seal drops from above, squashes as it presses, and throws out a few flecks.
private struct StampedSeal: View {
    let trigger: Int
    let delay: Double
    let reduceMotion: Bool

    var body: some View {
        WaxSeal()
            .frame(width: 42, height: 42)
            .keyframeAnimator(initialValue: SealPose(), trigger: trigger) { seal, pose in
                ZStack {
                    ForEach(0..<8, id: \.self) { k in
                        let a = Double(k) / 8 * 2 * .pi + 0.3
                        Circle()
                            .fill(k.isMultiple(of: 2) ? Theme.wax : Theme.gold)
                            .frame(width: 4, height: 4)
                            .offset(x: cos(a) * (18 + 16 * pose.puff), y: sin(a) * (16 + 12 * pose.puff))
                            .opacity(pose.puff > 0 && pose.puff < 1 ? 1 - pose.puff : 0)
                    }
                    seal
                        .shadow(color: Theme.waxDeep.opacity(0.35), radius: 2 + 8 * (pose.scale - 1), y: 1 + 4 * (pose.scale - 1))
                        .scaleEffect(pose.scale)
                        .rotationEffect(.degrees(pose.rotation))
                        .opacity(pose.opacity)
                }
            } keyframes: { _ in
                let lead = max(delay - 0.18, 0.01)
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: reduceMotion ? delay : lead)
                    LinearKeyframe(1, duration: reduceMotion ? 0.3 : 0.08)
                }
                KeyframeTrack(\.scale) {
                    if reduceMotion {
                        LinearKeyframe(1, duration: 0.01)
                    } else {
                        LinearKeyframe(2.6, duration: lead)
                        CubicKeyframe(0.9, duration: 0.18)
                        SpringKeyframe(1.0, duration: 0.35, spring: .bouncy)
                    }
                }
                KeyframeTrack(\.rotation) {
                    if reduceMotion {
                        LinearKeyframe(-8, duration: 0.01)
                    } else {
                        LinearKeyframe(-40, duration: lead)
                        SpringKeyframe(-8, duration: 0.3, spring: .snappy)
                    }
                }
                KeyframeTrack(\.puff) {
                    if reduceMotion {
                        LinearKeyframe(0, duration: 0.01)
                    } else {
                        LinearKeyframe(0, duration: lead + 0.18)
                        MoveKeyframe(0.01)
                        CubicKeyframe(1, duration: 0.45)
                    }
                }
            }
    }
}

/// A small gold star that pops in beside "A new best".
private struct BestSparkle: View {
    let trigger: Int
    let delay: Double

    var body: some View {
        Sparkle()
            .fill(Theme.gold)
            .frame(width: 11, height: 11)
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { star, s in
                star.scaleEffect(s).rotationEffect(.degrees(90 * s))
            } keyframes: { _ in
                LinearKeyframe(0.0, duration: delay)
                SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
            }
    }
}

// MARK: Paper

/// The page: paper with faint grain and pencilled contour lines in two corners, like the margin of an old map.
struct PaperBackground: View {
    var contours = 0.07

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Theme.paper)
                .colorEffect(ShaderLibrary.granulate(.float(0.012), .float(0.04)))
            Canvas { ctx, size in
                let ink = GraphicsContext.Shading.color(Theme.ink.opacity(contours))
                hill(ctx, centre: CGPoint(x: size.width * 1.02, y: size.height * 0.04), base: size.width * 0.12, seed: 1, shading: ink)
                hill(ctx, centre: CGPoint(x: -size.width * 0.06, y: size.height * 0.98), base: size.width * 0.14, seed: 4, shading: ink)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    /// Nested wobbly loops, wider apart further out, as contour lines on a hill.
    private func hill(_ ctx: GraphicsContext, centre: CGPoint, base: CGFloat, seed: Double, shading: GraphicsContext.Shading) {
        for ring in 1...7 {
            let r = base * CGFloat(ring) * (0.75 + 0.06 * CGFloat(ring))
            var p = Path()
            for i in 0...120 {
                let a = Double(i) / 120 * 2 * .pi
                let wobble = 0.09 * sin(a * 3 + seed) + 0.05 * sin(a * 5 + seed * 2 + Double(ring) * 0.3) + 0.03 * sin(a * 9 + seed)
                let point = CGPoint(x: centre.x + cos(a) * r * (1 + wobble), y: centre.y + sin(a) * r * 0.82 * (1 + wobble))
                if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
            }
            p.closeSubpath()
            ctx.stroke(p, with: shading, lineWidth: ring == 4 ? 1.1 : 0.7)
        }
    }
}

/// Inked compass rose for the home title. The needle swings and settles on first appearance.
struct CompassRose: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: settled ? 1 : 0)
                .stroke(Theme.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 2.5]))
                .rotationEffect(.degrees(-90))
            Circle().inset(by: 5).stroke(Theme.ink.opacity(0.18), lineWidth: 0.8)
            ZStack {
                Sparkle().fill(Theme.muted.opacity(0.55)).padding(12).rotationEffect(.degrees(45))
                Sparkle().fill(Theme.ink).padding(3)
                Circle().fill(Theme.gold).frame(width: 5, height: 5)
            }
            .rotationEffect(.degrees(settled ? 0 : -120))
        }
        .frame(width: 46, height: 46)
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(duration: 1.4, bounce: 0.45).delay(0.15)) { settled = true }
        }
        .accessibilityHidden(true)
    }
}

/// Cards and tiles sink a touch under the finger.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
