import SwiftUI

// Terrain, stops and map furniture, each a port of the matching block in the mockup's
// `terrain`, `realmTerrain`, `stopSvg` and `furniture`. All sizes are map units.

private typealias G = AtlasGeometry

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

extension AtlasSketch {
    // MARK: Terrain

    /// A mountain standing on (x, y): paper inside, a wash on the right flank, hatching down from the peak.
    mutating func mountain(x: CGFloat, y: CGFloat, height h: CGFloat) {
        let outline = G.mountain(x: x, y: y, height: h, peakShift: (rng.next() - 0.5) * 3)
        fill(outline, Theme.Atlas.paper)
        washOver(G.mountainFlank(outline), Theme.Atlas.mountain, opacity: 0.8)
        line(outline, width: 1.05)
        let peak = outline[2], shoulder = outline[3]
        let n = 4 + Int(rng.next() * 3)
        for j in 1...n {
            let t = CGFloat(j) / CGFloat(n + 1)
            let sx = peak.x + (shoulder.x - peak.x) * t * 1.4
            let sy = peak.y + (shoulder.y - peak.y) * t * 1.4 + h * 0.05
            if sx > x + h * 0.72 * 0.9 { continue }
            line([pt(sx, sy), pt(sx - 2 - rng.next() * 4, sy + 5 + rng.next() * h * 0.35)], width: 0.5, opacity: 0.75, wander: 0.4)
        }
    }

    mutating func hill(x: CGFloat, y: CGFloat) {
        var mound = Path()
        mound.move(to: pt(x - 9, y))
        mound.addQuadCurve(to: pt(x + 9, y), control: pt(x, y - 11))
        mound.closeSubpath()
        wash(mound, Theme.Atlas.hill, opacity: 0.6)
        line(G.hill(x: x, y: y), width: 0.9, wander: 0.5)
        line([pt(x + 2, y - 4), pt(x + 5, y - 1)], width: 0.5, wander: 0.3)
        line([pt(x + 5, y - 2.5), pt(x + 7, y - 0.5)], width: 0.5, wander: 0.3)
    }

    /// A round tree on a trunk, with a forest wash spreading under it.
    mutating func tree(x: CGFloat, y: CGFloat) {
        wash(Path(ellipseIn: CGRect(x: x - 8, y: y - 8, width: 16, height: 16)), Theme.Atlas.forest, opacity: 0.75)
        line([pt(x, y + 0.5), pt(x + rng.next() - 0.5, y + 4.5)], width: 0.7, wander: 0.2)
        let crown = G.ring(pt(x, y - 1), radius: 3.4, rng: &rng)
        fill(crown, Theme.Atlas.paper)
        line(crown, width: 0.8, wander: 0.25, press: false)
        line([pt(x + 1, y - 3), pt(x + 2.6, y - 1.6)], width: 0.45, wander: 0.15)
    }

    /// A tuft of reeds; every third one gets a pool of marsh wash.
    mutating func marsh(x: CGFloat, y: CGFloat, pool: Bool) {
        if pool { wash(Path(ellipseIn: CGRect(x: x - 12, y: y - 4, width: 24, height: 8)), Theme.Atlas.marsh, opacity: 0.7) }
        line([pt(x - 5, y), pt(x + 5, y)], width: 0.5, wander: 0.2, press: false)
        line([pt(x, y), pt(x, y - 5)], width: 0.5, wander: 0.15, press: false)
        line([pt(x - 2, y), pt(x - 3.5, y - 3.5)], width: 0.45, wander: 0.15, press: false)
        line([pt(x + 2, y), pt(x + 3.5, y - 3.5)], width: 0.45, wander: 0.15, press: false)
    }

    /// A coastline with three dashed echo lines out to sea. Positive `seaward` lies to the left
    /// of the direction the points run (east, for points running down the sheet). `sea` is the
    /// open water beyond, washed lighter than the strip along the shore.
    mutating func coast(_ p: [CGPoint], seaward: CGFloat = 1, sea: [CGPoint]? = nil) {
        if let sea { wash(sea, Theme.Atlas.sea, opacity: 0.45 * 0.9) }
        let strip = p + G.offset(p, by: 34 * seaward).reversed()
        wash(strip, Theme.Atlas.sea, opacity: 0.9)
        line(p, width: 1.3)
        for (d, w, op) in [(5.0, 0.8, 0.75), (10.0, 0.65, 0.55), (16.0, 0.55, 0.38)] {
            line(G.offset(p, by: d * seaward), width: w, opacity: op, dashed: true)
        }
    }

