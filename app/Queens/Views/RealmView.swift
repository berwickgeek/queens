import SwiftUI

struct RealmView: View {
    let size: Int
    @Environment(ProgressStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        let puzzles = PuzzleLibrary.shared.puzzles(size)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(puzzles) { puzzle in
                        NavigationLink(value: Route.puzzle(puzzle.id)) {
                            PuzzleTile(puzzle: puzzle, record: store.records[puzzle.id])
                        }
                        .buttonStyle(PressableStyle())
                        .id(puzzle.id)
                    }
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                if let first = store.firstUnsolved(size: size) {
                    proxy.scrollTo(first.id, anchor: .center)
                }
            }
        }
        .background(PaperBackground())
        .navigationTitle(Naming.realm(size).name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PuzzleTile: View {
    let puzzle: Puzzle
    let record: PuzzleRecord?

    var body: some View {
        let solved = record?.solvedOnce == true
        let inProgress = record?.inProgress == true
        // The square sets the size; the content sits on it, so it can never spill over the border.
        RoundedRectangle(cornerRadius: 12)
            .fill(solved ? Theme.region(puzzle.number - 1) : Theme.card)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(inProgress ? Theme.ink : Theme.border, lineWidth: inProgress ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                // A small gold crown marks a puzzle that has been crowned.
                if solved {
                    ZStack {
                        Crown().fill(Theme.gold)
                        Crown().stroke(Theme.goldDeep, lineWidth: 0.7)
                    }
                    .frame(width: 15, height: 15)
                    .rotationEffect(.degrees(12))
                    .padding(6)
                }
            }
            .overlay {
                VStack(spacing: 6) {
                    Text("\(puzzle.number)")
                        .font(.serif(22))
                        .foregroundStyle(Theme.ink)
                    if solved, let best = record?.bestTime {
                        Text(formatTime(best))
                            .font(.sans(12, .bold).monospacedDigit())
                            .foregroundStyle(Theme.ink.opacity(0.75))
                    } else {
                        TierDots(tier: puzzle.tier, dot: 5)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Puzzle \(puzzle.number), \(solved ? "crowned" : inProgress ? "in progress" : "difficulty \(puzzle.tier)")")
    }
}
