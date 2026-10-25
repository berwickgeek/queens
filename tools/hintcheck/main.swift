// Plays every puzzle using only hints: each clue's last step is applied (crown on a single, crosses otherwise).
// Fails if a clue ever marks a solution cell with a cross, or a puzzle gets stuck.
// Run: tools/hintcheck/run.sh
import Foundation

enum Mark: Character { case empty = ".", cross = "x", queen = "q" }
enum Theme { static let regionNames = ["blue", "apricot", "green", "coral", "lavender", "yellow", "teal", "pink", "olive", "orange", "periwinkle"] }

let data = try! Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let raw = try! JSONDecoder().decode([String: [Puzzle]].self, from: data)
var tally: [String: Int] = [:]
var failures = 0, total = 0
for (_, list) in raw.sorted(by: { $0.key < $1.key }) {
    for p in list {
        total += 1
        let answer = p.solutionCells
        var marks = [Mark](repeating: .empty, count: p.size * p.size)
        var ok = true
        for _ in 0..<(p.size * p.size * 2) {
            if marks.filter({ $0 == .queen }).count == p.size { break }
            guard let clue = HintEngine(puzzle: p, marks: marks).next() else { ok = false; print("\(p.id): stuck"); break }
            let first = clue.steps[0].text
            let key = first.contains("down to two") || first.hasPrefix("Imagine") ? "fork" : String(first.split(separator: " ").dropFirst().prefix(3).joined(separator: " "))
            tally[key, default: 0] += 1
            if clue.steps.last!.text.hasPrefix("Its crown") {
                let c = clue.targets.first!
                if !answer.contains(c) { ok = false; print("\(p.id): bad crown"); break }
                marks[c] = .queen
            } else {
                if !clue.targets.isDisjoint(with: answer) { ok = false; print("\(p.id): crossed a solution cell: \(clue.steps.map(\.text))"); break }
                for c in clue.targets { marks[c] = .cross }
            }
        }
        if ok && marks.filter({ $0 == .queen }).count != p.size { ok = false; print("\(p.id): ran out of moves") }
        if !ok { failures += 1 }
    }
}
print("\(total) puzzles, \(failures) failures")
for (k, v) in tally.sorted(by: { $0.value > $1.value }).prefix(12) { print(v, k) }