    /// A lake with two dashed rings inside it, `rx` by `ry` before the noise.
    mutating func lake(_ c: CGPoint, rx: CGFloat, ry: CGFloat) {
        let n = noise()
        let shore = stride(from: CGFloat(0), to: 6.3, by: 0.3).map { a in
            let r = 1 + 0.3 * n(cos(a) * 2 + 5, sin(a) * 2)
            return pt(c.x + cos(a) * rx * r, c.y + sin(a) * ry * r)
        }
        wash(shore, Theme.Atlas.sea)
        line(shore, width: 1.2, closed: true)
        for (k, scale) in [0.78, 0.58].enumerated() {
            let ring = shore.map { pt(c.x + ($0.x - c.x) * scale, c.y + ($0.y - c.y) * scale) }
            line(ring, width: 0.6, opacity: 0.7 - Double(k) * 0.2, closed: true, dashed: true)
        }
    }

    /// A river: a wash along it and a doubled pen line.
    mutating func river(_ p: [CGPoint]) {
        let n = noise()
        let course = G.resample(p, step: 6).map { q in
            pt(q.x + 5 * (n(q.x * 0.05, q.y * 0.05) - 0.5), q.y + 3 * (n(q.y * 0.05, q.x * 0.05) - 0.5))
        }
        wash(.polyline(course), Theme.Atlas.sea, lineWidth: 5)
        line(course, width: 0.9)
        line(course.map { pt($0.x + 1.8, $0.y + 1.4) }, width: 0.5, opacity: 0.8, press: false)
    }

    /// An island with a gold wash, a dashed shoal around it and a small peak.
    mutating func isle(_ c: CGPoint, radius r: CGFloat) {
        let n = noise()
        func outline(_ r: CGFloat) -> [CGPoint] {
            stride(from: CGFloat(0), to: 6.28, by: 0.25).map { a in
                let rr = r * (1 + 0.5 * (n(cos(a) * 1.5 + c.x, sin(a) * 1.5 + c.y) - 0.5))
                return pt(c.x + cos(a) * rr * 1.3, c.y + sin(a) * rr)
            }
        }
        let shore = outline(r)
        wash(shore, Theme.Atlas.isles, opacity: 0.7)
        line(shore, width: 1.1, closed: true)
        line(outline(r + 4), width: 0.55, opacity: 0.6, closed: true, dashed: true)
        line([pt(c.x - r * 0.3, c.y - 2), pt(c.x, c.y - r * 0.55), pt(c.x + r * 0.3, c.y - 2)], width: 0.8, wander: 0.4)
    }

    /// Two ripples on open water.
    mutating func waves(at c: CGPoint) {
        line([pt(c.x - 8, c.y), pt(c.x - 4, c.y - 1.5), pt(c.x, c.y), pt(c.x + 4, c.y - 1.5), pt(c.x + 8, c.y)], width: 0.6, wander: 0.2)
        line([pt(c.x + 6, c.y + 5), pt(c.x + 10, c.y + 3.5), pt(c.x + 14, c.y + 5)], width: 0.6, wander: 0.2)
    }

    // MARK: Roads

    /// The road walked so far, dashed by hand in red ink.
    mutating func road(_ p: [CGPoint], weight: CGFloat = 1) {
        let wandering = G.jitter(p, amp: Theme.Atlas.penWander * 0.7, closed: false, step: 1.2, noise: noise(), rng: &rng)
        for dash in G.handDashes(wandering, rng: &rng) {
            stroke(dash, Theme.Atlas.road, width: weight * 1.6 * (0.8 + rng.next() * 0.45))
        }
    }

    /// The road still ahead: a dotted pencil track.
    mutating func pencilRoad(_ p: [CGPoint]) {
        let points = G.resample(p, step: 1)
        var run: CGFloat = 0
        for (a, b) in zip(points, points.dropFirst()) {
            run += hypot(b.x - a.x, b.y - a.y)
            if run > 4.5 + rng.next() * 1.5 {
                run = 0
                dot(pt(b.x + rng.next() - 0.5, b.y + rng.next() - 0.5), radius: 0.6 + rng.next() * 0.5, Theme.Atlas.pencil)
            }
        }
    }

    // MARK: Stops

