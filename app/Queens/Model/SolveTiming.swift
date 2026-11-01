import Foundation

/// One clock for the solve celebration, shared by the haptic pattern and the board so they land together.
/// Times are seconds after the celebration starts (solveTrigger bumps), except `entrance`.
enum SolveTiming {
    /// Wait after the last crown is placed, so its entrance finishes before the bounce.
    static let entrance = 0.45
    /// Each row starts its bounce this much after the row above.
    static let rowStagger = 0.07
    /// From a row's start to the top of its bounce.
    static let peak = 0.18

    static func rowPeak(_ row: Int) -> Double { Double(row) * rowStagger + peak }
    /// The big beat once every row has bounced: board pulse, sheen, gilded frame.
    static func finale(rows: Int) -> Double { rowPeak(rows - 1) + 0.3 }

    /// The royal road: a dotted route drawn crown to crown, top row to bottom, once the sheen has passed.
    static func roadStart(rows: Int) -> Double { finale(rows: rows) + 0.5 }
    /// Time for the road to travel from one crown to the next.
    static let roadLeg = 0.09
    /// The road reaches this row's crown, and its kingdom ripples.
    static func roadReach(_ row: Int, rows: Int) -> Double { roadStart(rows: rows) + Double(row) * roadLeg }
    static func roadEnd(rows: Int) -> Double { roadReach(rows - 1, rows: rows) }
    /// How long the finished road stays before fading.
    static let roadLinger = 0.9

    /// Lanterns rise from every crown as the road arrives at the last one.
    static func lanterns(rows: Int) -> Double { roadEnd(rows: rows) }
    /// The ribbon unfurls under the board.
    static func ribbon(rows: Int) -> Double { roadEnd(rows: rows) + 0.2 }
    /// The wax seal stamps onto the ribbon.
    static func stamp(rows: Int) -> Double { ribbon(rows: rows) + 0.75 }
    /// A new best: the bells run up after the seal lands.
    static let bestRun = 0.25

    /// How long the lanterns take to rise and fade. A festival sends up more, for longer.
    static func lanternSpan(_ flourish: Flourish) -> Double { flourish == .festival ? 4.6 : 3.4 }
    /// A shooting star crosses the sky above the board once the lanterns are up.
    static func comet(rows: Int) -> Double { lanterns(rows: rows) + 0.4 }
    static let cometFlight = 1.1
}

/// The walk to the next stop on a province map, played once after a solve. Seconds after the
/// map's travel trigger bumps, from the mockup's province animation.
enum Travel {
    /// The castle blooms where the seal stood; the seal's red name gives way to the stop's ink one.
    static let bloom = 0.2...0.9
    static let oldNameOut = 0.2...0.7
    static let oldNameIn = 0.4...1.0
    /// The seal walks the road, red ink following it.
    static let walk = 0.6...1.7
    /// The seal settles on the new stop, or the castle is inked when the province is finished.
    static let land = 1.7...2.0
    /// The edge between ink and pencil creeps up to the new stop.
    static let ink = 0.9...2.6
    /// "Uncharted" and the pencil ring fade from the new stop.
    static let uncharted = 1.5...1.9
    /// The slim card and the solved count move on.
    static let card = 1.8
    /// The new stop's name is written on, left to right.
    static let name = 1.9...2.9
    static let total = 3.0
    /// Footsteps while the seal walks.
    static let steps = 5

    /// How far through `window` time `t` is, 0 to 1.
    static func progress(_ t: Double, _ window: ClosedRange<Double>) -> Double {
        min(max((t - window.lowerBound) / (window.upperBound - window.lowerBound), 0), 1)
    }

    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }

    /// When footstep `k` falls: evenly through the walk, half a step in from each end.
    static func step(_ k: Int) -> Double {
        walk.lowerBound + (walk.upperBound - walk.lowerBound) * (Double(k) + 0.5) / Double(steps)
    }
}

/// A rare extra on a solve, drawn by chance so a coronation is now and then not the usual one.
enum Flourish: String {
    case none, festival, comet

    static func draw() -> Flourish {
        #if DEBUG
        if let forced = UserDefaults.standard.string(forKey: "flourish").flatMap(Flourish.init(rawValue:)) { return forced }
        #endif
        switch Int.random(in: 0..<16) {
        case 0: return .festival
        case 1: return .comet
        default: return .none
        }
    }
}
