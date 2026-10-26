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
    /// The clue on show and how far into it the player has asked.
    private(set) var clue: Clue?
    private(set) var clueLevel = 0
    /// Bumped to replay the clash shake and the solve bounce.
    private(set) var clashTrigger = 0
    private(set) var solveTrigger = 0
    /// The crown most recently placed without a clash, and a bump for its ink drop.
    private(set) var lastPlaced = 0
    private(set) var placeTrigger = 0
    /// Crowns turn gold once the solve celebration starts (and stay gold on a finished board).
    private(set) var gilded: Bool
    /// The board as it was when pinned, so a guess can be tested and abandoned. One pin per game.
    private(set) var pin: [Mark]?

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
        gilded = rec.complete
        hinted = rec.hinted
        bestTime = rec.bestTime
        pin = rec.pin.map { $0.compactMap(Mark.init(rawValue:)) }.flatMap { $0.count == marks.count ? $0 : nil }
        clashes = computeClashes()
    }

    // MARK: Derived

    var queenCount: Int { marks.lazy.filter { $0 == .queen }.count }
    var canUndo: Bool { !undoStack.isEmpty && !complete }
    var isBlank: Bool { !marks.contains { $0 != .empty } }
    var canReturn: Bool { pin.map { $0 != marks } ?? false }

    /// A mark made since the pin, drawn in pencil until the guess is kept or abandoned.
    func pencilled(_ i: Int) -> Bool { pin.map { $0[i] != marks[i] } ?? false }

    var clueStep: ClueStep? { clue.map { $0.steps[min(clueLevel, $0.steps.count - 1)] } }
    var clueHasMore: Bool { clue.map { clueLevel < $0.steps.count - 1 } ?? false }

    /// Cells inside the spotlighted rows, columns and kingdoms.
    var clueFocusCells: Set<Int> {
        guard let step = clueStep else { return [] }
        var out = Set<Int>()
        for u in step.focus {
            for i in 0..<(n * n) {
                switch u {
                case .row(let r) where i / n == r: out.insert(i)
                case .col(let c) where i % n == c: out.insert(i)
                case .region(let g) where puzzle.regionOf[i] == g: out.insert(i)
                default: break
                }
            }
        }
        return out
    }

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
        if dragMoved { refreshClue(); persist() } else { tap(start) }
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
        defer { refreshClue() }
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
        } else {
            lastPlaced = cell
            placeTrigger += 1
            if queenCount == n && clashes.isEmpty { solve() } else { Haptics.shared.queen() }
        }
    }

    private func solve() {
        let time = elapsed()
        accumulated = time
        runningSince = nil
        complete = true
        pin = nil
        undoStack.removeAll()
        if !hinted, bestTime.map({ time < $0 }) ?? true {
            newBest = bestTime != nil
            bestTime = time
        }
        Haptics.shared.queen()
        // Let the last crown finish its entrance before every crown bounces.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard complete else { return }
            Haptics.shared.solved(rows: n)
            gilded = true
            solveTrigger += 1
        }
    }

    // MARK: Commands

    #if DEBUG
    /// Plays the solution in a crown at a time, for recording the celebration (launch with `-autosolve YES`).
    func debugSolve() {
        Task { @MainActor in
            for row in 0..<n {
                try? await Task.sleep(for: .milliseconds(350))
                let cell = row * n + puzzle.solution[row]
                while marks[cell] != .queen { tap(cell) }
            }
        }
    }
    #endif

    func undo() {
        guard !complete, let last = undoStack.popLast() else { return }
        marks = last
        refreshClue()
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

    /// Saves the board as it stands, to come back to with `returnToPin`.
    func setPin() {
        guard !complete, pin == nil, !isBlank else { return }
        pin = marks
        Haptics.shared.undo()
        persist()
    }

    /// Puts the board back as it was when pinned and lifts the pin. Undo can bring the guess back.
    func returnToPin() {
        guard !complete, let saved = pin, canReturn else { return }
        pushUndo()
        withAnimation(.easeOut(duration: 0.25)) {
            marks = saved
            pin = nil
            clashes = computeClashes()
        }
        refreshClue()
        Haptics.shared.undo()
        persist()
    }

    func playAgain() {
        clue = nil
        pin = nil
        marks = Array(repeating: .empty, count: n * n)
        clashes = []
        undoStack.removeAll()
        accumulated = 0
        complete = false
        gilded = false
        hinted = false
        newBest = false
        persist()
        resume()
    }

    /// Points at a mistake if there is one. Otherwise gives the easiest deduction, a step at a time:
    /// asking again for the same deduction reveals its next step.
    func hint() {
        guard !complete else { return }
        hinted = true
        let answer = puzzle.solutionCells
        let fresh: Clue
        if let wrong = marks.indices.first(where: { marks[$0] == .queen && !answer.contains($0) }) {
            fresh = Clue(steps: [ClueStep(text: "That crown is in the wrong place.", cells: [wrong])], targets: [wrong], transient: true)
        } else if let wrong = marks.indices.first(where: { marks[$0] == .cross && answer.contains($0) }) {
            fresh = Clue(steps: [ClueStep(text: "A crown belongs under that cross.", cells: [wrong])], targets: [wrong], transient: true)
        } else if let found = HintEngine(puzzle: puzzle, marks: marks).next() {
            fresh = found
        } else {
            // The engine covers every rule the generator used, so this is only a backstop.
            guard let cell = answer.first(where: { marks[$0] != .queen }) else { return }
            fresh = Clue(steps: [ClueStep(text: "A crown belongs here.", cells: [cell])], targets: [cell])
        }
        withAnimation(.easeOut(duration: 0.25)) {
            if let clue, clue.targets == fresh.targets, !fresh.transient {
                clueLevel = min(clueLevel + 1, clue.steps.count - 1)
            } else {
                clue = fresh
                clueLevel = 0
            }
        }
        Haptics.shared.undo()
        persist()
    }

    /// A clue stays up while the player acts on it, and goes once its cells are all marked.
    private func refreshClue() {
        guard let clue else { return }
        if clue.transient || clue.targets.allSatisfy({ marks[$0] != .empty }) { clearHint() }
    }

    private func clearHint() {
        guard clue != nil else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            clue = nil
            clueLevel = 0
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
        let pin = self.pin.map { String($0.map(\.rawValue)) }
        let elapsed = elapsed()
        store.update(puzzle.id) { r in
            r.marks = marks
            r.elapsed = elapsed
            r.complete = complete
            r.hinted = hinted
            r.bestTime = bestTime
            r.pin = pin
            if complete { r.solvedOnce = true }
        }
    }
}