    /// A castle: inked with its province's pigment washed under it and a flag, or pencilled.
    /// `door` is for the small castles that mark solved stops.
    mutating func castle(at c: CGPoint, scale s: CGFloat, pigment: Color, inked: Bool, door: Bool = false) {
        let inked = inked && !pencil
        let colour = inked ? inkColor : Theme.Atlas.pencil
        let blob = G.blob(c, radius: 10.4 * s, k: 0.18, noise: noise())
        if inked { washOver(blob, pigment, opacity: 1.1) }
        line(G.place(G.castle, at: c, scale: s), width: inked ? 0.9 : 0.55, color: colour, wander: 0.3,
             closed: true, fill: Theme.Atlas.paper, press: inked)
        if door {
            line([pt(c.x - 1.1, c.y + 4.6), pt(c.x - 1.1, c.y + 2), pt(c.x, c.y + 1), pt(c.x + 1.1, c.y + 2), pt(c.x + 1.1, c.y + 4.6)],
                 width: 0.6, color: colour, wander: 0.15)
        }
        let top = pt(c.x, c.y - 13 * s)
        line([pt(c.x, c.y - 9.5 * s), top], width: 0.6, color: colour, wander: 0.1)
        if inked {
            let flag = [top, pt(top.x + 4 * s, top.y + 1.2), pt(top.x, top.y + 2.5)]
            fill(flag, pigment)
            fill(flag, inkColor.opacity(0.25))
        }
    }

    /// The red wax seal on the current stop: a lumpy blob with three drips, a crown pressed into
    /// it and a gold ring around it. The mockup draws it at radius 14 on a province and 9 on the realm.
    mutating func seal(at c: CGPoint, radius r: CGFloat = 14) {
        var wax = G.blob(c, radius: r, k: 0.1, noise: noise())
        for _ in 0..<3 {
            let a = rng.next() * 6.28
            wax.insert(pt(c.x + cos(a) * r * 17 / 14, c.y + sin(a) * r * 17 / 14), at: min(wax.count, Int(a / 0.3) + 1))
        }
        fill(wax, Theme.Atlas.road)
        if r >= 12 { stroke(G.ring(c, radius: r * 10 / 14, rng: &rng), Theme.Atlas.sealMark.opacity(0.45), width: 0.9) }
        let crown = G.jitter(G.place(G.sealCrown, at: c, scale: r / 14), amp: 0.25, closed: true, step: 1.5, noise: noise(), rng: &rng)
        fill(crown, Theme.Atlas.sealMark)
        line(G.ring(c, radius: r * 1.5, rng: &rng), width: 1.1, color: Theme.Atlas.sealRing, wander: 0.5, press: false)
    }

    /// One stop on a province road and its name. Names sit on the side away from the sheet's
    /// middle; stops ahead read "Uncharted" until the traveller reaches them.
    mutating func stop(_ state: Journey.StopState, at c: CGPoint, name: String, pigment: Color) {
        switch state {
        case .solved: castle(at: c, scale: 1.15, pigment: pigment, inked: true, door: true)
        case .skipped: line(G.ring(c, radius: 5, rng: &rng), width: 1, wander: 0.3, press: false)
        case .ahead: line(G.ring(c, radius: 4, rng: &rng), width: 0.6, color: Theme.Atlas.pencil, wander: 0.3, press: false)
        case .current: seal(at: c)
        }
        let right = c.x < 150
        let anchor: AtlasDrawing.Anchor = right ? .start : .end
        switch state {
        case .ahead:
            label("Uncharted", at: pt(c.x + (right ? 15 : -15), c.y + 3.5), italic: true, color: Theme.Atlas.pencil, anchor: anchor)
        case .current:
            label(name, at: pt(c.x + (right ? 26 : -26), c.y + 4.5), size: 13, color: Theme.Atlas.road, anchor: anchor)
        default:
            label(name, at: pt(c.x + (right ? 15 : -15), c.y + 3.5), anchor: anchor)
        }
    }

    // MARK: Furniture

    /// The ribbon banner with the sheet's title: a gold-washed body and forked tails.
    mutating func cartouche(at c: CGPoint, title: String, subtitle: String) {
        func at(_ p: [(CGFloat, CGFloat)]) -> [CGPoint] { p.map { pt(c.x + $0.0, c.y + $0.1) } }
        for sx: CGFloat in [-1, 1] {
            line(at([(sx * 58, -10), (sx * 84, -13), (sx * 74, -1), (sx * 85, 11), (sx * 58, 8)]), closed: true, fill: Theme.Atlas.paper)
            line(at([(sx * 58, 8), (sx * 64, 13), (sx * 64, 2)]), width: 0.6, closed: true, fill: inkColor)
        }
        let body = at([(-64, -22), (-30, -25), (0, -22), (30, -25), (64, -22), (64, 10), (30, 7), (0, 10), (-30, 7), (-64, 10)])
        line(body, width: 1.2, closed: true, fill: Theme.Atlas.paper)
        washOver(body, Theme.Atlas.isles, opacity: 0.35)
        line(at([(-60, -18), (-30, -21), (0, -18), (30, -21), (60, -18)]), width: 0.5, opacity: 0.7)
        label(title, at: pt(c.x, c.y - 2), size: 18, anchor: .middle, rotation: -1)
        label(subtitle, at: pt(c.x, c.y + 7), size: 8, italic: true, opacity: 0.8, anchor: .middle, rotation: -1)
    }

