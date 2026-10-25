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
                .overlay {
                    if game.complete {
                        SolvedBanner(time: game.elapsed(), newBest: game.newBest, hinted: game.hinted)
                    }
                }
                .padding(.horizontal, 12)
            Text(game.hintText ?? " ")
                .font(.bodyMd)
                .foregroundStyle(Theme.muted)
                .frame(minHeight: 22)
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
                Button { game.hint() } label: { Label("Hint", systemImage: "lightbulb") }
            }
            .buttonStyle(PillButtonStyle())
            .labelStyle(.titleAndIcon)
            .transition(.opacity)
        }
    }
}
