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
    /// The big beat once every row has bounced: board pulse, sheen, gilded frame, ribbon.
    static func finale(rows: Int) -> Double { rowPeak(rows - 1) + 0.3 }
    /// The gold crown stamps onto the ribbon.
    static func stamp(rows: Int) -> Double { finale(rows: rows) + 0.75 }
}
