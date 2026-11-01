import SwiftUI

/// A realm as one long map: twelve provinces climbing two shores, inked as far as the traveller
/// has gone and pencilled beyond. Tapping a province opens it; the slim card goes to the next puzzle.
struct RealmMapView: View {
    let size: Int
    @Environment(ProgressStore.self) private var store
    @State private var terrain: RealmSheet.Terrain?

    private typealias L = Journey.Layout

    var body: some View {
        let puzzles = PuzzleLibrary.shared.puzzles(size)
        let states = Journey.stopStates(solved: store.solvedFlags(size: size))
        let provinces = Journey.provinceStates(states)
        let current = states.firstIndex(of: .current)
        ScrollView {
            ZStack {
                if let terrain {
                    AtlasSheet(pencil: terrain.pencil, ink: terrain.ink, height: L.realmHeight,
                               boundary: RealmSheet.boundary(size: size, states: states))
                } else {
                    AtlasPaper()
                }
                AtlasCanvas(drawing: RealmSheet.live(size: size, states: states), height: L.realmHeight)
                bands(provinces, states: states)
            }
            .aspectRatio(L.width / L.realmHeight, contentMode: .fit)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        // Opens on the current province. scrollTo cannot find the bands inside their GeometryReader.
        .defaultScrollAnchor(UnitPoint(x: 0.5, y: focus(current)))
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
        .task { terrain = await RealmSheet.terrain(size: size) }
        .navigationTitle("Realm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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

    /// The current province's band centre as a fraction of the sheet height, for the opening scroll.
    private func focus(_ current: Int?) -> CGFloat {
        guard let current else { return 1 }
        return (L.bandBottom(current / Journey.stopsPerProvince) - L.band / 2) / L.realmHeight
    }

    /// A clear tap target over each province's band.
    private func bands(_ provinces: [Journey.ProvinceState], states: [Journey.StopState]) -> some View {
        GeometryReader { geo in
            let k = geo.size.width / L.width
            ForEach(provinces.indices, id: \.self) { i in
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
