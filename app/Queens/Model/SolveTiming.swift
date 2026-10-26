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
}
