import SwiftUI

struct RealmView: View {
    let size: Int
    @Environment(ProgressStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        let puzzles = PuzzleLibrary.shared.puzzles(size)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(puzzles) { puzzle in
                        NavigationLink(value: Route.puzzle(puzzle.id)) {
                            PuzzleTile(puzzle: puzzle, record: store.records[puzzle.id])
                        }
                        .buttonStyle(.plain)
                        .id(puzzle.id)
                    }
                }
                .padding(20)
            }
            .onAppear {
                if let first = store.firstUnsolved(size: size) {
                    proxy.scrollTo(first.id, anchor: .center)
                }
            }
        }
        .background(Theme.paper)
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
        VStack(spacing: 5) {
            Text("\(puzzle.number)")
                .font(.serif(19))
                .foregroundStyle(Theme.ink)
            if solved, let best = record?.bestTime {
                Text(formatTime(best))
                    .font(.sans(11, .bold).monospacedDigit())
                    .foregroundStyle(Theme.ink.opacity(0.75))
            } else {
                TierDots(tier: puzzle.tier, dot: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(solved ? Theme.region(puzzle.number - 1) : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(inProgress ? Theme.ink : Theme.border, lineWidth: inProgress ? 2 : 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Puzzle \(puzzle.number), \(solved ? "crowned" : inProgress ? "in progress" : "difficulty \(puzzle.tier)")")
    }
}
