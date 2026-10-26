import Foundation
import Observation

struct PuzzleRecord: Codable {
    /// Current attempt, one character per cell: "." empty, "x" cross, "q" queen.
    var marks = ""
    var elapsed: Double = 0
    var complete = false
    var hinted = false
    /// Ever solved, for ticks in the picker. Survives "Play again".
    var solvedOnce = false
    /// Best unhinted time.
    var bestTime: Double?
    var lastPlayed = Date()

    var started: Bool { elapsed > 0 || marks.contains(where: { $0 != "." }) }
    var inProgress: Bool { started && !complete }
}

/// All progress, stored as one JSON file in Application Support. Local only.
@MainActor @Observable
final class ProgressStore {
    private(set) var records: [String: PuzzleRecord] = [:]
    private(set) var lastPuzzleId: String?

    private struct File: Codable {
        var records: [String: PuzzleRecord]
        var lastPuzzleId: String?
    }

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("progress.json")
    }()

    init() {
        guard let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return }
        records = file.records
        lastPuzzleId = file.lastPuzzleId
    }

    func record(_ id: String) -> PuzzleRecord { records[id] ?? PuzzleRecord() }

    func update(_ id: String, _ change: (inout PuzzleRecord) -> Void) {
        var r = record(id)
        change(&r)
        r.lastPlayed = Date()
        records[id] = r
        lastPuzzleId = id
        save()
    }

    func solvedCount(size: Int) -> Int {
        PuzzleLibrary.shared.puzzles(size).filter { records[$0.id]?.solvedOnce == true }.count
    }

    func firstUnsolved(size: Int) -> Puzzle? {
        let list = PuzzleLibrary.shared.puzzles(size)
        return list.first { records[$0.id]?.solvedOnce != true } ?? list.last
    }

    /// The puzzle to offer as "Continue": the last one touched, if unfinished.
    var resumable: Puzzle? {
        guard let id = lastPuzzleId, record(id).inProgress else { return nil }
        return PuzzleLibrary.shared.byId[id]
    }

    private func save() {
        let file = File(records: records, lastPuzzleId: lastPuzzleId)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(file).write(to: url, options: .atomic)
        } catch {
            print("progress save failed: \(error)")
        }
    }
}
