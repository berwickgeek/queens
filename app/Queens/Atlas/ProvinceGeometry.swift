import Foundation

/// Where things sit on a province sheet, ported from the mockup's province `terrain()`. Every
/// province uses the same 390 by 720 sheet; the road's phase differs per province, so the lake
/// and the title move to stay clear of it. Pure functions, so they can be checked without UI.
enum ProvinceGeometry {
    private typealias L = Journey.Layout

    /// The mockup's `f77`.
    static let noise = AtlasNoise(seed: 77)

    /// The east coast's x at sheet height `y`, about 260 to 325.
    static func coastX(_ y: CGFloat) -> CGFloat {
        292 + 22 * sin(y * 0.018) + 26 * (noise(3, y * 0.02) - 0.5)
    }

    /// The coastline from above the sheet to below it.
    static var coastline: [CGPoint] {
        stride(from: CGFloat(-20), through: L.provinceHeight + 20, by: 10).map { CGPoint(x: coastX($0), y: $0) }
    }

    /// Open water east of the coast.
    static var sea: [CGPoint] {
        coastline + [CGPoint(x: L.width + 30, y: L.provinceHeight + 20), CGPoint(x: L.width + 30, y: -20)]
    }

    /// The province's stops, first to last. A short last province has fewer than twenty.
    static func stops(_ province: Journey.Province, count: Int = Journey.stopsPerProvince) -> [CGPoint] {
        (0..<count).map { L.provinceStop(province, $0) }
    }

    /// The road through the stops, with stop `j` at index `j * 8`.
    static func road(_ stops: [CGPoint]) -> [CGPoint] {
        AtlasGeometry.road(through: stops)
    }

    /// The castle at the end of the road, above the last stop.
    static func castle(_ stops: [CGPoint]) -> CGPoint {
        guard let last = stops.last else { return CGPoint(x: 150, y: 30) }
        return CGPoint(x: last.x, y: last.y - 30)
    }

    /// Whether (x, y) is within `r` of a stop or the castle, so terrain stays off them.
    static func near(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, stops: [CGPoint]) -> Bool {
        let c = castle(stops)
        return stops.contains { hypot($0.x - x, $0.y - y) < r } || hypot(c.x - x, c.y - y) < r + 14
    }

    /// The lake sits on the west edge at the height where the road swings furthest east, so
    /// whatever the road's phase, no stop falls in it.
    static func lake(_ stops: [CGPoint]) -> CGPoint {
        let road = road(stops)
        let best = stride(from: CGFloat(250), through: 470, by: 10).max { a, b in
            clearance(CGPoint(x: 46, y: a), road) < clearance(CGPoint(x: 46, y: b), road)
        } ?? 330
        return CGPoint(x: 46, y: best)
    }

    private static func clearance(_ c: CGPoint, _ road: [CGPoint]) -> CGFloat {
        road.map { hypot(($0.x - c.x) / 1.3, $0.y - c.y) }.min() ?? .infinity
    }

    /// Whether (x, y) is inside the lake plus a margin `m`, in the lake's stretched units.
    static func inLake(_ x: CGFloat, _ y: CGFloat, lake: CGPoint, margin m: CGFloat = 44) -> Bool {
        hypot((x - lake.x) / 1.3, y - lake.y) < m
    }

    /// The title cartouche goes in the top corner away from the castle.
    static func cartouche(_ stops: [CGPoint]) -> CGPoint {
        castle(stops).x > 196 ? CGPoint(x: 92, y: 30) : CGPoint(x: 300, y: 30)
    }

    /// Whether (x, y) falls under the cartouche, so trees and peaks leave it clear.
    static func underCartouche(_ x: CGFloat, _ y: CGFloat, stops: [CGPoint]) -> Bool {
        let c = cartouche(stops)
        return abs(x - c.x) < 90 && y < c.y + 30
    }

    /// Where the ink meets the pencil for this province's stop states: just above the current
    /// stop, past the bottom while the whole province lies ahead, past the top otherwise.
    static func boundary(_ province: Journey.Province, states: [Journey.StopState]) -> CGFloat {
        if let j = states.firstIndex(of: .current) { return L.provinceStop(province, j).y - 14 }
        if !states.isEmpty && states.allSatisfy({ $0 == .ahead }) { return L.provinceHeight + 40 }
        return -40
    }
}
