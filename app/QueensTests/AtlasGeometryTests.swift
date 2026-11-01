import XCTest
@testable import Queens

final class AtlasGeometryTests: XCTestCase {
    private typealias G = AtlasGeometry

    func testRandomIsDeterministicAndInRange() {
        var a = AtlasRandom(seed: 42), b = AtlasRandom(seed: 42), c = AtlasRandom(seed: 43)
        let xs = (0..<500).map { _ in a.next() }
        XCTAssertEqual(xs, (0..<500).map { _ in b.next() })
        XCTAssertNotEqual(xs, (0..<500).map { _ in c.next() })
        XCTAssertTrue(xs.allSatisfy { $0 >= 0 && $0 < 1 })
    }

    func testResampleKeepsEndsAndStep() {
        let p = [CGPoint(x: 0, y: 0), CGPoint(x: 40, y: 0), CGPoint(x: 40, y: 25)]
        let q = G.resample(p, step: 3)
        XCTAssertEqual(q.first, p.first)
        XCTAssertEqual(q.last, p.last)
        for (a, b) in zip(q, q.dropFirst()) { XCTAssertLessThanOrEqual(hypot(b.x - a.x, b.y - a.y), 3.0001) }
    }

    func testJitterIsDeterministicAndBounded() {
        let p = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 50)]
        var r1 = AtlasRandom(seed: 5), r2 = AtlasRandom(seed: 5)
        let a = G.jitter(p, amp: 2, closed: false, noise: AtlasNoise(seed: 1), rng: &r1)
        let b = G.jitter(p, amp: 2, closed: false, noise: AtlasNoise(seed: 1), rng: &r2)
        XCTAssertEqual(a, b)
        let base = G.resample(p, step: 3.5)
        XCTAssertEqual(a.count, base.count)
        // Up to amp from the noise plus 0.15 amp of tremor on each axis.
        for (q, o) in zip(a, base) {
            XCTAssertLessThanOrEqual(abs(q.x - o.x), 2.3001)
            XCTAssertLessThanOrEqual(abs(q.y - o.y), 2.3001)
        }
    }

    func testRingOvershootsAFullTurn() {
        var rng = AtlasRandom(seed: 9)
        let c = CGPoint(x: 10, y: 10)
        let ring = G.ring(c, radius: 6, rng: &rng)
        let angles = ring.map { atan2($0.y - c.y, $0.x - c.x) }
        var turned: CGFloat = 0
        for (a, b) in zip(angles, angles.dropFirst()) {
            var d = b - a
            if d > .pi { d -= 2 * .pi }
            if d < -.pi { d += 2 * .pi }
            turned += d
        }
        XCTAssertGreaterThan(turned, 2 * .pi + 0.2)
        XCTAssertLessThan(turned, 2 * .pi + 0.65)
    }

    func testCastleIsSymmetric() {
        let xs = G.castle.map(\.x)
        XCTAssertEqual(xs.reduce(0, +), 0, accuracy: 0.0001)
        for p in G.castle { XCTAssertTrue(G.castle.contains { abs($0.x + p.x) < 0.0001 && abs($0.y - p.y) < 0.0001 }) }
    }

    func testHandDashesStayInBounds() {
        var rng = AtlasRandom(seed: 3)
        let line = G.resample([CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 300)], step: 1.2)
        let dashes = G.handDashes(line, rng: &rng)
        XCTAssertGreaterThan(dashes.count, 20)
        for d in dashes {
            let length = zip(d, d.dropFirst()).reduce(CGFloat(0)) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
            XCTAssertGreaterThanOrEqual(length, 5 - 0.0001)
            XCTAssertLessThanOrEqual(length, 8 + 1.2 + 0.0001)
        }
    }

    func testOffsetMovesByDistanceToTheLeftOfTravel() {
        let p = [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 50), CGPoint(x: 0, y: 100)]
        let east = G.offset(p, by: 5)
        XCTAssertTrue(east.allSatisfy { abs($0.x - 5) < 0.0001 })
        XCTAssertEqual(east.map(\.y), p.map(\.y))
    }

    func testRoadThroughStopsPassesEveryStop() {
        let stops = (0..<5).map { CGPoint(x: CGFloat($0) * 10, y: CGFloat($0) * -26) }
        let road = G.road(through: stops)
        XCTAssertEqual(road.count, 1 + 8 * 4)
        for (j, s) in stops.enumerated() {
            XCTAssertEqual(road[j * 8].x, s.x, accuracy: 0.0001)
            XCTAssertEqual(road[j * 8].y, s.y, accuracy: 0.0001)
        }
    }
}
