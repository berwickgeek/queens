import Foundation

enum HintUnit: Hashable {
    case row(Int), col(Int), region(Int)
}

/// One stage of a clue: what to say, which rows, columns or kingdoms to spotlight, which cells to mark.
struct ClueStep: Equatable {
    var text: String
    var focus: [HintUnit] = []
    var cells: Set<Int> = []
    /// Cells to dot show as faint crosses; anything else gets a pulsing outline.
    var dots = false
}

/// A clue reveals itself a step at a time: where to look, then why, then which cells.
struct Clue: Equatable {
    var steps: [ClueStep]
    /// The cells the clue is about. Once they are all marked, the clue has done its job.
    var targets: Set<Int>
    /// Mistake pointers vanish on the next move.
    var transient = false
}

/// Finds the easiest deduction from the player's marks, using the generator's rules in the same order
/// (tools/generate.py logic_solve), so every puzzle the generator accepted can be hinted all the way.
struct HintEngine {
    let n: Int
    let regionOf: [Int]
    private(set) var cand: Set<Int>
    private(set) var queens: Set<Int>

    /// Assumes the marks hold no mistakes: crowns are all correct and no cross covers a solution cell.
    init(puzzle: Puzzle, marks: [Mark]) {
        n = puzzle.size
        regionOf = puzzle.regionOf
        queens = Set(marks.indices.filter { marks[$0] == .queen })
        cand = Set(marks.indices.filter { marks[$0] == .empty })
        for q in queens { cand.subtract(attack(q)) }
    }

    func next() -> Clue? {
        single() ?? pointing() ?? sharedLines() ?? wouldBlock() ?? fork()
    }

    // MARK: Rules, easiest first

    /// A row, column or kingdom with one cell left.
    private func single() -> Clue? {
        for u in openUnits {
            let cs = cands(u)
            guard cs.count == 1, let c = cs.first else { continue }
            return Clue(steps: [
                ClueStep(text: "\(cap(name(u))) has only one cell left that no crown blocks.", focus: [u]),
                ClueStep(text: "Its crown goes here.", focus: [u], cells: [c]),
            ], targets: [c])
        }
        return nil
    }

    /// Everything left in one unit sits inside another, so that other unit's spare cells can go.
    private func pointing() -> Clue? {
        var best: (HintUnit, HintUnit, Set<Int>)?
        for a in openUnits {
            let cs = cands(a)
            guard cs.count > 1 else { continue }
            for b in openUnits where kind(b) != kind(a) {
                let bCells = Set(cells(b))
                guard cs.isSubset(of: bCells) else { continue }
                let kill = cand.intersection(bCells).subtracting(cs)
                if !kill.isEmpty, kill.count > (best?.2.count ?? 0) { best = (a, b, kill) }
            }
        }
        guard let (a, b, kill) = best else { return nil }
        let look: String, why: String
        if kind(a) == 2 {
            look = "Look at where \(name(a)) can still go."
            why = "Every open cell of \(name(a)) is in \(name(b)), so \(possessive(b)) crown must be \(possessive(a))."
        } else {
            look = "Look at which colours \(name(a)) can still use."
            why = "Every open cell in \(name(a)) is \(name(b)), so \(possessive(b)) crown must be in \(name(a))."
        }
        return Clue(steps: [
            ClueStep(text: look, focus: [a]),
            ClueStep(text: cap(why), focus: [a, b]),
            ClueStep(text: "Dot the rest of \(name(b)).", focus: [a, b], cells: kill, dots: true),
        ], targets: kill)
    }

    /// A cell that would leave some row, column or kingdom with nowhere to go.
    private func wouldBlock() -> Clue? {
        for u in openUnits.sorted(by: { cands($0).count < cands($1).count }) {
            let cs = cands(u)
            guard !cs.isEmpty else { continue }
            let inside = Set(cells(u))
            for c in cand.sorted() where !inside.contains(c) && cs.isSubset(of: attack(c)) {
                return Clue(steps: [
                    ClueStep(text: "One cell outside \(name(u)) would leave it with nowhere to go.", focus: [u]),
                    ClueStep(text: "A crown here would block every open cell of \(name(u)).", focus: [u], cells: [c]),
                    ClueStep(text: "So it can't hold a crown. Dot it.", focus: [u], cells: [c]),
                ], targets: [c])
            }
        }
        return nil
    }

