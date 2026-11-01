import SwiftUI

/// One province as a map: its twenty puzzles are stops on a road climbing to a castle, inked as
/// far as the traveller has gone. Every stop opens its puzzle, the ones ahead included; the slim
/// card goes to the next puzzle to play. The first time it shows a solve, the traveller walks
/// the last leg (`TravelOverlay`).
struct ProvinceMapView: View {
    let province: Journey.Province
    @Environment(ProgressStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var terrain: ProvinceSheet.Terrain?
    /// The leg being walked, from appear until `Travel.total` after the trigger bumps.
    @State private var leg: ProvinceGeometry.Leg?
    @State private var travelTrigger = 0
    @State private var started = false
    /// The ink edge has been sent up to the new stop.
    @State private var inked = false
    /// The card and solved count have moved on to the new stop.
    @State private var arrived = false

    private typealias L = Journey.Layout

    var body: some View {
        let all = PuzzleLibrary.shared.puzzles(province.size)
        let realmStates = Journey.stopStates(solved: store.solvedFlags(size: province.size))
        let range = min(all.count, province.numbers.lowerBound - 1) ..< min(all.count, province.numbers.upperBound)
        let puzzles = Array(all[range])
        let states = Array(realmStates[range])
        // Until the leg is walked, the card and count show the stop the traveller left.
        let shown = leg != nil && !arrived ? Journey.stopStates(solved: walkBack(store.solvedFlags(size: province.size), range: range)) : realmStates
        let next = nextPuzzle(all, realmStates: shown, range: range)
        let solved = states.filter { $0 == .solved }.count - (leg?.from != nil && !arrived ? 1 : 0)
        ScrollViewReader { proxy in
            ScrollView {
                ZStack {
                    if let terrain {
                        AtlasSheet(pencil: terrain.pencil, ink: terrain.ink, height: L.provinceHeight,
                                   boundary: ProvinceSheet.boundary(province, states: leg.map { inked ? states : $0.before(states) } ?? states))
                            .animation(inked ? .easeInOut(duration: Travel.ink.upperBound - Travel.ink.lowerBound).delay(Travel.ink.lowerBound) : nil, value: inked)
                    } else {
                        AtlasPaper()
                    }
                    AtlasCanvas(drawing: ProvinceSheet.live(province, states: states, travelling: leg), height: L.provinceHeight)
                    if let leg {
                        TravelOverlay(pieces: ProvinceSheet.pieces(province, count: states.count, leg: leg),
                                      trigger: travelTrigger, height: L.provinceHeight)
                    }
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
                            .id(next.id)
                            .transition(.opacity)
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .frame(maxWidth: 640)
                }
            }
            .onAppear {
                if store.solvedCount(size: province.size) > store.journeySeenCount(size: province.size) {
                    store.markJourneySeen(size: province.size)
                    if !reduceMotion { leg = ProvinceGeometry.leg(states) }
                }
                let focus = leg.map { $0.to ?? states.count - 1 } ?? states.firstIndex(of: .current) ?? states.firstIndex(of: .skipped) ?? 0
                proxy.scrollTo(focus, anchor: .center)
                if terrain != nil { travel() }
            }
        }
        .task {
            terrain = await ProvinceSheet.terrain(province)
            travel()
        }
        .navigationTitle(province.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(province.name).font(.serif(18)).foregroundStyle(Theme.ink)
                    Text("No. \(province.numbers.lowerBound) to \(province.numbers.lowerBound + puzzles.count - 1) · \(solved) solved")
                        .font(.sans(11, .bold)).foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// Walks the leg: bumps the overlay's trigger a frame after it mounted at the start, sends
    /// the ink edge up, moves the card on at `Travel.card`, and hands back to the plain sheet.
    private func travel() {
        guard let walking = leg, terrain != nil, !started else { return }
        started = true
        Task { @MainActor in
            // Let the overlay and the sheet draw the start frame before anything moves.
            try? await Task.sleep(for: .milliseconds(50))
            travelTrigger += 1
            inked = true
            Haptics.shared.travel(walks: walking.from != nil, finished: walking.to == nil)
            try? await Task.sleep(for: .seconds(Travel.card))
            withAnimation(.easeOut(duration: 0.3)) { arrived = true }
            try? await Task.sleep(for: .seconds(Travel.total - Travel.card))
            leg = nil
        }
    }

    /// The solved flags as they were before the leg's puzzle was solved, for the card and count.
    private func walkBack(_ flags: [Bool], range: Range<Int>) -> [Bool] {
        guard let from = leg?.from, range.lowerBound + from < flags.count else { return flags }
        var f = flags
        f[range.lowerBound + from] = false
        return f
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
