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

    /// Map and walls spread out through a kingdom from its crown, this long per cell of distance.
    static let landSpread = 0.06
    /// Time to ink one map symbol.
    static let landDraw = 0.3
    /// The corner towers rise just after the road reaches the last crown, then the curtain wall runs between them.
    static func outerWall(rows: Int) -> Double { roadEnd(rows: rows) + 0.1 }
    /// The ribbon unfurls under the board.
    static func ribbon(rows: Int) -> Double { roadEnd(rows: rows) + 0.2 }
    /// The wax seal stamps onto the ribbon.
    static func stamp(rows: Int) -> Double { ribbon(rows: rows) + 0.75 }
}
