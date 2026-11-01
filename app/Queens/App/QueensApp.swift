import SwiftUI

enum Route: Hashable {
    case realm(Int)
    /// A realm's size and a province index, 0 to 11.
    case province(Int, Int)
    case puzzle(String)

    /// The stack that reopens a puzzle with its realm and province maps behind it.
    static func path(to puzzle: Puzzle) -> [Route] {
        let province = Journey.province(of: puzzle)
        return [.realm(puzzle.size), .province(puzzle.size, province.index), .puzzle(puzzle.id)]
    }
}

@MainActor @Observable
final class Router {
    var path: [Route] = []

    func replaceLast(with route: Route) {
        if path.isEmpty { path = [route] } else { path[path.count - 1] = route }
    }

    /// Back to the puzzle's province map, with the realm map behind it, however the puzzle was opened.
    func toMap(of puzzle: Puzzle) {
        path = Array(Route.path(to: puzzle).dropLast())
    }
}

@main
struct QueensApp: App {
    @State private var store = ProgressStore()
    @State private var router = Router()
    @State private var unlock = Unlock()

    init() {
        let bar = UINavigationBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(Theme.paper)
        bar.shadowColor = .clear
        let ink = UIColor(Theme.ink)
        if let serif = UIFont(name: "YoungSerif-Regular", size: 18) {
            bar.titleTextAttributes = [.font: serif, .foregroundColor: ink]
        }
        if let sans = UIFont(name: "NunitoSans-NormalBold", size: 16) {
            bar.buttonAppearance.normal.titleTextAttributes = [.font: sans, .foregroundColor: ink]
            bar.backButtonAppearance.normal.titleTextAttributes = [.font: sans, .foregroundColor: ink]
        }
        UINavigationBar.appearance().standardAppearance = bar
        UINavigationBar.appearance().scrollEdgeAppearance = bar
        UINavigationBar.appearance().tintColor = ink
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
                .environment(unlock)
        }
    }
}

struct RootView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @State private var restored = false

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .realm(let size):
                        RealmMapView(size: size)
                    case .province(let size, let index):
                        ProvinceMapView(province: Journey.Province(size: size, index: index))
                    case .puzzle(let id):
                        if let puzzle = PuzzleLibrary.shared.byId[id] {
                            GameView(puzzle: puzzle, store: store)
                                .id(id)
                        }
                    }
                }
        }
        .tint(Theme.ink)
        .atlasGallery()
        .onChange(of: scenePhase) { _, phase in
            // The game persists on .inactive, so by .background its last move is queued.
            if phase == .background { store.flushCloud() }
            if phase == .active { store.refreshFromCloud() }
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            #if DEBUG
            // Launch with `-openPuzzle 8-001` to go straight to a puzzle.
            if let id = UserDefaults.standard.string(forKey: "openPuzzle"), let puzzle = PuzzleLibrary.shared.byId[id] {
                router.path = Route.path(to: puzzle)
                return
            }
            // Launch with `-openProvince 7-1` to go straight to a province's map.
            let parts = (UserDefaults.standard.string(forKey: "openProvince") ?? "").split(separator: "-").compactMap { Int($0) }
            if parts.count == 2 {
                router.path = [.realm(parts[0]), .province(parts[0], parts[1])]
                return
            }
            // Launch with `-openRealm 7` to go straight to a realm's map.
            let realm = UserDefaults.standard.integer(forKey: "openRealm")
            if realm > 0 {
                router.path = [.realm(realm)]
                return
            }
            #endif
            // Reopen the puzzle that was left unfinished.
            if let puzzle = store.resumable {
                router.path = Route.path(to: puzzle)
            }
        }
    }
}
