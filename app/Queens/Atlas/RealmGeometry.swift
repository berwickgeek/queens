import Foundation

/// Where things sit on the realm sheet, ported from the mockup's `realmTerrain`. The mockup drew
/// one shore of six provinces on a 720 sheet; the realm sheet has two shores, so each reuses the
/// mockup's numbers moved down by `shift`. Pure functions, so they can be checked without UI.
enum RealmGeometry {
    private typealias L = Journey.Layout

    /// The mockup's `f77`: the noise that shapes the coasts, the borders and where forests grow.
    static let noise = AtlasNoise(seed: 77)

    /// How far a shore sits below the mockup's one: 700 for the near shore (0), 0 for the far (1).
    static func shift(_ shore: Int) -> CGFloat {
        L.bandBottom(shore * Journey.provincesPerShore) - 605
    }

    /// The east coast's x at sheet height `y`, about 270 to 330.
    static func coastX(_ y: CGFloat) -> CGFloat {
        298 + 18 * sin(y * 0.016) + 24 * (noise(5, y * 0.02) - 0.5)
    }

    /// The north coast of a shore, below its isles.
    static func northY(_ x: CGFloat, shore: Int) -> CGFloat {
        152 + 10 * sin(x * 0.04) + 12 * (noise(x * 0.02, 11 + 5 * CGFloat(shore)) - 0.5) + shift(shore)
    }

    /// The far shore's south coast, facing the sea crossing, at least 9 below its first stop.
    static func southY(_ x: CGFloat) -> CGFloat {
        622 + 6 * sin(x * 0.05) + 8 * (noise(x * 0.02, 23) - 0.5)
    }

    /// A shore's coastline: west to east along the north coast, down the east coast, and on the
    /// far shore back west along the south coast. The sea is always on the left of the direction
    /// of travel, so `AtlasSketch.coast` takes it with `seaward` 1.
    static func coastline(_ shore: Int) -> [CGPoint] {
        let dy = shift(shore)
        let top = 174 + dy
        let x0 = coastX(top)
        var c = stride(from: CGFloat(-20), through: x0 - 20, by: 10).map { CGPoint(x: $0, y: northY($0, shore: shore)) }
        c.append(CGPoint(x: x0 - 8, y: 162 + dy))
        let bottom: CGFloat = shore == 0 ? L.realmHeight + 20 : 600
        c += stride(from: top, through: bottom, by: 10).map { CGPoint(x: coastX($0), y: $0) }
        if shore == 1 {
            let x1 = coastX(bottom)
            c.append(CGPoint(x: x1 - 10, y: 612))
            c += stride(from: x1 - 22, through: -20, by: -10).map { CGPoint(x: $0, y: southY($0)) }
        }
        return c
    }

    /// All open water as one outline: the sheet's edge with both shores cut out of it.
    static var sea: [CGPoint] {
        [CGPoint(x: -20, y: -20), CGPoint(x: L.width + 20, y: -20), CGPoint(x: L.width + 20, y: L.realmHeight + 20)]
            + coastline(0).reversed() + coastline(1).reversed()
    }

    /// Whether (x, y) is within `r` of the winding road, so terrain stays off it.
    static func nearRoad(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> Bool {
        stride(from: y - r, through: y + r, by: 4).contains { hypot(L.roadX($0) - x, $0 - y) < r }
    }

    /// The baseline centre of a province's name: across the band from the road, or under the
    /// islands for an isles province. Its state line sits 13 below.
    static func labelCentre(_ index: Int) -> CGPoint {
        let y0 = L.bandBottom(index)
        if index % Journey.provincesPerShore == Journey.provincesPerShore - 1 {
            return CGPoint(x: 246, y: y0 - 21)
        }
        let ym = y0 - L.band / 2
        return CGPoint(x: L.roadX(ym) < 150 ? 222 : 82, y: ym + 3)
    }

    /// Whether (x, y) falls on a province's name or state line, so terrain leaves room for them.
    static func underLabel(_ x: CGFloat, _ y: CGFloat, index: Int) -> Bool {
        let c = labelCentre(index)
        return abs(x - c.x) < 60 && y > c.y - 16 && y < c.y + 18
    }

    /// The road in travel order and the index of each stop on it. Land provinces follow the
    /// winding road; the crossings to and between islands bow like a province road.
    static func route(size: Int, stops count: Int) -> (points: [CGPoint], stops: [Int]) {
        func stop(_ i: Int) -> CGPoint {
            L.realmStop(Journey.Province(size: size, index: i / Journey.stopsPerProvince), i % Journey.stopsPerProvince)
        }
        func onIsles(_ i: Int) -> Bool { (i / Journey.stopsPerProvince) % Journey.provincesPerShore == Journey.provincesPerShore - 1 }
        guard count > 0 else { return ([], []) }
        let start = L.bandBottom(0)
        var points = [CGPoint(x: L.roadX(start), y: start)]
        var stops: [Int] = []
        for i in 0..<count {
            let a = points[points.count - 1], b = stop(i)
            if i > 0 && (onIsles(i) || onIsles(i - 1)) {
                points += AtlasGeometry.roadSegment(a, b, index: i)
            } else {
                points += (1...3).map { k in
                    let y = a.y + (b.y - a.y) * CGFloat(k) / 3
                    return k == 3 ? b : CGPoint(x: L.roadX(y), y: y)
                }
            }
            stops.append(points.count - 1)
        }
        return (points, stops)
    }

    /// Where the ink meets the pencil: just above the current stop, or past the top of the
    /// sheet once every stop is solved.
    static func boundary(size: Int, states: [Journey.StopState]) -> CGFloat {
        guard let current = states.firstIndex(of: .current) else { return states.isEmpty ? L.realmHeight : -40 }
        let province = Journey.Province(size: size, index: current / Journey.stopsPerProvince)
        return L.realmStop(province, current % Journey.stopsPerProvince).y - 14
    }
}
