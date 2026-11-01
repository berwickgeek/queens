import SwiftUI

enum Route: Hashable {
    case realm(Int)
    /// A realm's size and a province index, 0 to 11.
    case province(Int, Int)
    case puzzle(String)
}

@MainActor @Observable
final class Router {
    var path: [Route] = []

    func replaceLast(with route: Route) {
        if path.isEmpty { path = [route] } else { path[path.count - 1] = route }
    }
}

@main
struct QueensApp: App {
    @State private var store = ProgressStore()
    @State private var router = Router()

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
        }
    }
}

struct RootView: View {
    @Environment(ProgressStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @State private var restored = false

    /// DEBUG builds keep the old puzzle grid at `-realmGrid YES` until the province map replaces it.
    private var realmGrid: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "realmGrid")
        #else
        false
        #endif
    }

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .realm(let size):
                        if realmGrid {
                            RealmView(size: size)
                        } else {
                            RealmMapView(size: size)
                        }
                    case .province(let size, let index):
                        // The province map arrives in PR 4; until then, its twenty puzzles.
                        RealmView(size: size, province: index)
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
                router.path = [.realm(puzzle.size), .puzzle(puzzle.id)]
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
                router.path = [.realm(puzzle.size), .puzzle(puzzle.id)]
            }
        }
    }
}
