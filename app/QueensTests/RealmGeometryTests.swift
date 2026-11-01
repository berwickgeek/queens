import XCTest
@testable import Queens

final class RealmGeometryTests: XCTestCase {
    typealias L = Journey.Layout
    typealias R = RealmGeometry

    private func provinceStops(_ i: Int) -> [CGPoint] {
        (0..<Journey.stopsPerProvince).map { L.realmStop(Journey.Province(size: 7, index: i), $0) }
    }

    func testShifts() {
        XCTAssertEqual(R.shift(0), 700, accuracy: 0.01)
        XCTAssertEqual(R.shift(1), 0, accuracy: 0.01)
    }

    func testLandStopsAreAshoreAndIslesAtSea() {
        for i in 0..<12 {
            let shore = i / Journey.provincesPerShore
            for p in provinceStops(i) {
                if Journey.Province(size: 7, index: i).isles {
                    XCTAssertLessThan(p.y, R.northY(p.x, shore: shore), "isle stop \(i) \(p) is ashore")
                } else {
                    XCTAssertLessThan(p.x, R.coastX(p.y) - 20, "stop \(i) \(p) is too near the east coast")
                    XCTAssertGreaterThan(p.y, R.northY(p.x, shore: shore) + 2, "stop \(i) \(p) is north of the coast")
                }
            }
        }
    }

    func testFarShoreSouthCoastClearsItsFirstStop() {
        let first = provinceStops(6)[0]
        for x in stride(from: CGFloat(-20), through: 330, by: 5) {
            XCTAssertGreaterThan(R.southY(x), first.y + 9)
        }
    }

    func testCoastlinesAreUnbroken() {
        for shore in 0..<2 {
            let c = R.coastline(shore)
            XCTAssertGreaterThan(c.count, 40)
            for (a, b) in zip(c, c.dropFirst()) { XCTAssertLessThan(hypot(b.x - a.x, b.y - a.y), 30) }
        }
        XCTAssertGreaterThan(R.coastline(0).last!.y, L.realmHeight)
        XCTAssertLessThan(R.coastline(1).last!.x, 0)
    }

    func testProvinceNamesStayOffTheRoad() {
        for i in 0..<12 where !Journey.Province(size: 7, index: i).isles {
            let c = R.labelCentre(i)
            for y in stride(from: c.y - 16, through: c.y + 18, by: 2) {
                XCTAssertGreaterThan(abs(L.roadX(y) - c.x), 56, "province \(i)'s name crosses the road")
            }
            XCTAssertLessThan(c.x + 60, R.coastX(c.y) + 30, "province \(i)'s name runs out to sea")
        }
    }

    func testNearRoad() {
        XCTAssertTrue(R.nearRoad(L.roadX(500), 500, 5))
        XCTAssertFalse(R.nearRoad(L.roadX(500) + 60, 500, 20))
    }

    func testRouteVisitsEveryStopInOrder() {
        let route = R.route(size: 7, stops: 240)
        XCTAssertEqual(route.stops.count, 240)
        for i in 0..<240 {
            let want = L.realmStop(Journey.Province(size: 7, index: i / 20), i % 20)
            XCTAssertEqual(route.points[route.stops[i]].x, want.x, accuracy: 0.001)
            XCTAssertEqual(route.points[route.stops[i]].y, want.y, accuracy: 0.001)
        }
        XCTAssertEqual(route.stops, route.stops.sorted())
        for (a, b) in zip(route.points, route.points.dropFirst()) { XCTAssertLessThan(hypot(b.x - a.x, b.y - a.y), 40) }
    }

    func testBoundary() {
        let solved = (0..<240).map { $0 < 45 }
        XCTAssertEqual(R.boundary(size: 7, states: Journey.stopStates(solved: solved)),
                       L.realmStop(Journey.Province(size: 7, index: 2), 5).y - 14, accuracy: 0.001)
        XCTAssertEqual(R.boundary(size: 7, states: Journey.stopStates(solved: Array(repeating: true, count: 240))), -40)
    }
}
