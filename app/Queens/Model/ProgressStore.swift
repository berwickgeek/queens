import Foundation
import Observation

struct PuzzleRecord: Codable {
    /// Current attempt, one character per cell: "." empty, "x" cross, "q" queen.
    var marks = ""
    /// The board saved by Pin, in the same form as `marks`.
    var pin: String?
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

    /// Combine two devices' copies: the attempt comes from whichever was played last,
    /// while solved and best time keep the best of both.
    func merged(with other: PuzzleRecord) -> PuzzleRecord {
        var r = other.lastPlayed > lastPlayed ? other : self
        r.solvedOnce = solvedOnce || other.solvedOnce
        r.bestTime = [bestTime, other.bestTime].compactMap { $0 }.min()
        return r
    }

    /// True when `self` holds something `other` lacks, so it is worth sending.
    func improves(_ other: PuzzleRecord) -> Bool {
        solvedOnce != other.solvedOnce || bestTime != other.bestTime
            || lastPlayed.timeIntervalSince(other.lastPlayed) > 0.001
    }
}

/// All progress, stored as one JSON file in Application Support, and mirrored to the iCloud
/// key-value store (one key per puzzle) so an iPhone and an iPad share it. The local file stays
/// the source of truth offline; iCloud copies are merged in with `PuzzleRecord.merged`.
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

    private let cloud = NSUbiquitousKeyValueStore.default
    private static let cloudPrefix = "p."
    private var pending: Set<String> = []
    private var flushTask: Task<Void, Never>?

    init() {
        if let data = try? Data(contentsOf: url),
           let file = try? JSONDecoder().decode(File.self, from: data) {
            records = file.records
            lastPuzzleId = file.lastPuzzleId
        }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, queue: .main
        ) { [weak self] note in
            let keys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
            MainActor.assumeIsolated { self?.pullCloud(keys: keys) }
        }
        cloud.synchronize()
        pullCloud(keys: nil)
        // Send up anything recorded before sync existed, or while offline.
        for (id, r) in records where cloudRecord(id).map({ r.improves($0) }) ?? true {
            pushCloud(id, r)
        }
    }

    // MARK: iCloud

    private func cloudRecord(_ id: String) -> PuzzleRecord? {
        cloud.data(forKey: Self.cloudPrefix + id).flatMap { try? JSONDecoder().decode(PuzzleRecord.self, from: $0) }
    }

    /// Writes on every move get throttled by iCloud, so moves are batched: a record is sent
    /// 2s after its last change, or straight away when the app leaves the foreground.
    private func pushCloud(_ id: String, _ r: PuzzleRecord, soon: Bool = false) {
        if soon {
            pending.insert(id)
            flushTask?.cancel()
            flushTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                self?.flushCloud()
            }
            return
        }
        guard let data = try? JSONEncoder().encode(r) else { return }
        cloud.set(data, forKey: Self.cloudPrefix + id)
    }

    /// Send any batched records and ask iCloud to sync now.
    func flushCloud() {
        flushTask?.cancel()
        for id in pending { pushCloud(id, record(id)) }
        pending.removeAll()
        cloud.synchronize()
    }

    /// On returning to the foreground, fetch what the other device has sent.
    func refreshFromCloud() {
        cloud.synchronize()
        pullCloud(keys: nil)
    }

    /// Merge iCloud copies into local records. `keys` nil means every key.
    private func pullCloud(keys: [String]?) {
        let ids = (keys ?? Array(cloud.dictionaryRepresentation.keys))
            .filter { $0.hasPrefix(Self.cloudPrefix) }
            .map { String($0.dropFirst(Self.cloudPrefix.count)) }
        var changed = false
        for id in ids {
            guard let remote = cloudRecord(id) else { continue }
            let local = records[id]
            let merged = local.map { $0.merged(with: remote) } ?? remote
            if local.map({ merged.improves($0) }) ?? true {
                records[id] = merged
                changed = true
                // Played more recently elsewhere: offer it as Continue here too.
                if let last = lastPuzzleId, last != id, merged.lastPlayed > record(last).lastPlayed { lastPuzzleId = id }
                if lastPuzzleId == nil { lastPuzzleId = id }
            }
            if merged.improves(remote) { pushCloud(id, merged) }
        }
        if changed { saveFile() }
    }

    func record(_ id: String) -> PuzzleRecord { records[id] ?? PuzzleRecord() }

    func update(_ id: String, _ change: (inout PuzzleRecord) -> Void) {
        var r = record(id)
        change(&r)
        r.lastPlayed = Date()
        records[id] = r
        lastPuzzleId = id
        saveFile()
        pushCloud(id, r, soon: true)
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

    private func saveFile() {
        let file = File(records: records, lastPuzzleId: lastPuzzleId)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(file).write(to: url, options: .atomic)
        } catch {
            print("progress save failed: \(error)")
        }
    }
}
