import Observation
import SwiftUI

enum Mark: Character {
    case empty = ".", cross = "x", queen = "q"
}

/// One puzzle being played: marks, undo, clashes, timer, hints. Persists every change.
@MainActor @Observable
final class GameModel {
    let puzzle: Puzzle
    let n: Int

    private(set) var marks: [Mark]
    private(set) var clashes: Set<Int> = []
    private(set) var complete: Bool
    private(set) var hinted: Bool
    private(set) var bestTime: Double?
    private(set) var newBest = false
    private(set) var hintCell: Int?
    private(set) var hintText: String?
    /// Bumped to replay the clash shake and the solve bounce.
    private(set) var clashTrigger = 0
    private(set) var solveTrigger = 0

    private var undoStack: [[Mark]] = []
    private var accumulated: Double
    private var runningSince: Date?
    private let store: ProgressStore

    private enum DragMode { case cross, erase }
    private var dragStart: Int?
    private var dragMode: DragMode?
    private var dragMoved = false

    init(puzzle: Puzzle, store: ProgressStore) {
        self.puzzle = puzzle
        self.store = store
        n = puzzle.size
        let rec = store.record(puzzle.id)
        let saved = rec.marks.compactMap(Mark.init(rawValue:))
        marks = saved.count == puzzle.size * puzzle.size ? saved : Array(repeating: .empty, count: puzzle.size * puzzle.size)
        accumulated = rec.elapsed
        complete = rec.complete
        hinted = rec.hinted
        bestTime = rec.bestTime
        clashes = computeClashes()
    }

    // MARK: Derived

    var queenCount: Int { marks.lazy.filter { $0 == .queen }.count }
    var canUndo: Bool { !undoStack.isEmpty && !complete }
    var isBlank: Bool { !marks.contains { $0 != .empty } }

    var claimedRegions: Set<Int> {
        Set(marks.indices.filter { marks[$0] == .queen }.map { puzzle.regionOf[$0] })
    }

    func elapsed(at date: Date = Date()) -> Double {
        accumulated + (runningSince.map { date.timeIntervalSince($0) } ?? 0)
    }

    // MARK: Timer

    func resume() {
        guard !complete, runningSince == nil else { return }
        runningSince = Date()
    }

    func pause() {
        if let start = runningSince {
            accumulated += Date().timeIntervalSince(start)
            runningSince = nil
        }
        persist()
    }

    // MARK: Touch input. A touch that stays in one cell is a tap; leaving it starts a drag.

    func touchBegan(_ cell: Int) {
        guard !complete else { return }
        dragStart = cell
        dragMoved = false
        dragMode = nil
    }

    func touchMoved(_ cell: Int) {
        guard !complete, let start = dragStart else { return }
        if !dragMoved {
            guard cell != start else { return }
            dragMoved = true
            // Dragging from a cross erases crosses; from anywhere else it lays them.
            dragMode = marks[start] == .cross ? .erase : .cross
            pushUndo()
            paint(start)
        }
        paint(cell)
    }

    func touchEnded() {
        defer { dragStart = nil; dragMode = nil }
        guard !complete, let start = dragStart else { return }
        if dragMoved { persist() } else { tap(start) }
    }

    private func paint(_ cell: Int) {
        switch dragMode {
        case .cross where marks[cell] == .empty:
            marks[cell] = .cross
            Haptics.shared.cross()
        case .erase where marks[cell] == .cross:
            marks[cell] = .empty
            Haptics.shared.cross()
        default:
            break
        }
    }

    /// Empty, then cross, then queen, then empty.
    func tap(_ cell: Int) {
        pushUndo()
        clearHint()
        switch marks[cell] {
        case .empty:
            marks[cell] = .cross
            Haptics.shared.cross()
        case .cross:
            withAnimation(.spring(duration: 0.4, bounce: 0.4)) { marks[cell] = .queen }
            queenPlaced(cell)
        case .queen:
            marks[cell] = .empty
            Haptics.shared.remove()
            withAnimation(.easeOut(duration: 0.2)) { clashes = computeClashes() }
        }
        persist()
    }

