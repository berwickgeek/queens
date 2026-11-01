import SwiftUI

/// Paints an `AtlasDrawing` at the view's width (a sheet is 390 map units wide), in three
/// layers like the board: watercolour through `washBleed` and `granulate`, ink through
/// `inkWobble`, then the place names with a paper halo so they read over the ink.
struct AtlasCanvas: View {
    let drawing: AtlasDrawing
    /// Sheet height in map units.
    let height: CGFloat
    /// The pencilled half of a sheet keeps a steady hand.
    var wobble = true

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / Journey.Layout.width
            ZStack {
                washes(k)
                ink(k)
                labels(k)
            }
        }
        .aspectRatio(Journey.Layout.width / height, contentMode: .fit)
        .allowsHitTesting(false)
    }

    private func washes(_ k: CGFloat) -> some View {
        Canvas { ctx, _ in
            ctx.scaleBy(x: k, y: k)
            for wash in drawing.washes { Self.paint(wash, in: &ctx) }
        }
        .compositingGroup()
        .colorEffect(Self.granulate)
        .distortionEffect(Self.bleed, maxSampleOffset: CGSize(width: 6, height: 6))
    }

    private func ink(_ k: CGFloat) -> some View {
        Canvas { ctx, _ in
            ctx.scaleBy(x: k, y: k)
            var i = drawing.ink.startIndex
            while i < drawing.ink.endIndex {
                switch drawing.ink[i] {
                case .fill(let path, let colour):
                    ctx.fill(path, with: .color(colour))
                    i += 1
                case .stroke(let path, let colour, let style):
                    ctx.stroke(path, with: .color(colour), style: style)
                    i += 1
                case .wash:
                    // A run of washes over the ink shares one layer, so it bleeds and
                    // granulates like the washes underneath.
                    var run: [AtlasDrawing.Wash] = []
                    while i < drawing.ink.endIndex, case .wash(let wash) = drawing.ink[i] {
                        run.append(wash)
                        i += 1
                    }
                    ctx.drawLayer { layer in
                        layer.addFilter(.colorShader(Self.granulate))
                        layer.addFilter(.distortionShader(Self.bleed, maxSampleOffset: CGSize(width: 6, height: 6)))
                        for wash in run { Self.paint(wash, in: &layer) }
                    }
                }
            }
        }
        .compositingGroup()
        .distortionEffect(ShaderLibrary.inkWobble(.float(0.05), .float(wobble ? 1.6 : 0)),
                          maxSampleOffset: CGSize(width: 2, height: 2))
    }

    private func labels(_ k: CGFloat) -> some View {
        Canvas { ctx, _ in
            ctx.scaleBy(x: k, y: k)
            for label in drawing.labels { Self.draw(label, in: &ctx) }
        }
    }

    // MARK: Painting

    private static let granulate = ShaderLibrary.granulate(.float(0.045), .float(0.16))
    /// `washBleed` leaves a margin of `inset` untouched; the sheet has none, so the size only
    /// needs to cover every layer it is used on.
    private static let bleed = ShaderLibrary.washBleed(.float2(100_000, 100_000), .float(0), .float(0.035), .float(4.5))

    /// A wash dries darker at its rim, so each one gets a soft edge stroke at half strength.
    private static func paint(_ wash: AtlasDrawing.Wash, in ctx: inout GraphicsContext) {
        let colour = wash.color.opacity(wash.opacity)
        if let width = wash.lineWidth {
            ctx.stroke(wash.path, with: .color(colour), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        } else {
            ctx.fill(wash.path, with: .color(colour))
            ctx.stroke(wash.path, with: .color(wash.color.opacity(wash.opacity * 0.5)), lineWidth: 1.2)
        }
    }

    private static let halo: [CGSize] = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]
        .map { CGSize(width: $0.0 * 1.3, height: $0.1 * 1.3) }

    /// `at` is the baseline, as in the mockup's SVG; Fell is set 10% larger to match its size there.
    private static func draw(_ label: AtlasDrawing.Label, in ctx: inout GraphicsContext) {
        func text(_ colour: Color) -> Text {
            Text(label.text).font(.atlas(label.size * 1.1, italic: label.italic)).tracking(label.tracking).foregroundStyle(colour)
        }
        let ink = ctx.resolve(text(label.color))
        let size = ink.measure(in: CGSize(width: 1000, height: 1000))
        let baseline = ink.firstBaseline(in: size)
        let x: CGFloat = switch label.anchor {
        case .start: 0
        case .middle: -size.width / 2
        case .end: -size.width
        }
        let origin = CGPoint(x: x, y: -baseline)
        var c = ctx
        c.translateBy(x: label.at.x, y: label.at.y)
        c.rotate(by: label.rotation)
        let paper = c.resolve(text(Theme.Atlas.paper))
        c.drawLayer { halo in
            halo.opacity = 0.85
            for d in Self.halo { halo.draw(paper, at: CGPoint(x: origin.x + d.width, y: origin.y + d.height), anchor: .topLeading) }
        }
        c.draw(ink, at: origin, anchor: .topLeading)
    }
}

