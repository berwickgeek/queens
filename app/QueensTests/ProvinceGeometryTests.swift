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
}
