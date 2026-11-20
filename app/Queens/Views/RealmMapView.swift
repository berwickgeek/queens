import SwiftUI

/// A realm as one long map: twelve provinces climbing two shores, inked as far as the traveller
/// has gone and pencilled beyond. A realm of more than 240 puzzles has more charts of twelve; the
/// map opens on the traveller's and the toolbar turns to the others. Tapping a province opens
/// it; the slim card goes to the next puzzle.
struct RealmMapView: View {
    let size: Int
    @Environment(ProgressStore.self) private var store
    @State private var terrain: (chart: Int, sheets: RealmSheet.Terrain)?
    /// The chart on show; nil until turned, meaning the traveller's.
    @State private var turned: Int?

    private typealias L = Journey.Layout

    var body: some View {
        let puzzles = PuzzleLibrary.shared.puzzles(size)
        let states = Journey.stopStates(solved: store.solvedFlags(size: size))
        let provinces = Journey.provinceStates(states)
        let current = states.firstIndex(of: .current)
        let charts = Journey.charts(puzzleCount: puzzles.count)
        let chart = turned ?? min(charts - 1, (current ?? states.count - 1) / Journey.stopsPerChart)
        ScrollView {
            ZStack {
                if let terrain = terrain.flatMap({ $0.chart == chart ? $0.sheets : nil }) {
                    AtlasSheet(pencil: terrain.pencil, ink: terrain.ink, height: L.realmHeight,
                               boundary: RealmSheet.boundary(size: size, chart: chart, states: states))
                } else {
                    AtlasPaper()
                }
                AtlasCanvas(drawing: RealmSheet.live(size: size, chart: chart, states: states), height: L.realmHeight)
                bands(provinces, chart: chart, states: states)
            }
            .aspectRatio(L.width / L.realmHeight, contentMode: .fit)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        // Opens on the current province. scrollTo cannot find the bands inside their GeometryReader.
        .defaultScrollAnchor(UnitPoint(x: 0.5, y: focus(current, chart: chart)))
        // A new identity per chart, so turning the chart scrolls to its own anchor.
        .id(chart)
        .background(Theme.Atlas.paper)
        .safeAreaInset(edge: .bottom) {
            if let current {
                let province = Journey.Province(size: size, index: current / Journey.stopsPerProvince)
                NavigationLink(value: Route.puzzle(puzzles[current].id)) {
                    let solved = states[province.numbers.lowerBound - 1 ..< min(states.count, province.numbers.upperBound)]
                        .filter { $0 == .solved }.count
                    SlimMapCard(caption: "\(province.name) · \(solved) of \(Journey.stopsPerProvince)", puzzle: puzzles[current])
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .frame(maxWidth: 640)
            }
        }
        .task(id: chart) { terrain = (chart, await RealmSheet.terrain(size: size, chart: chart)) }
        .navigationTitle("Realm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if charts > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Chart", selection: Binding(get: { chart }, set: { turned = $0 })) {
                            ForEach(0..<charts, id: \.self) { c in
                                let first = Journey.Province(size: size, index: c * Journey.provincesPerChart)
                                Text("Chart \(c + 1): \(first.name) onward").tag(c)
                            }
                        }
                    } label: {
                        Label("Chart \(chart + 1)", systemImage: "map")
                            .labelStyle(.titleAndIcon)
                            .font(.sans(13, .bold))
                            .foregroundStyle(Theme.ink)
                    }
                    .accessibilityLabel("Chart \(chart + 1) of \(charts)")
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(Naming.realm(size).name).font(.serif(18)).foregroundStyle(Theme.ink)
                    Text("\(states.filter { $0 == .solved }.count) of \(puzzles.count) solved")
                        .font(.sans(11, .bold)).foregroundStyle(Theme.muted)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The current province's band centre as a fraction of the sheet height, for the opening
    /// scroll. The bottom of a chart the traveller is not on.
    private func focus(_ current: Int?, chart: Int) -> CGFloat {
        guard let current, current / Journey.stopsPerChart == chart else { return 1 }
        return (L.bandBottom(current / Journey.stopsPerProvince) - L.band / 2) / L.realmHeight
    }

    /// A clear tap target over each of the chart's province bands.
    private func bands(_ provinces: [Journey.ProvinceState], chart: Int, states: [Journey.StopState]) -> some View {
        GeometryReader { geo in
            let k = geo.size.width / L.width
            let first = chart * Journey.provincesPerChart
            ForEach(first..<min(provinces.count, first + Journey.provincesPerChart), id: \.self) { i in
                NavigationLink(value: Route.province(size, i)) {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: geo.size.width, height: L.band * k)
                .position(x: geo.size.width / 2, y: (L.bandBottom(i) - L.band / 2) * k)
                .accessibilityLabel(label(i, state: provinces[i], states: states))
            }
        }
    }

    private func label(_ i: Int, state: Journey.ProvinceState, states: [Journey.StopState]) -> String {
        let province = Journey.Province(size: size, index: i)
        let solved = province.numbers.filter { $0 <= states.count && states[$0 - 1] == .solved }.count
        let status = switch state {
        case .finished: "crowned"
        case .current: "\(solved) of \(Journey.stopsPerProvince), you are here"
        case .visited: "\(solved) of \(Journey.stopsPerProvince)"
        case .next: "next"
        case .uncharted: "uncharted"
        }
        return "\(province.name), \(status)"
    }
}

/// The map's continue card: a slim pill, so it hides less of the province under it than the
/// Home screen's ContinueCard would.
struct SlimMapCard: View {
    let caption: String
    let puzzle: Puzzle

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.sans(13, .bold))
                    .foregroundStyle(Theme.muted)
                Text(puzzle.name)
                    .font(.serif(17))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("Continue")
                .font(.labelMd)
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 18)
                .frame(height: 40)
                .background(Capsule().fill(Theme.ink))
        }
        .padding(.leading, 16)
        .padding([.vertical, .trailing], 8)
        .background(Capsule().fill(Theme.paper))
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
        .shadow(color: Theme.ink.opacity(0.15), radius: 12, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Continue \(puzzle.name)")
    }
}