    /// A compass rose: two rings, four inked-and-plain points with shading ticks, four small diagonals.
    mutating func compass(at c: CGPoint) {
        line(G.ring(c, radius: 20, rng: &rng), width: 0.8)
        line(G.ring(c, radius: 16, rng: &rng), width: 0.4, press: false)
        func turned(_ degrees: CGFloat, _ p: [(CGFloat, CGFloat)]) -> [CGPoint] {
            let r = degrees * .pi / 180
            return p.map { pt(c.x + $0.0 * cos(r) - $0.1 * sin(r), c.y + $0.0 * sin(r) + $0.1 * cos(r)) }
        }
        for a: CGFloat in [0, 90, 180, 270] {
            line(turned(a, [(0, -27), (4, -4), (0, 0)]), width: 0.7, wander: 0.3, closed: true, fill: inkColor)
            line(turned(a, [(0, -27), (-4, -4), (0, 0)]), width: 0.7, wander: 0.3, closed: true, fill: Theme.Atlas.paper)
            for k in 1..<5 {
                let k = CGFloat(k)
                line(turned(a, [(-0.6, -5 - k * 4.2), (-3.4 + k * 0.6, -3 - k * 4.2)]), width: 0.35, wander: 0.1, press: false)
            }
        }
        for a: CGFloat in [45, 135, 225, 315] {
            line(turned(a, [(0, -16), (2.5, -3), (-2.5, -3)]), width: 0.6, wander: 0.25, closed: true, fill: Theme.Atlas.paper)
        }
        label("N", at: pt(c.x, c.y - 30), size: 10, anchor: .middle, rotation: 0)
    }

    /// A two-sailed ship riding on two ripples.
    mutating func ship(at c: CGPoint) {
        func at(_ p: [(CGFloat, CGFloat)]) -> [CGPoint] { p.map { pt(c.x + $0.0, c.y + $0.1) } }
        line(at([(-14, 0), (14, 0), (9, 6), (-9, 6)]), width: 0.9, wander: 0.3, closed: true, fill: Theme.Atlas.paper)
        line(at([(0, 0), (0, -22)]), width: 0.9, wander: 0.2)
        line(at([(1, -21), (7, -15), (8, -9), (1, -3)]), width: 0.8, wander: 0.3, closed: true, fill: Theme.Atlas.paper)
        line(at([(-1, -18), (-6, -13), (-6, -8), (-1, -4)]), width: 0.8, wander: 0.3, closed: true, fill: Theme.Atlas.paper)
        line(at([(-20, 10), (-16, 8.5), (-12, 10), (-8, 8.5), (-4, 10)]), width: 0.6, wander: 0.2)
        line(at([(6, 11), (10, 9.5), (14, 11)]), width: 0.6, wander: 0.2)
    }

    /// Three coils of a sea serpent and its head, for the sea crossing.
    mutating func serpent(at c: CGPoint) {
        for (dx, dy) in [(0.0, 0.0), (11.0, 1.0), (21.0, 0.0)] {
            let x = c.x + dx, y = c.y + dy
            line([pt(x - 4, y), pt(x - 3, y - 4), pt(x, y - 5.5), pt(x + 3, y - 4), pt(x + 4, y)], width: 0.9, wander: 0.2)
        }
        line([pt(c.x - 8, c.y), pt(c.x - 10, c.y - 6), pt(c.x - 8, c.y - 9), pt(c.x - 4, c.y - 9), pt(c.x - 3, c.y - 7)], width: 0.9, wander: 0.2)
        line([pt(c.x - 12, c.y + 2), pt(c.x - 6, c.y + 1.5)], width: 0.4, wander: 0.2)
        line([pt(c.x + 26, c.y + 1), pt(c.x + 31, c.y + 1.5)], width: 0.4, wander: 0.2)
    }
}
