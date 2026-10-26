import Foundation

struct Puzzle: Decodable, Identifiable, Hashable {
    let id: String
    let size: Int
    /// Column of the queen in each row.
    let solution: [Int]
    /// Difficulty 1 to 5: the hardest logic rule the generator needed.
    let tier: Int
    /// Region index (0-based) for each cell, row-major.
    let regionOf: [Int]

    private enum CodingKeys: String, CodingKey { case id, size, regions, solution, tier }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        size = try c.decode(Int.self, forKey: .size)
        solution = try c.decode([Int].self, forKey: .solution)
        tier = try c.decode(Int.self, forKey: .tier)
        regionOf = try c.decode(String.self, forKey: .regions).utf8.map { Int($0) - 97 }
    }

    /// 1-based position within its realm.
    var number: Int { Int(id.split(separator: "-").last ?? "") ?? 0 }
    var name: String { Naming.puzzleName(size: size, number: number) }
    var solutionCells: Set<Int> { Set(solution.enumerated().map { $0.offset * size + $0.element }) }
}

final class PuzzleLibrary {
    static let shared = PuzzleLibrary()
    static let sizes = [7, 8, 9, 10, 11]

    let bySize: [Int: [Puzzle]]
    let byId: [String: Puzzle]

    private init() {
        guard let url = Bundle.main.url(forResource: "puzzles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([String: [Puzzle]].self, from: data)
        else { fatalError("puzzles.json missing from the bundle") }
        var bySize: [Int: [Puzzle]] = [:]
        for (key, list) in raw { bySize[Int(key) ?? 0] = list }
        self.bySize = bySize
        byId = Dictionary(uniqueKeysWithValues: bySize.values.flatMap { $0 }.map { ($0.id, $0) })
    }

    func puzzles(_ size: Int) -> [Puzzle] { bySize[size] ?? [] }

    func next(after puzzle: Puzzle) -> Puzzle? {
        let list = puzzles(puzzle.size)
        guard let i = list.firstIndex(of: puzzle), i + 1 < list.count else { return nil }
        return list[i + 1]
    }
}
