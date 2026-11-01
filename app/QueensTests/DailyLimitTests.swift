import XCTest
@testable import Queens

final class DailyLimitTests: XCTestCase {
    func testFirstSittingIsNeverCutShort() {
        XCTAssertFalse(Unlock.limitReached(lifetime: 9, today: 9))
        XCTAssertTrue(Unlock.limitReached(lifetime: 10, today: 10))
    }

    func testFiveADayAfterThat() {
        XCTAssertFalse(Unlock.limitReached(lifetime: 40, today: 4))
        XCTAssertTrue(Unlock.limitReached(lifetime: 40, today: 5))
    }

    func testMergeKeepsTheLatestSolveDay() {
        var a = PuzzleRecord()
        a.solvedOn = Date(timeIntervalSince1970: 100)
        a.lastPlayed = Date(timeIntervalSince1970: 500)
        var b = PuzzleRecord()
        b.solvedOn = Date(timeIntervalSince1970: 300)
        b.lastPlayed = Date(timeIntervalSince1970: 200)
        XCTAssertEqual(a.merged(with: b).solvedOn, Date(timeIntervalSince1970: 300))
        XCTAssertTrue(b.improves(a))
    }
}
