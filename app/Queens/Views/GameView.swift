import SwiftUI

struct GameView: View {
    @State private var game: GameModel
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    init(puzzle: Puzzle, store: ProgressStore) {
        _game = State(initialValue: GameModel(puzzle: puzzle, store: store))
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            Spacer(minLength: 4)
            BoardView(game: game)
                .padding(.horizontal, 12)
            // The ribbon sits under the board so it never hides a crown.
            Group {
                if game.complete {
                    // Just solved: wait for the board's finale. Reopened finished puzzle: show it straight away.
                    let fresh = !game.gilded || game.solveTrigger > 0
                    SolvedBanner(
                        time: game.elapsed(), newBest: game.newBest, hinted: game.hinted,
                        unfurlDelay: fresh ? SolveTiming.entrance + SolveTiming.finale(rows: game.n) : 0.1,
                        stampDelay: fresh ? SolveTiming.entrance + SolveTiming.stamp(rows: game.n) : 0.4
                    )
                } else if let step = game.clueStep {
                    Text(step.text)
                        .font(.bodyMd)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .id(step.text)
                        .transition(.opacity)
                } else {
                    Text(" ").font(.bodyMd)
                }
            }
            .frame(minHeight: 52)
            .padding(.top, 24)
            controls
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .background(Theme.paper)
        .navigationTitle(Naming.realm(game.n).name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Haptics.shared.prepare()
            game.resume()
        }
        .onDisappear { game.pause() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { game.resume() } else { game.pause() }
        }
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
            HStack(spacing: 12) {
                Button("Play again") { game.playAgain() }
                    .buttonStyle(PillButtonStyle())
                if let next = PuzzleLibrary.shared.next(after: game.puzzle) {
                    Button("Next puzzle") { router.replaceLast(with: .puzzle(next.id)) }
                        .buttonStyle(PillButtonStyle(prominent: true))
                }
            }
            .transition(.opacity)
        } else {
            HStack(spacing: 12) {
                Button { game.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(!game.canUndo)
                Button { game.clear() } label: { Label("Clear", systemImage: "eraser") }
                    .disabled(game.isBlank)
                Button { game.hint() } label: {
                    Label(game.clueHasMore ? "More" : "Hint", systemImage: game.clueHasMore ? "lightbulb.fill" : "lightbulb")
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
