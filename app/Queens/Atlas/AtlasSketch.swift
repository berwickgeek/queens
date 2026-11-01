import SwiftUI

/// A map sheet recorded as drawing operations in map units. `AtlasSketch` builds one and
/// `AtlasCanvas` paints it, so the same sheet can go to the screen or into `ImageRenderer`.
struct AtlasDrawing {
    struct Wash {
        var path: Path
        var color: Color
        var opacity: Double
        /// Set for a wash laid along a line (a river) rather than over an area.
        var lineWidth: CGFloat?
    }

    enum Ink {
        case fill(Path, Color)
        case stroke(Path, Color, StrokeStyle)
        /// Watercolour laid over the ink drawn so far, as under a castle or on a mountain's
        /// flank, where the paper fill would otherwise hide it.
        case wash(Wash)
    }

    enum Anchor { case start, middle, end }

    struct Label {
        var text: String
        var at: CGPoint
        var size: CGFloat
        var italic: Bool
        var color: Color
        var anchor: Anchor
        var rotation: Angle
        var tracking: CGFloat
    }

    var washes: [Wash] = []
    var ink: [Ink] = []
    var labels: [Label] = []

    mutating func append(_ other: AtlasDrawing) {
        washes += other.washes
        ink += other.ink
        labels += other.labels
    }
}

extension Path {
    static func polyline(_ p: [CGPoint], closed: Bool = false) -> Path {
        var path = Path()
        path.addLines(p)
        if closed { path.closeSubpath() }
        return path
    }
}

/// Draws like the cartographer in the mockup: every line wanders, starts and stops a little off,
/// and a pressed nib leaves a thicker broken second pass. In pencil mode lines are thin, grey and
/// looser, with no pressure and no washes: the part of the map not yet travelled.
struct AtlasSketch {
    private(set) var drawing = AtlasDrawing()
    let pencil: Bool
    var rng: AtlasRandom
    /// Pressure dashes draw from their own generator, so a pencil sketch and an inked one from
    /// the same seed put every line in the same place.
    private var pressRng: AtlasRandom
    private var field = 0

    init(seed: Int, pencil: Bool = false) {
        rng = AtlasRandom(seed: seed)
        pressRng = AtlasRandom(seed: seed ^ 0x5eed)
        self.pencil = pencil
    }

    var inkColor: Color { pencil ? Theme.Atlas.pencil : Theme.Atlas.ink }

    mutating func noise() -> AtlasNoise {
        defer { field += 1 }
        return AtlasNoise.fields[field % AtlasNoise.fields.count]
    }

    /// A pen line through `p`. `width` is relative to the pen; `wander` overrides how far the
    /// line strays (small shapes like castles use 0.3 so they stay legible).
    mutating func line(_ p: [CGPoint], width: CGFloat = 1, opacity: Double = 1, color: Color? = nil,
                       wander: CGFloat? = nil, closed: Bool = false, fill: Color? = nil,
                       press: Bool = true, dashed: Bool = false) {
        guard p.count > 1 else { return }
        let w = width * (pencil ? Theme.Atlas.pencilWidth : Theme.Atlas.penWidth)
        let amp = wander ?? (pencil ? Theme.Atlas.pencilWander : Theme.Atlas.penWander)
        let colour = (color ?? inkColor).opacity(opacity)
        let points = closed ? p : AtlasGeometry.loosenEnds(p, rng: &rng)
        let path = Path.polyline(AtlasGeometry.jitter(points, amp: amp, closed: closed, noise: noise(), rng: &rng), closed: closed)
        if let fill { drawing.ink.append(.fill(path, fill)) }
        var style = StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round)
        if dashed { style.dash = AtlasGeometry.pressDashes(rng: &rng) }
        drawing.ink.append(.stroke(path, colour, style))
        if press && !dashed && !pencil && w > 0.5 {
            let pressed = StrokeStyle(lineWidth: w * 1.9, lineCap: .round, dash: AtlasGeometry.pressDashes(rng: &pressRng))
            drawing.ink.append(.stroke(path, colour.opacity(0.55), pressed))
        }
    }

    /// Paper or ink laid flat with no pen line, such as the paper inside a mountain.
    mutating func fill(_ p: [CGPoint], _ color: Color) {
        fill(.polyline(p, closed: true), color)
    }

    mutating func dot(_ c: CGPoint, radius r: CGFloat, _ color: Color) {
        drawing.ink.append(.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), color))
    }

    /// Watercolour under the ink. Skipped in pencil mode.
    mutating func wash(_ path: Path, _ color: Color, opacity: Double = 1, lineWidth: CGFloat? = nil) {
        guard !pencil else { return }
        drawing.washes.append(.init(path: path, color: color, opacity: opacity * Theme.Atlas.washOpacity, lineWidth: lineWidth))
    }

    mutating func wash(_ p: [CGPoint], _ color: Color, opacity: Double = 1) {
        wash(.polyline(p, closed: true), color, opacity: opacity)
    }

    /// Watercolour over what is already drawn, in drawing order. Skipped in pencil mode.
    mutating func washOver(_ p: [CGPoint], _ color: Color, opacity: Double = 1) {
        guard !pencil else { return }
        drawing.ink.append(.wash(.init(path: .polyline(p, closed: true), color: color,
                                       opacity: opacity * Theme.Atlas.washOpacity, lineWidth: nil)))
    }

    /// A stroke exactly through `p`, for points that already wander (road dashes, the seal's ring).
    mutating func stroke(_ p: [CGPoint], _ color: Color, width: CGFloat, closed: Bool = false) {
        drawing.ink.append(.stroke(.polyline(p, closed: closed), color, StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)))
    }

    mutating func fill(_ path: Path, _ color: Color) {
        drawing.ink.append(.fill(path, color))
    }

    /// A place name. `at` is the baseline point, as in SVG; names tilt up to 2.5 degrees either
    /// way unless `rotation` is given.
    mutating func label(_ text: String, at: CGPoint, size: CGFloat = 9.5, italic: Bool = false,
                        color: Color? = nil, opacity: Double = 1, anchor: AtlasDrawing.Anchor = .start,
                        rotation: Double? = nil, tracking: CGFloat = 0) {
        let tilt = rotation ?? (rng.next() - 0.5) * 5
        drawing.labels.append(.init(text: text, at: at, size: size, italic: italic, color: (color ?? inkColor).opacity(opacity),
                                    anchor: anchor, rotation: .degrees(tilt), tracking: tracking))
    }
}
