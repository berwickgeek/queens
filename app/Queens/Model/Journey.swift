import Foundation

/// The journey across a realm. A realm's 240 puzzles are 12 provinces of 20 stops on one map
/// sheet: provinces 1 to 6 are the near shore (the first set), a sea crossing, then 7 to 12 on
/// the far shore (the second set, whose puzzle names already use `Naming`'s far places).
enum Journey {
    static let stopsPerProvince = 20
    static let provincesPerShore = 6

    struct Province: Hashable, Identifiable {
        let size: Int
        /// 0-based, 0 to 11.
        let index: Int

        var id: String { "\(size)-p\(index)" }
        var name: String { Naming.province(size: size, index: index) }
        /// Puzzle numbers on this province's road.
        var numbers: ClosedRange<Int> { index * stopsPerProvince + 1 ... (index + 1) * stopsPerProvince }
        var farShore: Bool { index >= provincesPerShore }
        /// The last province of each shore is a scatter of islands rather than a stretch of road.
        var isles: Bool { index % provincesPerShore == provincesPerShore - 1 }
    }

    static func provinces(size: Int, puzzleCount: Int) -> [Province] {
        let count = (puzzleCount + stopsPerProvince - 1) / stopsPerProvince
        return (0..<count).map { Province(size: size, index: $0) }
    }

    static func province(of puzzle: Puzzle) -> Province {
        Province(size: puzzle.size, index: (puzzle.number - 1) / stopsPerProvince)
    }

    // MARK: Progress

    enum StopState { case solved, skipped, current, ahead }

    enum ProvinceState {
        /// Every stop solved: the castle is inked.
        case finished
        /// Behind the current stop but with skipped stops, so its castle stays pencilled.
        case visited
        case current
        /// The one after the current province, labelled "next".
        case next
        case uncharted
    }

    /// `solved[i]` says whether puzzle number i + 1 is solved. The current stop is the first
    /// unsolved one after the furthest solve, so a puzzle passed over reads as skipped rather
    /// than pulling the traveller back. Once the furthest stop is solved, the current stop is the
    /// first skipped one. This differs from `ProgressStore.firstUnsolved`, which ignores order.
    static func stopStates(solved: [Bool]) -> [StopState] {
        let furthest = solved.lastIndex(of: true) ?? -1
        let current = solved[(furthest + 1)...].firstIndex(of: false) ?? solved.firstIndex(of: false)
        return solved.indices.map { i in
            if solved[i] { return .solved }
            if i == current { return .current }
            return i < furthest ? .skipped : .ahead
        }
    }

    static func provinceStates(_ stops: [StopState]) -> [ProvinceState] {
        let count = (stops.count + stopsPerProvince - 1) / stopsPerProvince
        let currentProvince = stops.firstIndex(of: .current).map { $0 / stopsPerProvince }
        return (0..<count).map { p in
            let slice = stops[(p * stopsPerProvince)..<min(stops.count, (p + 1) * stopsPerProvince)]
            if slice.allSatisfy({ $0 == .solved }) { return .finished }
            guard let cur = currentProvince else { return .visited }
            if p == cur { return .current }
            if p < cur { return .visited }
            return p == cur + 1 ? .next : .uncharted
        }
    }

    // MARK: Layout

    /// Positions in map units: both sheets are 390 wide, the width the mockups were drawn at,
    /// and scale to the screen width. y grows downward and the journey travels up the sheet.
    enum Layout {
        static let width: CGFloat = 390

        // Realm sheet, top to bottom: margin for the cartouche, far shore bands 12 to 7, the sea
        // crossing, near shore bands 6 to 1, room for the card.
        static let band: CGFloat = 90
        static let topMargin: CGFloat = 65
        static let sea: CGFloat = 160
        static let bottomMargin: CGFloat = 115
        static let realmHeight = topMargin + 12 * band + sea + bottomMargin

        /// Bottom edge of a province's band on the realm sheet; the band runs `band` above it.
        static func bandBottom(_ index: Int) -> CGFloat {
            let shore = CGFloat(index / provincesPerShore)
            let k = CGFloat(index % provincesPerShore)
            return realmHeight - bottomMargin - shore * (6 * band + sea) - k * band
        }

        /// The winding road up the realm sheet.
        static func roadX(_ y: CGFloat) -> CGFloat { 150 + 82 * sin(y * 0.0349 + 0.873) }

        /// Island centres and radii for an isles province, relative to the band bottom.
        static let isles: [(x: CGFloat, dy: CGFloat, r: CGFloat)] = [
            (176, -49, 18), (244, -77, 22), (316, -47, 19), (322, -115, 16),
        ]

        /// Where stop `j` (0 to 19) of a province sits on the realm sheet.
        static func realmStop(_ province: Province, _ j: Int) -> CGPoint {
            let y0 = bandBottom(province.index)
            if province.isles {
                let island = isles[j / 5], k = CGFloat(j % 5)
                return CGPoint(x: island.x - island.r * 0.55 + k * island.r * 0.27,
                               y: y0 + island.dy + island.r * 0.18 * sin(k * 1.3))
            }
            let y = y0 - (CGFloat(j) + 0.5) / CGFloat(stopsPerProvince) * band
            return CGPoint(x: roadX(y), y: y)
        }

        // Province sheet: 20 stops climbing a sine road, the castle above the last.
        static let provinceHeight: CGFloat = 720

        /// Each province's road starts its swing at a different phase so no two look alike.
        static func phase(_ province: Province) -> CGFloat {
            0.2 + CGFloat((province.size * 12 + province.index) * 37 % 100) / 100 * 2 * .pi
        }

        static func provinceStop(_ province: Province, _ j: Int) -> CGPoint {
            CGPoint(x: 150 + 70 * sin(CGFloat(j) * 0.72 + phase(province)), y: 560 - CGFloat(j) * 26.5)
        }
    }
}