    /// k kingdoms that fit inside k rows (or columns) own them; or k rows that only reach k kingdoms own those.
    private func sharedLines() -> Clue? {
        let regions = openUnits.filter { kind($0) == 2 }
        for size in 2...4 {
            for axis in 0...1 {
                let lines = openUnits.filter { kind($0) == axis }
                // Kingdoms boxed into lines.
                let boxed = regions.compactMap { r -> (HintUnit, Set<Int>)? in
                    let ls = Set(cands(r).map { line($0, axis) })
                    return ls.count > 1 && ls.count <= size ? (r, ls) : nil
                }
                for combo in combinations(boxed, size) {
                    let ls = combo.reduce(into: Set<Int>()) { $0.formUnion($1.1) }
                    guard ls.count == size else { continue }
                    let members = Set(combo.map { index($0.0) })
                    let kill = cand.filter { ls.contains(line($0, axis)) && !members.contains(regionOf[$0]) }
                    guard !kill.isEmpty else { continue }
                    let lineUnits = ls.sorted().map { axis == 0 ? HintUnit.row($0) : .col($0) }
                    let regionUnits = combo.map(\.0)
                    let where_ = linesPhrase(ls.sorted(), axis)
                    return Clue(steps: [
                        ClueStep(text: "Count the colours that fit entirely inside \(where_).", focus: lineUnits),
                        ClueStep(text: "\(cap(list(regionUnits.map(name)))) all fit inside \(where_), so those \(size) crowns fill them.", focus: lineUnits + regionUnits),
                        ClueStep(text: "Dot every other colour in \(where_).", focus: lineUnits + regionUnits, cells: kill, dots: true),
                    ], targets: kill)
                }
                // Lines that only reach a few kingdoms.
                let reach = lines.compactMap { l -> (HintUnit, Set<Int>)? in
                    let rs = Set(cands(l).map { regionOf[$0] })
                    return rs.count > 1 && rs.count <= size ? (l, rs) : nil
                }
                for combo in combinations(reach, size) {
                    let rs = combo.reduce(into: Set<Int>()) { $0.formUnion($1.1) }
                    guard rs.count == size else { continue }
                    let ls = Set(combo.map { index($0.0) })
                    let kill = cand.filter { rs.contains(regionOf[$0]) && !ls.contains(line($0, axis)) }
                    guard !kill.isEmpty else { continue }
                    let lineUnits = combo.map(\.0)
                    let regionUnits = rs.sorted().map { HintUnit.region($0) }
                    let where_ = linesPhrase(ls.sorted(), axis)
                    let colours = list(regionUnits.map(name))
                    return Clue(steps: [
                        ClueStep(text: "Look at which colours \(where_) can still use.", focus: lineUnits),
                        ClueStep(text: "\(cap(where_)) can only use \(colours), so those \(size) crowns all land in \(where_).", focus: lineUnits + regionUnits),
                        ClueStep(text: "Dot the rest of \(colours).", focus: lineUnits + regionUnits, cells: kill, dots: true),
                    ], targets: kill)
                }
            }
        }
        return nil
    }

    /// Test a fork: a crown here forces others until something runs out of room.
    private func fork() -> Clue? {
        // Prefer a unit down to two cells: that is the test a person would pick.
        var best: (HintUnit?, Int, HintUnit, Int)?
        for u in openUnits where cands(u).count == 2 {
            for c in cands(u).sorted() {
                if let (broken, forced) = contradiction(placing: c), forced < (best?.3 ?? .max) {
                    best = (u, c, broken, forced)
                }
            }
        }
        if best == nil {
            for c in cand.sorted() {
                if let (broken, forced) = contradiction(placing: c) { best = (nil, c, broken, forced); break }
            }
        }
        guard let (unit, c, broken, forced) = best else { return nil }
        let first: ClueStep
        if let unit {
            first = ClueStep(text: "\(cap(name(unit))) is down to two cells. Imagine its crown in the marked one and play it forward.", focus: [unit], cells: [c])
        } else {
            first = ClueStep(text: "Imagine a crown in the marked cell and play it forward.", cells: [c])
        }
        let chain = forced == 0 ? "" : forced == 1 ? "That forces one more crown, then " : "That forces \(forced) more crowns, then "
        let focus = (unit.map { [$0] } ?? []) + [broken]
        return Clue(steps: [
            first,
            ClueStep(text: "\(chain)\(chain.isEmpty ? cap(name(broken)) : name(broken)) has nowhere left to go.", focus: focus, cells: [c]),
            ClueStep(text: "So that cell can't hold a crown. Dot it.", focus: focus, cells: [c]),
        ], targets: [c])
    }

