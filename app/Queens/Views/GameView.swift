import SwiftUI

struct GameView: View {
    @State private var game: GameModel
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    @State private var undoTick = 0
    @State private var hintTick = 0

    init(puzzle: Puzzle, store: ProgressStore) {
        _game = State(initialValue: GameModel(puzzle: puzzle, store: store))
    }

    var body: some View {
        Group {
            if wide {
                // iPad, landscape: board on the left, everything else in a column beside it.
                HStack(spacing: 32) {
                    BoardView(game: game)
                        .padding(.vertical, 24)
                    VStack(spacing: 14) {
                        Spacer(minLength: 0)
                        header
                        outcome
                        controls
                        Spacer(minLength: 0)
                    }
                    .frame(width: 380)
                }
                .padding(.horizontal, 32)
            } else {
                VStack(spacing: 14) {
                    header
                    Spacer(minLength: 4)
                    BoardView(game: game)
                        .padding(.horizontal, 12)
                    outcome
                    controls
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.top, 4)
        .background(PaperBackground(contours: 0.05))
        .animation(.easeOut(duration: 0.25), value: game.clueStep?.text)
        .navigationTitle(Naming.realm(game.n).name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Haptics.shared.prepare()
            game.resume()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "autosolve") { game.debugSolve() }
            #endif
        }
        .onDisappear { game.pause() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { game.resume() } else { game.pause() }
        }
    }

    private var wide: Bool { hSize == .regular && vSize == .regular }

    /// Under the board: the ribbon once solved, otherwise the current clue.
    /// The ribbon sits under the board so it never hides a crown.
    private var outcome: some View {
        Group {
            if game.complete {
                // Just solved: wait for the board's finale. Reopened finished puzzle: show it straight away.
                let fresh = !game.gilded || game.solveTrigger > 0
                SolvedBanner(
                    time: game.elapsed(), newBest: game.newBest, hinted: game.hinted,
                    unfurlDelay: fresh ? SolveTiming.entrance + SolveTiming.ribbon(rows: game.n) : 0.1,
                    stampDelay: fresh ? SolveTiming.entrance + SolveTiming.stamp(rows: game.n) : 0.4,
                    countUp: fresh
                )
            } else if let step = game.clueStep {
                Text(step.text)
                    .font(.bodyMd)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .id(step.text)
                    .transition(.asymmetric(insertion: .offset(y: 8).combined(with: .opacity), removal: .opacity))
            } else {
                Text(" ").font(.bodyMd)
            }
        }
        .frame(minHeight: 52)
        .padding(.top, 24)
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(game.puzzle.name)
                .font(.headlineMd)
                .foregroundStyle(Theme.ink)
            HStack(spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text("\(game.queenCount) of \(game.n) crowned · \(formatTime(game.elapsed(at: ctx.date)))")
                        .font(.timer)
                        .foregroundStyle(Theme.muted)
                        .contentTransition(.numericText())
                }
                TierDots(tier: game.puzzle.tier)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var controls: some View {
        if game.complete {
            // On a fresh solve the buttons arrive with the ribbon, not over the coronation.
            let fresh = !game.gilded || game.solveTrigger > 0
            HStack(spacing: 12) {
                Button("Play again") { game.playAgain() }
                    .buttonStyle(PillButtonStyle())
                if let next = PuzzleLibrary.shared.next(after: game.puzzle) {
                    Button("Next puzzle") { router.replaceLast(with: .puzzle(next.id)) }
                        .buttonStyle(PillButtonStyle(prominent: true))
                }
            }
            .transition(.opacity.animation(.easeOut(duration: 0.4).delay(fresh ? SolveTiming.entrance + SolveTiming.ribbon(rows: game.n) + 0.3 : 0)))
        } else {
            HStack(spacing: 12) {
                Button { game.undo(); undoTick += 1 } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .symbolEffect(.bounce.down, value: undoTick)
                }
                    .disabled(!game.canUndo)
                Button { game.clear() } label: { Label("Clear", systemImage: "eraser") }
                    .disabled(game.isBlank)
                Button { game.hint(); hintTick += 1 } label: {
                    Label(game.clueHasMore ? "More" : "Hint", systemImage: game.clueHasMore ? "lightbulb.fill" : "lightbulb")
                        .symbolEffect(.bounce, value: hintTick)
                }
            }
            .buttonStyle(PillButtonStyle())
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .fixedSize()
            .transition(.opacity)
        }
    }
}