    private func queenPlaced(_ cell: Int) {
        withAnimation(.easeOut(duration: 0.2)) { clashes = computeClashes() }
        if clashes.contains(cell) {
            Haptics.shared.clash()
            withAnimation(.linear(duration: 0.36)) { clashTrigger += 1 }
        } else if queenCount == n && clashes.isEmpty {
            solve()
        } else {
            Haptics.shared.queen()
        }
    }

    private func solve() {
        let time = elapsed()
        accumulated = time
        runningSince = nil
        complete = true
        undoStack.removeAll()
        if !hinted, bestTime.map({ time < $0 }) ?? true {
            newBest = bestTime != nil
            bestTime = time
        }
        Haptics.shared.solved()
        // Let the last crown finish its entrance before every crown bounces.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            solveTrigger += 1
        }
    }

    // MARK: Commands

    func undo() {
        guard !complete, let last = undoStack.popLast() else { return }
        clearHint()
        marks = last
        withAnimation(.easeOut(duration: 0.2)) { clashes = computeClashes() }
        Haptics.shared.undo()
        persist()
    }

    func clear() {
        guard !complete, !isBlank else { return }
        pushUndo()
        clearHint()
        withAnimation(.easeOut(duration: 0.25)) {
            marks = Array(repeating: .empty, count: n * n)
            clashes = []
        }
        Haptics.shared.undo()
        persist()
    }

    func playAgain() {
        marks = Array(repeating: .empty, count: n * n)
        clashes = []
        undoStack.removeAll()
        accumulated = 0
        complete = false
        hinted = false
        newBest = false
        persist()
        resume()
    }

    /// Points at a mistake if there is one, otherwise at the most constrained queen still to place.
    func hint() {
        guard !complete else { return }
        hinted = true
        let answer = puzzle.solutionCells
        if let wrong = marks.indices.first(where: { marks[$0] == .queen && !answer.contains($0) }) {
            showHint(wrong, "That crown is in the wrong place.")
        } else if let wrong = marks.indices.first(where: { marks[$0] == .cross && answer.contains($0) }) {
            showHint(wrong, "A crown belongs under that cross.")
        } else {
            let open = answer.filter { marks[$0] != .queen }
            let best = open.min { openCells(inRegionOf: $0) < openCells(inRegionOf: $1) }
            if let best { showHint(best, "A crown belongs here.") }
        }
        Haptics.shared.undo()
        persist()
    }

    private func openCells(inRegionOf cell: Int) -> Int {
        let g = puzzle.regionOf[cell]
        return marks.indices.filter { puzzle.regionOf[$0] == g && marks[$0] == .empty }.count
    }

    private func showHint(_ cell: Int, _ text: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            hintCell = cell
            hintText = text
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, self.hintCell == cell else { return }
            self.clearHint()
        }
    }

    private func clearHint() {
        guard hintCell != nil else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            hintCell = nil
            hintText = nil
        }
    }

    // MARK: Rules

    private func pushUndo() {
        undoStack.append(marks)
        if undoStack.count > 500 { undoStack.removeFirst() }
    }

    /// Queens sharing a row, column or region, or touching (diagonals included).
    private func computeClashes() -> Set<Int> {
        let queens = marks.indices.filter { marks[$0] == .queen }
        var out = Set<Int>()
        for i in queens.indices {
            for j in queens.indices where j > i {
                let a = queens[i], b = queens[j]
                let (ar, ac, br, bc) = (a / n, a % n, b / n, b % n)
                if ar == br || ac == bc || puzzle.regionOf[a] == puzzle.regionOf[b]
                    || (abs(ar - br) <= 1 && abs(ac - bc) <= 1) {
                    out.insert(a)
                    out.insert(b)
                }
            }
        }
        return out
    }

    private func persist() {
        let marks = String(self.marks.map(\.rawValue))
        let elapsed = elapsed()
        store.update(puzzle.id) { r in
            r.marks = marks
            r.elapsed = elapsed
            r.complete = complete
            r.hinted = hinted
            r.bestTime = bestTime
            if complete { r.solvedOnce = true }
        }
    }
}
