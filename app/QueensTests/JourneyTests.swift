import XCTest
@testable import Queens

final class JourneyTests: XCTestCase {
    private func solved(_ count: Int, _ numbers: Set<Int>) -> [Bool] {
        (1...count).map { numbers.contains($0) }
    }

    func testFreshRealmStartsAtTheFirstStop() {
        let states = Journey.stopStates(solved: solved(240, []))
        XCTAssertEqual(states[0], .current)
        XCTAssertTrue(states.dropFirst().allSatisfy { $0 == .ahead })
    }

    func testPassedOverPuzzleIsSkippedAndCurrentIsPastTheFurthestSolve() {
        // The mockup's state: 1 to 37 solved except 36.
        let states = Journey.stopStates(solved: solved(240, Set(1...37).subtracting([36])))
        XCTAssertEqual(states[35], .skipped)
        XCTAssertEqual(states[37], .current)
        XCTAssertEqual(states[38], .ahead)
        XCTAssertEqual(states.filter { $0 == .current }.count, 1)
    }

    func testOnceTheLastStopIsSolvedCurrentFallsBackToTheFirstSkipped() {
        let states = Journey.stopStates(solved: solved(40, Set(1...40).subtracting([12, 30])))
        XCTAssertEqual(states[11], .current)
        XCTAssertEqual(states[29], .skipped)
    }

    func testEverythingSolvedHasNoCurrent() {
        let states = Journey.stopStates(solved: solved(40, Set(1...40)))
        XCTAssertTrue(states.allSatisfy { $0 == .solved })
        XCTAssertEqual(Journey.provinceStates(states), [.finished, .finished])
    }

    func testProvinceStates() {
        let states = Journey.stopStates(solved: solved(240, Set(1...37).subtracting([36])))
        let provinces = Journey.provinceStates(states)
        XCTAssertEqual(provinces.count, 12)
        XCTAssertEqual(provinces[0], .finished)
        XCTAssertEqual(provinces[1], .current)
        XCTAssertEqual(provinces[2], .next)
        XCTAssertTrue(provinces[3...].allSatisfy { $0 == .uncharted })
    }

    func testProvinceBehindTheTravellerWithASkipIsVisited() {
        let states = Journey.stopStates(solved: solved(240, Set(1...45).subtracting([7])))
        XCTAssertEqual(Journey.provinceStates(states)[0], .visited)
    }

    func testProvinceNumbering() {
        let p = Journey.Province(size: 8, index: 1)
        XCTAssertEqual(p.numbers, 21...40)
        XCTAssertEqual(p.name, "Fernhollow")
        XCTAssertTrue(Journey.Province(size: 8, index: 5).isles)
        XCTAssertTrue(Journey.Province(size: 8, index: 11).isles)
        XCTAssertTrue(Journey.Province(size: 8, index: 6).farShore)
        XCTAssertEqual(Journey.provinces(size: 9, puzzleCount: 240).count, 12)
    }

    func testEveryPuzzleMapsToItsProvince() {
        for size in PuzzleLibrary.sizes {
            for puzzle in PuzzleLibrary.shared.puzzles(size) {
                XCTAssertTrue(Journey.province(of: puzzle).numbers.contains(puzzle.number), puzzle.id)
            }
        }
    }

    func testProvinceNamesAreUniqueAcrossRealms() {
        let names = PuzzleLibrary.sizes.flatMap { size in (0..<12).map { Naming.province(size: size, index: $0) } }
        XCTAssertEqual(Set(names).count, 60)
    }

    func testRealmStopsStayOnTheSheetAndInTheirBand() {
        let L = Journey.Layout.self
        for province in Journey.provinces(size: 7, puzzleCount: 240) {
            var lastY = CGFloat.infinity
            for j in 0..<Journey.stopsPerProvince {
                let p = L.realmStop(province, j)
                XCTAssertTrue((8...(L.width - 8)).contains(p.x), "\(province.name) stop \(j) x \(p.x)")
                XCTAssertTrue((8...(L.realmHeight - L.bottomMargin)).contains(p.y), "\(province.name) stop \(j) y \(p.y)")
                if !province.isles {
                    XCTAssertLessThan(p.y, lastY, "the road climbs")
                    XCTAssertGreaterThan(p.y, L.bandBottom(province.index) - L.band)
                    lastY = p.y
                }
            }
        }
    }

    func testBandsDoNotOverlapAndLeaveTheSeaBetweenShores() {
        let L = Journey.Layout.self
        for i in 1..<12 {
            let gap = L.bandBottom(i - 1) - L.bandBottom(i)
            XCTAssertEqual(gap, i == Journey.provincesPerShore ? L.band + L.sea : L.band, accuracy: 0.001)
        }
        XCTAssertEqual(L.bandBottom(11) - L.band, L.topMargin, accuracy: 0.001)
    }

    func testProvinceStopsStayOnTheSheet() {
        let L = Journey.Layout.self
        for size in PuzzleLibrary.sizes {
            for province in Journey.provinces(size: size, puzzleCount: 240) {
                for j in 0..<Journey.stopsPerProvince {
                    let p = L.provinceStop(province, j)
                    XCTAssertTrue((40...(L.width - 40)).contains(p.x))
                    XCTAssertTrue((0...L.provinceHeight).contains(p.y))
                }
            }
        }
    }
}
