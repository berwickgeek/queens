import SwiftUI

/// The realm sheet: twelve provinces on two shores with the sea crossing between them, as in the
/// mockup's realm view. The terrain is drawn twice, inked and pencilled, and `AtlasSheet` shows
/// ink up to the traveller; the road, castles, names and furniture are drawn live from progress.
enum RealmSheet {
    private typealias L = Journey.Layout
    private typealias R = RealmGeometry

    struct Terrain {
        var ink: AtlasDrawing
        var pencil: AtlasDrawing
    }

    /// Both terrain drawings for a realm, built once per launch off the main thread.
    @MainActor static func terrain(size: Int) async -> Terrain {
        if let cached = cache[size] { return cached }
        let built = await Task.detached(priority: .userInitiated) {
            Terrain(ink: terrain(size: size, pencil: false), pencil: terrain(size: size, pencil: true))
        }.value
        cache[size] = built
        return built
    }

    @MainActor private static var cache: [Int: Terrain] = [:]

    private static func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    // MARK: Terrain

    /// Coasts, borders, islands and each province's country. Placement draws from its own
    /// generator so the pencilled and inked sheets put every feature in the same place.
    static func terrain(size: Int, pencil: Bool) -> AtlasDrawing {
        var t = AtlasSketch(seed: size * 100 + 1, pencil: pencil)
        t.wash(R.sea, Theme.Atlas.sea, opacity: 0.45 * 0.9)
        for shore in 0..<2 {
            t.coast(R.coastline(shore))
            for isle in L.isles {
                t.isle(pt(isle.x, L.bandBottom(shore * Journey.provincesPerShore + Journey.provincesPerShore - 1) + isle.dy), radius: isle.r)
            }
            var place = AtlasRandom(seed: size * 100 + shore * 7 + 21)
            country(&t, shore: shore, place: &place)
        }
        return t.drawing
    }

    /// One shore's five land provinces, south to north: fields, forest, marsh, hills, mountains.
    /// Coordinates are the mockup's, moved down by the shore's shift.
    private static func country(_ t: inout AtlasSketch, shore: Int, place r: inout AtlasRandom) {
        let dy = R.shift(shore)
        let first = shore * Journey.provincesPerShore
        func coast(_ y: CGFloat) -> CGFloat { R.coastX(y + dy) }
        func clear(_ x: CGFloat, _ y: CGFloat, band k: Int) -> Bool { !R.underLabel(x, y + dy, index: first + k) }

        // Borders between the land provinces: a dotted and dashed line from the west edge to the coast.
        for k in 0..<4 {
            let i = first + k, y = L.bandBottom(i) - L.band, phase = CGFloat(i)
            let border = stride(from: CGFloat(-10), through: R.coastX(y), by: 8).map { (x: CGFloat) -> CGPoint in
                let wave: CGFloat = 5 * sin(x * 0.06 + phase * 2)
                let wobble: CGFloat = 6 * (R.noise(x * 0.03, 30 + phase) - 0.5)
                return pt(x, y + wave + wobble)
            }
            t.line(border, width: 0.9, press: false, dash: [5, 3, 1.2, 3])
        }

        t.lake(pt(70, 282 + dy), rx: 33, ry: 22)
        t.river([(92, 212), (82, 239), (78, 263), (76, 282), (110, 306), (150, 328), (196, 356), (240, 369)]
            .map { pt($0.0, $0.1 + dy) } + [pt(coast(378), 378 + dy)])

        // Mountains (band 4), with the fire peak in among them.
        var peaks: [(x: CGFloat, y: CGFloat, h: CGFloat, fire: Bool)] = [(46, 198, 34, true)]
        for row in 0..<3 {
            for col in 0..<9 {
                let x = 14 + CGFloat(col) * 28 + CGFloat(row % 2) * 14 + r.next() * 6
                let y = 183 + CGFloat(row) * 19 + r.next() * 5
                let h = 18 + r.next() * 12
                if x >= coast(y) - 24 || R.nearRoad(x, y + dy - 10, 24) || (x < 116 && y > 216) { continue }
                peaks.append((x, y, h, false))
            }
        }
        for peak in peaks.sorted(by: { $0.y < $1.y }) {
            if peak.fire {
                let top = pt(peak.x, peak.y + dy - peak.h)
                t.wash(AtlasGeometry.blob(top, radius: 9, k: 0.3, noise: R.noise), Theme.Atlas.fire, opacity: 0.8)
                t.mountain(x: peak.x, y: peak.y + dy, height: peak.h)
                t.line([pt(top.x - 1, top.y - 4), pt(top.x - 4, top.y - 12), pt(top.x + 1, top.y - 20)], width: 0.6, opacity: 0.7, press: false)
                t.line([pt(top.x + 3, top.y - 5), pt(top.x + 2, top.y - 13), pt(top.x + 7, top.y - 19)], width: 0.5, opacity: 0.55, press: false)
            } else {
                t.mountain(x: peak.x, y: peak.y + dy, height: peak.h)
            }
        }

        // Hills (band 3), clear of the lake.
        for _ in 0..<26 {
            let x = 20 + r.next() * 260, y = 258 + r.next() * 73
            let inLake = pow((x - 70) / 42, 2) + pow((y - 282) / 30, 2) < 1
            if x > coast(y) - 14 || R.nearRoad(x, y + dy, 18) || inLake || !clear(x, y, band: 3) { continue }
            t.hill(x: x, y: y + dy)
        }

        // Marsh (band 2).
        var tufts = 0
        for _ in 0..<60 {
            let x = 16 + r.next() * 270, y = 341 + r.next() * 72
            if x > coast(y) - 12 || R.nearRoad(x, y + dy, 15) { continue }
            t.marsh(x: x, y: y + dy, pool: tufts % 3 == 0)
            tufts += 1
        }

        // Forest (band 1), where the noise says trees grow.
        for y in stride(from: CGFloat(428), through: 510, by: 9) {
            for x in stride(from: CGFloat(10), through: 290, by: 9) {
                let jx = x + r.next() * 5, jy = y + r.next() * 5
                if R.noise(jx / 36, (jy + dy) / 36) < 0.5 || R.nearRoad(jx, jy + dy, 16) || jx > coast(jy) - 12 || !clear(jx, jy, band: 1) { continue }
                t.tree(x: jx, y: jy + dy)
            }
        }

        // Fields (band 0): washed plots, outlined and hatched.
        let crops = [Theme.Atlas.hill, Theme.Atlas.isles, Theme.Atlas.forest, Theme.region(2), Theme.region(1)]
        var plots = 0
        for _ in 0..<34 {
            let x = 16 + r.next() * 260, y = 520 + r.next() * 76
            let w = 16 + r.next() * 12, h = 10 + r.next() * 6, skew = (r.next() - 0.5) * 6
            if x + w > coast(y) - 10 || R.nearRoad(x + w / 2, y + dy + h / 2, 20) || !clear(x + w / 2, y + h / 2, band: 0) { continue }
            let y0 = y + dy
            let plot = [pt(x, y0), pt(x + w, y0 + skew), pt(x + w, y0 + h + skew), pt(x, y0 + h)]
            t.wash(plot, crops[plots % crops.count], opacity: 0.55)
            t.line(plot, width: 0.7, closed: true, press: false)
            for d in stride(from: CGFloat(3.2), to: h, by: 3.2) {
                t.line([pt(x + 1, y0 + d), pt(x + w - 1, y0 + d + skew)], width: 0.35, opacity: 0.6, wander: 0.2, press: false)
            }
            plots += 1
        }
    }