/// The sheet itself: aged paper with blotches, a fold down the middle, a darker rim and grain.
struct AtlasPaper: View {
    var seed = 11

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / Journey.Layout.width
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.Atlas.paper))
            ctx.drawLayer { blots in
                blots.addFilter(.blur(radius: 28 * k))
                var rng = AtlasRandom(seed: seed)
                let count = max(4, Int(size.height / k / 110))
                for _ in 0..<count {
                    let r = rng.next(40...90) * k
                    let c = CGPoint(x: rng.next() * size.width, y: rng.next() * size.height)
                    blots.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.7, width: 2 * r, height: 1.4 * r)),
                               with: .color(Theme.Atlas.paperShade.opacity(rng.next(0.18...0.35))))
                }
            }
            let crease = Gradient(stops: [
                .init(color: Theme.Atlas.paperShade.opacity(0), location: 0),
                .init(color: Theme.Atlas.paperShade.opacity(0.28), location: 0.5),
                .init(color: Theme.Atlas.paperShade.opacity(0), location: 1),
            ])
            ctx.fill(Path(CGRect(x: 186 * k, y: 0, width: 18 * k, height: size.height)),
                     with: .linearGradient(crease, startPoint: CGPoint(x: 186 * k, y: 0), endPoint: CGPoint(x: 204 * k, y: 0)))
            let vignette = Gradient(stops: [
                .init(color: Theme.Atlas.paperShade.opacity(0), location: 0.62),
                .init(color: Theme.Atlas.paperShade.opacity(0.75), location: 1),
            ])
            let radius = 0.78 * max(size.width, size.height)
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(vignette, center: CGPoint(x: size.width / 2, y: size.height * 0.45), startRadius: 0, endRadius: radius))
        }
        .colorEffect(ShaderLibrary.granulate(.float(0.85), .float(0.1)))
        .allowsHitTesting(false)
    }
}

/// The edge between the inked map and the pencilled one: a wavering line at `y` (map units),
/// filled down to the bottom of the sheet. Animating `y` upward is the inking.
struct AtlasInkLine: Shape {
    var y: CGFloat

    var animatableData: CGFloat {
        get { y }
        set { y = newValue }
    }

    private static let noise = AtlasNoise(seed: 77)

    func path(in rect: CGRect) -> Path {
        let k = rect.width / Journey.Layout.width
        let edge = stride(from: CGFloat(-10), through: Journey.Layout.width + 10, by: 4).map { (x: CGFloat) -> CGPoint in
            let wave: CGFloat = 12 * sin(x * 0.035 + 1)
            let wobble: CGFloat = 16 * (Self.noise(x * 0.02, 7) - 0.5)
            return CGPoint(x: x * k, y: (y + wave + wobble) * k)
        }
        var path = Path.polyline(edge)
        path.addLine(to: CGPoint(x: rect.maxX + 10 * k, y: rect.maxY + 20))
        path.addLine(to: CGPoint(x: rect.minX - 10 * k, y: rect.maxY + 20))
        path.closeSubpath()
        return path
    }
}

/// A sheet half inked: the pencil drawing everywhere, the inked one (on its own paper, so it
/// hides the pencil) below a soft `AtlasInkLine` at `boundary`.
struct AtlasSheet: View {
    let pencil: AtlasDrawing
    let ink: AtlasDrawing
    let height: CGFloat
    var boundary: CGFloat

    var body: some View {
        ZStack {
            AtlasPaper()
            AtlasCanvas(drawing: pencil, height: height, wobble: false)
            ZStack {
                AtlasPaper()
                AtlasCanvas(drawing: ink, height: height)
            }
            .mask {
                AtlasInkLine(y: boundary)
                    .fill(.black)
                    .blur(radius: 5)
            }
        }
        .aspectRatio(Journey.Layout.width / height, contentMode: .fit)
    }
}
