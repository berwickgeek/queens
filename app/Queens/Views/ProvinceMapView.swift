import SwiftUI

/// One province as a map: its twenty puzzles are stops on a road climbing to a castle, inked as
/// far as the traveller has gone. Every stop opens its puzzle, the ones ahead included; the slim
/// card goes to the next puzzle to play.
struct ProvinceMapView: View {
    let province: Journey.Province
    @Environment(ProgressStore.self) private var store
    @State private var terrain: ProvinceSheet.Terrain?

    private typealias L = Journey.Layout

    var body: some View {
        let all = PuzzleLibrary.shared.puzzles(province.size)
        let realmStates = Journey.stopStates(solved: store.solvedFlags(size: province.size))
        let range = min(all.count, province.numbers.lowerBound - 1) ..< min(all.count, province.numbers.upperBound)
        let puzzles = Array(all[range])
        let states = Array(realmStates[range])
        let next = nextPuzzle(all, realmStates: realmStates, range: range)
        ScrollViewReader { proxy in
            ScrollView {
                ZStack {
                    if let terrain {
                        AtlasSheet(pencil: terrain.pencil, ink: terrain.ink, height: L.provinceHeight,
                                   boundary: ProvinceSheet.boundary(province, states: states))
                    } else {
                        AtlasPaper()
                    }
                    AtlasCanvas(drawing: ProvinceSheet.live(province, states: states), height: L.provinceHeight)
                    stopButtons(puzzles, states: states)
                }
                .aspectRatio(L.width / L.provinceHeight, contentMode: .fit)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .background(Theme.Atlas.paper)
            .safeAreaInset(edge: .bottom) {
                if let next {
                    NavigationLink(value: Route.puzzle(next.id)) {
                        SlimMapCard(caption: "No. \(next.number) · \(Journey.province(of: next).name)", puzzle: next)
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .frame(maxWidth: 640)
                }
            }
            .onAppear {
                let focus = states.firstIndex(of: .current) ?? states.firstIndex(of: .skipped) ?? 0
                proxy.scrollTo(focus, anchor: .center)
            }
        }
        .task { terrain = await ProvinceSheet.terrain(province) }
        .navigationTitle(province.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(province.name).font(.serif(18)).foregroundStyle(Theme.ink)
                    Text("No. \(province.numbers.lowerBound) to \(province.numbers.lowerBound + puzzles.count - 1) · \(states.filter { $0 == .solved }.count) solved")
                        .font(.sans(11, .bold)).foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The card's puzzle: this province's current or first skipped stop, else the realm's current.
    private func nextPuzzle(_ all: [Puzzle], realmStates: [Journey.StopState], range: Range<Int>) -> Puzzle? {
        let here = realmStates[range]
        let i = here.firstIndex(of: .current) ?? here.firstIndex(of: .skipped) ?? realmStates.firstIndex(of: .current)
        return i.map { all[$0] }
    }

    /// A clear 44pt button over each stop, which also carries its accessibility label and anchors the scroll.
    private func stopButtons(_ puzzles: [Puzzle], states: [Journey.StopState]) -> some View {
        GeometryReader { geo in
            let k = geo.size.width / L.width
            ForEach(puzzles.indices, id: \.self) { j in
                let p = L.provinceStop(province, j)
                NavigationLink(value: Route.puzzle(puzzles[j].id)) {
                    Color.clear.contentShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .position(x: p.x * k, y: p.y * k)
                .id(j)
                .accessibilityLabel(label(puzzles[j], state: states[j]))
            }
        }
    }

    private func label(_ puzzle: Puzzle, state: Journey.StopState) -> String {
        let status = switch state {
        case .solved: "solved"
        case .skipped: "skipped"
        case .current: "current"
        case .ahead: "uncharted"
        }
        return "Puzzle \(puzzle.number), \(puzzle.name), \(status)"
    }
}
