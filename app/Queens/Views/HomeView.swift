import SwiftUI

struct HomeView: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Queens")
                        .font(.displayLg)
                        .foregroundStyle(Theme.ink)
                    Text("One crown in every row, column and kingdom.")
                        .font(.bodyMd)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.top, 8)

                if let puzzle = store.resumable {
                    NavigationLink(value: Route.puzzle(puzzle.id)) {
                        ContinueCard(puzzle: puzzle, record: store.record(puzzle.id))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(PuzzleLibrary.sizes, id: \.self) { size in
                    NavigationLink(value: Route.realm(size)) {
                        RealmCard(size: size)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ContinueCard: View {
    let puzzle: Puzzle
    let record: PuzzleRecord

    var body: some View {
        HStack(spacing: 16) {
            MiniBoard(puzzle: puzzle)
                .frame(width: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text("Continue")
                    .font(.labelMd)
                    .foregroundStyle(Theme.paper.opacity(0.8))
                Text(puzzle.name)
                    .font(.headlineSm)
                    .foregroundStyle(Theme.paper)
                Text("\(Naming.realm(puzzle.size).name) · \(formatTime(record.elapsed))")
                    .font(.bodySm)
                    .foregroundStyle(Theme.paper.opacity(0.8))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.paper.opacity(0.7))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.ink))
    }
}

private struct RealmCard: View {
    let size: Int
    @Environment(ProgressStore.self) private var store

    var body: some View {
        let realm = Naming.realm(size)
        let total = PuzzleLibrary.shared.puzzles(size).count
        let solved = store.solvedCount(size: size)
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(realm.name)
                    .font(.headlineSm)
                    .foregroundStyle(Theme.ink)
                Text(realm.subtitle)
                    .font(.bodySm)
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 6)
                ProgressBar(value: total == 0 ? 0 : Double(solved) / Double(total), tint: Theme.region(size - 7))
                Text("\(solved) of \(total) crowned")
                    .font(.bodySm)
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            if let puzzle = store.firstUnsolved(size: size) {
                MiniBoard(puzzle: puzzle)
                    .frame(width: 92)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

private struct ProgressBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.sunken)
                Capsule().fill(tint).frame(width: max(value > 0 ? 6 : 0, geo.size.width * value))
            }
        }
        .frame(height: 6)
    }
}
