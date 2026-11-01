import SwiftUI

/// A province sheet: twenty stops climbing a road from the south edge to a castle, the coast down
/// the east side, as in the mockup's province view. The terrain is drawn twice, inked and
/// pencilled, and `AtlasSheet` shows ink up to the traveller; the road, stops, castle and
/// furniture are drawn live from progress.
enum ProvinceSheet {
    private typealias P = ProvinceGeometry

    struct Terrain {
        var ink: AtlasDrawing
        var pencil: AtlasDrawing
    }

    /// Both terrain drawings for a province, built once per launch off the main thread.
    @MainActor static func terrain(_ province: Journey.Province) async -> Terrain {
        if let cached = cache[province] { return cached }
        let built = await Task.detached(priority: .userInitiated) {
            Terrain(ink: terrain(province, pencil: false), pencil: terrain(province, pencil: true))
        }.value
        cache[province] = built
        return built
    }

    @MainActor private static var cache: [Journey.Province: Terrain] = [:]

    private static func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private static func seed(_ province: Journey.Province) -> Int { province.size * 1000 + province.index * 10 }

    // MARK: Terrain

    /// Coast, lake, mountains along the top, hills and forest. Placement draws from its own
    /// generator so the pencilled and inked sheets put every feature in the same place.
    static func terrain(_ province: Journey.Province, pencil: Bool) -> AtlasDrawing {
        var t = AtlasSketch(seed: seed(province) + 1, pencil: pencil)
        var r = AtlasRandom(seed: seed(province) + 9)
        let stops = P.stops(province)
        let lake = P.lake(stops)
        func near(_ x: CGFloat, _ y: CGFloat, _ d: CGFloat) -> Bool { P.near(x, y, d, stops: stops) }

        t.coast(P.coastline, sea: P.sea)
        t.lake(lake, rx: 26 * 1.3, ry: 26)

        // Mountains: three staggered rows across the top, clear of the road, castle and title.
        var peaks: [(x: CGFloat, y: CGFloat, h: CGFloat)] = []
        for row in 0..<3 {
            for k in 0..<7 {
                let x = 22 + CGFloat(k) * 24 + CGFloat(row % 2) * 12 + r.next() * 6
                let y = 82 + CGFloat(row) * 24 + r.next() * 6
                let h = 24 + r.next() * 16
                if near(x, y - 12, 30) || P.underCartouche(x, y - h, stops: stops) { continue }
                peaks.append((x, y, h))
            }
        }
        for peak in peaks.sorted(by: { $0.y < $1.y }) { t.mountain(x: peak.x, y: peak.y, height: peak.h) }

        for _ in 0..<22 {
            let x = 20 + r.next() * 250, y = 200 + r.next() * 360
            if near(x, y, 24) || P.inLake(x, y, lake: lake) || x > P.coastX(y) - 14 { continue }
            t.hill(x: x, y: y)
        }

        // Forest, where the noise says trees grow.
        for y in stride(from: CGFloat(40), to: 640, by: 9) {
            for x in stride(from: CGFloat(10), to: 285, by: 9) {
                let jx = x + r.next() * 5, jy = y + r.next() * 5
                if P.noise(jx / 40, jy / 40) < 0.58 || near(jx, jy, 22) || P.inLake(jx, jy, lake: lake)
                    || jx > P.coastX(jy) - 10 || (jy < 165 && jx < 200) || P.underCartouche(jx, jy, stops: stops) { continue }
                t.tree(x: jx, y: jy)
            }
        }
        return t.drawing
    }

    // MARK: Live

    /// The road, stops, castle and furniture for this province's stop states (one per puzzle on
    /// its road, in order). Always inked: stops ahead are pencil rings and read "Uncharted".
    /// While `leg` is being walked, its road and both its stops are left out for `TravelOverlay`
    /// to draw. Each road segment, stop and the castle draws from its own seed, so the overlay's
    /// pieces match this drawing exactly once the leg is walked.
    static func live(_ province: Journey.Province, states: [Journey.StopState], travelling leg: ProvinceGeometry.Leg? = nil) -> AtlasDrawing {
        var s = AtlasSketch(seed: seed(province) + 50)
        let stops = P.stops(province, count: states.count)
        guard !stops.isEmpty else { return s.drawing }
        let finished = states.allSatisfy { $0 == .solved }

        // Road segments below the stop reached are inked; the one to the castle only once it is.
        let reached = if let leg { leg.from ?? 0 }
            else if let current = states.firstIndex(of: .current) { current }
            else if states.allSatisfy({ $0 == .ahead }) { 0 }
            else { stops.count - 1 }
        for i in 0..<(stops.count - 1) {
            s.append(roadSegment(province, i, stops: stops, inked: i < reached))
        }
        if finished && leg == nil { s.append(roadSegment(province, stops.count - 1, stops: stops, inked: true)) }

        s.append(castle(province, stops: stops, inked: finished && leg == nil))
        for (j, state) in states.enumerated() where j != leg?.from && j != leg?.to {
            s.append(stop(province, j, state: state, at: stops[j]))
        }

        s.cartouche(at: P.cartouche(stops), title: province.name, subtitle: "the \(ordinals[province.index]) Province")
        s.compass(at: pt(345, 300))
        s.serpent(at: pt(344, 392))
        s.ship(at: pt(338, 470))
        return s.drawing
    }

