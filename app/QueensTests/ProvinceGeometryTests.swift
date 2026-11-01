import XCTest
@testable import Queens

final class ProvinceGeometryTests: XCTestCase {
    typealias P = ProvinceGeometry

    private var everyProvince: [Journey.Province] {
        (7...11).flatMap { size in (0..<12).map { Journey.Province(size: size, index: $0) } }
    }

    func testStopsAndCastleAreAshoreAndOnTheSheet() {
        for province in everyProvince {
            let stops = P.stops(province)
            for p in stops {
                XCTAssertLessThan(p.x, P.coastX(p.y) - 30, "\(province.id) stop \(p) is too near the coast")
            }
            let castle = P.castle(stops)
            XCTAssertGreaterThan(castle.y - 1.6 * 13, 0, "\(province.id) castle flag is off the sheet")
        }
    }

    func testRoadMeetsEveryStop() {
        let stops = P.stops(Journey.Province(size: 7, index: 1))
        let road = P.road(stops)
        for (j, p) in stops.enumerated() {
            XCTAssertEqual(road[j * 8].x, p.x, accuracy: 0.001)
            XCTAssertEqual(road[j * 8].y, p.y, accuracy: 0.001)
        }
    }

    func testLakeIsClearOfTheRoad() {
        for province in everyProvince {
            let stops = P.stops(province)
            let lake = P.lake(stops)
            for p in P.road(stops) {
                XCTAssertFalse(P.inLake(p.x, p.y, lake: lake, margin: 38), "\(province.id) road \(p) runs through the lake at \(lake)")
            }
        }
    }

    func testCartoucheIsClearOfTheCastle() {
        for province in everyProvince {
            let stops = P.stops(province)
            let castle = P.castle(stops)
            XCTAssertFalse(P.underCartouche(castle.x, castle.y, stops: stops), "\(province.id) castle under the title")
        }
    }

    func testBoundary() {
        let province = Journey.Province(size: 7, index: 1)
        var states = [Journey.StopState](repeating: .solved, count: 20)
        XCTAssertLessThan(P.boundary(province, states: states), 0)
        states[17] = .current
        XCTAssertEqual(P.boundary(province, states: states), Journey.Layout.provinceStop(province, 17).y - 14, accuracy: 0.001)
        states = [Journey.StopState](repeating: .ahead, count: 20)
        XCTAssertGreaterThan(P.boundary(province, states: states), Journey.Layout.provinceHeight)
    }

    // MARK: Travel

    private func states(solved: Int, count: Int = 20) -> [Journey.StopState] {
        (0..<count).map { $0 < solved ? .solved : $0 == solved ? .current : .ahead }
    }

    func testLeg() {
        XCTAssertEqual(P.leg(states(solved: 5)), P.Leg(from: 4, to: 5))
        XCTAssertEqual(P.leg(states(solved: 0)), P.Leg(from: nil, to: 0))
        XCTAssertEqual(P.leg([Journey.StopState](repeating: .solved, count: 20)), P.Leg(from: 19, to: nil))
        XCTAssertNil(P.leg([Journey.StopState](repeating: .ahead, count: 20)))
        // A skipped stop just before the current one: nothing was walked onto this stop.
        var s = states(solved: 5)
        s[4] = .skipped
        XCTAssertEqual(P.leg(s), P.Leg(from: nil, to: 5))
    }

    func testBeforeUndoesTheLeg() {
        XCTAssertEqual(P.Leg(from: 4, to: 5).before(states(solved: 5)), states(solved: 4))
        XCTAssertEqual(P.Leg(from: nil, to: 0).before(states(solved: 0)), [Journey.StopState](repeating: .ahead, count: 20))
        XCTAssertEqual(P.Leg(from: 19, to: nil).before([Journey.StopState](repeating: .solved, count: 20)), states(solved: 19))
    }

    func testPathRunsStopToStop() {
        for province in everyProvince {
            let stops = P.stops(province)
            let path = P.path(P.Leg(from: 6, to: 7), stops: stops)
            XCTAssertEqual(path.count, 9)
            XCTAssertEqual(path.first, stops[6])
            XCTAssertEqual(path.last, stops[7])
            let end = P.path(P.Leg(from: 19, to: nil), stops: stops)
            XCTAssertEqual(end.first, stops[19])
            XCTAssertEqual(end.last.map { hypot($0.x - P.castle(stops).x, $0.y - P.castle(stops).y) } ?? .infinity, 0, accuracy: 0.001)
            XCTAssertTrue(P.path(P.Leg(from: nil, to: 0), stops: stops).isEmpty)
        }
    }

    func testTravelClock() {
        XCTAssertEqual(Travel.progress(0, Travel.walk), 0)
        XCTAssertEqual(Travel.progress(Travel.total, Travel.walk), 1)
        XCTAssertEqual(Travel.easeInOut(0.5), 0.5, accuracy: 0.0001)
        for k in 0..<Travel.steps {
            XCTAssertTrue(Travel.walk.contains(Travel.step(k)))
        }
        XCTAssertLessThanOrEqual(Travel.name.upperBound, Travel.total)
    }
}