    /// Place a crown and follow forced singles. Returns the unit that empties and how many crowns it took.
    private func contradiction(placing c: Int) -> (HintUnit, Int)? {
        var t = self
        t.place(c)
        var forced = 0
        for _ in 0..<(n * 3) {
            if let empty = t.openUnits.first(where: { t.cands($0).isEmpty }) { return (empty, forced) }
            if t.queens.count == n { return nil }
            guard let u = t.openUnits.first(where: { t.cands($0).count == 1 }), let s = t.cands(u).first else { return nil }
            t.place(s)
            forced += 1
        }
        return nil
    }

    // MARK: Board geometry

    private mutating func place(_ c: Int) {
        queens.insert(c)
        cand.subtract(attack(c))
    }

    /// The cell plus everything a crown there rules out.
    private func attack(_ c: Int) -> Set<Int> {
        let (r, col) = (c / n, c % n)
        var out = Set<Int>()
        for i in 0..<(n * n) where i / n == r || i % n == col || regionOf[i] == regionOf[c] { out.insert(i) }
        for dr in -1...1 { for dc in -1...1 {
            let rr = r + dr, cc = col + dc
            if rr >= 0, rr < n, cc >= 0, cc < n { out.insert(rr * n + cc) }
        } }
        return out
    }

    private var allUnits: [HintUnit] {
        (0..<n).map { HintUnit.region($0) } + (0..<n).map { .row($0) } + (0..<n).map { .col($0) }
    }

    private var openUnits: [HintUnit] {
        allUnits.filter { u in !cells(u).contains { queens.contains($0) } }
    }

    private func cells(_ u: HintUnit) -> [Int] {
        switch u {
        case .row(let r): return (0..<n).map { r * n + $0 }
        case .col(let c): return (0..<n).map { $0 * n + c }
        case .region(let g): return (0..<(n * n)).filter { regionOf[$0] == g }
        }
    }

    private func cands(_ u: HintUnit) -> Set<Int> { cand.intersection(cells(u)) }

    /// 0 row, 1 column, 2 kingdom.
    private func kind(_ u: HintUnit) -> Int {
        switch u { case .row: 0; case .col: 1; case .region: 2 }
    }

    private func index(_ u: HintUnit) -> Int {
        switch u { case .row(let i), .col(let i), .region(let i): i }
    }

    private func line(_ c: Int, _ axis: Int) -> Int { axis == 0 ? c / n : c % n }

    // MARK: Wording

    private func name(_ u: HintUnit) -> String {
        switch u {
        case .row(let r): "row \(r + 1)"
        case .col(let c): "column \(c + 1)"
        case .region(let g): Theme.regionNames[g % Theme.regionNames.count]
        }
    }

    private func possessive(_ u: HintUnit) -> String { name(u) + "'s" }

    private func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    private func list(_ items: [String]) -> String {
        items.count <= 1 ? items.joined() : items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    private func linesPhrase(_ ls: [Int], _ axis: Int) -> String {
        let word = axis == 0 ? "rows" : "columns"
        let nums = ls.map { $0 + 1 }
        if nums.count > 2, nums.last! - nums.first! == nums.count - 1 { return "\(word) \(nums.first!) to \(nums.last!)" }
        return "\(word) \(list(nums.map(String.init)))"
    }
}

private func combinations<T>(_ items: [T], _ k: Int) -> [[T]] {
    guard k > 0 else { return [[]] }
    guard items.count >= k else { return [] }
    var out: [[T]] = []
    for (i, x) in items.enumerated() {
        for rest in combinations(Array(items[(i + 1)...]), k - 1) { out.append([x] + rest) }
    }
    return out
}