    // MARK: Live

    /// The road, castles, province names and the sheet's furniture for the traveller's progress.
    /// Always inked: a pencilled province still shows its name and the dotted road ahead.
    static func live(size: Int, states: [Journey.StopState]) -> AtlasDrawing {
        var s = AtlasSketch(seed: size * 100 + 50)
        let provinces = Journey.provinceStates(states)
        let route = R.route(size: size, stops: states.count)

        if let current = states.firstIndex(of: .current) {
            let split = route.stops[current] + 1
            s.road(Array(route.points[..<split]), weight: 0.85)
            s.pencilRoad(Array(route.points[(split - 1)...]))
        } else {
            s.road(route.points, weight: 0.85)
        }

        func stop(_ i: Int) -> CGPoint { route.points[route.stops[i]] }
        for (i, state) in states.enumerated() where state == .skipped {
            let ring = AtlasGeometry.ring(stop(i), radius: 3.6, rng: &s.rng)
            s.line(ring, width: 0.8, wander: 0.2, press: false)
        }

        for (p, state) in provinces.enumerated() {
            let province = Journey.Province(size: size, index: p)
            let slice = states[(p * Journey.stopsPerProvince)..<min(states.count, (p + 1) * Journey.stopsPerProvince)]
            if !province.isles, let last = slice.indices.last {
                let c = stop(last), side: CGFloat = c.x < 150 ? 1 : -1
                s.castle(at: pt(c.x + side * 22, c.y + 2), scale: 1.25, pigment: Theme.region(p), inked: state == .finished)
            }
            let solved = slice.filter { $0 == .solved }.count
            let at = R.labelCentre(p)
            let name: Color = switch state {
            case .current: Theme.Atlas.road
            case .finished, .visited: Theme.Atlas.ink
            case .next, .uncharted: Theme.Atlas.pencil
            }
            let tilt = (s.rng.next() - 0.5) * 3
            s.label(province.name.uppercased(), at: at, size: state == .current ? 13.5 : 12, color: name,
                    anchor: .middle, rotation: tilt, tracking: 2.2)
            let info: (String, Color) = switch state {
            case .finished: ("\(slice.count) of \(slice.count), crowned", Theme.Atlas.ink)
            case .current, .visited: ("\(solved) of \(slice.count)", Theme.Atlas.ink)
            case .next: ("next", Theme.Atlas.pencil)
            case .uncharted: ("Uncharted", Theme.Atlas.pencil)
            }
            s.label(info.0, at: pt(at.x, at.y + 13), size: 8.5, italic: true, color: info.1, opacity: 0.85, anchor: .middle, rotation: 0)
        }

        if let current = states.firstIndex(of: .current) {
            let c = stop(current)
            s.seal(at: c, radius: 9)
            s.label("No. \(current + 1)", at: pt(c.x + 18, c.y + 4), size: 10, color: Theme.Atlas.road, rotation: 0)
        }

        s.cartouche(at: pt(98, 52), title: Naming.realm(size).name, subtitle: "a realm in twelve provinces")
        s.compass(at: pt(352, 1230))
        s.ship(at: pt(250, 690))
        s.serpent(at: pt(90, 710))
        for c in [pt(352, 420), pt(346, 980), pt(196, 742), pt(360, 600), pt(140, 668)] { s.waves(at: c) }
        return s.drawing
    }

    /// Ink runs up to the current stop, or over the whole sheet once the realm is crowned.
    static func boundary(size: Int, states: [Journey.StopState]) -> CGFloat {
        R.boundary(size: size, states: states)
    }
}