    /// Road segment `i`, from stop `i` to the next, or to the castle from the last stop.
    private static func roadSegment(_ province: Journey.Province, _ i: Int, stops: [CGPoint], inked: Bool) -> AtlasDrawing {
        var s = AtlasSketch(seed: seed(province) + 200 + i)
        let path = P.path(P.Leg(from: i, to: i + 1 < stops.count ? i + 1 : nil), stops: stops)
        if inked { s.road(path) } else { s.pencilRoad(path) }
        return s.drawing
    }

    private static func castle(_ province: Journey.Province, stops: [CGPoint], inked: Bool) -> AtlasDrawing {
        var s = AtlasSketch(seed: seed(province) + 99)
        s.castle(at: P.castle(stops), scale: 1.6, pigment: Theme.region(province.index), inked: inked)
        return s.drawing
    }

    private static func stop(_ province: Journey.Province, _ j: Int, state: Journey.StopState, at c: CGPoint) -> AtlasDrawing {
        var s = AtlasSketch(seed: seed(province) + 100 + j)
        let name = Naming.puzzleName(size: province.size, number: province.numbers.lowerBound + j)
        s.stop(state, at: c, name: name, pigment: Theme.region(province.index))
        return s.drawing
    }

    // MARK: Travel

    /// What `TravelOverlay` moves, each drawn from the same seed as in `live`.
    struct TravelPieces {
        /// The leg's red road, and the line it follows for the reveal and the walking seal.
        var road = AtlasDrawing()
        var path: [CGPoint] = []
        var from: CGPoint?
        /// At `from`: the seal and its red name, then the castle and ink name that replace them.
        var seal = AtlasDrawing()
        var sealName = AtlasDrawing()
        var solved = AtlasDrawing()
        var solvedName = AtlasDrawing()
        var to: CGPoint?
        /// At `to`: the pencil ring and "Uncharted", then the seal and the name written on.
        var ahead = AtlasDrawing()
        var arrived = AtlasDrawing()
        var arrivedName = AtlasDrawing()
        /// Where the name is written, in map units, for the clip that reveals it.
        var nameBox = CGRect.zero
        /// The inked castle, when the leg finishes the province.
        var castle: AtlasDrawing?
    }

    static func pieces(_ province: Journey.Province, count: Int, leg: ProvinceGeometry.Leg) -> TravelPieces {
        let stops = P.stops(province, count: count)
        var p = TravelPieces()
        if let from = leg.from {
            p.road = roadSegment(province, from, stops: stops, inked: true)
            p.path = P.path(leg, stops: stops)
            p.from = stops[from]
            (p.seal, p.sealName) = split(stop(province, from, state: .current, at: stops[from]))
            (p.solved, p.solvedName) = split(stop(province, from, state: .solved, at: stops[from]))
        }
        if let to = leg.to {
            let c = stops[to]
            p.to = c
            p.ahead = stop(province, to, state: .ahead, at: c)
            (p.arrived, p.arrivedName) = split(stop(province, to, state: .current, at: c))
            // AtlasSketch.stop sets the seal's name 26 out at size 13; Fell runs about 7.6 a letter there.
            let name = Naming.puzzleName(size: province.size, number: province.numbers.lowerBound + to)
            let width = CGFloat(name.count) * 7.6 + 8
            let x = c.x < 150 ? c.x + 22 : c.x - 26 - width
            p.nameBox = CGRect(x: x, y: c.y - 16, width: width + 4, height: 28)
        } else {
            p.castle = castle(province, stops: stops, inked: true)
        }
        return p
    }

    /// A drawing's marks and its names, apart.
    private static func split(_ d: AtlasDrawing) -> (AtlasDrawing, AtlasDrawing) {
        (AtlasDrawing(washes: d.washes, ink: d.ink), AtlasDrawing(labels: d.labels))
    }

    private static let ordinals = ["First", "Second", "Third", "Fourth", "Fifth", "Sixth",
                                   "Seventh", "Eighth", "Ninth", "Tenth", "Eleventh", "Twelfth"]

    static func boundary(_ province: Journey.Province, states: [Journey.StopState]) -> CGFloat {
        P.boundary(province, states: states)
    }
}
