import SwiftUI

enum Route: Hashable {
    case realm(Int)
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
    @State private var restored = false

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .realm(let size):
                        RealmView(size: size)
                    case .puzzle(let id):
                        if let puzzle = PuzzleLibrary.shared.byId[id] {
                            GameView(puzzle: puzzle, store: store)
                                .id(id)
                        }
                    }
                }
        }
        .tint(Theme.ink)
        .onAppear {
            guard !restored else { return }
            restored = true
            #if DEBUG
            // Launch with `-openPuzzle 8-001` to go straight to a puzzle.
            if let id = UserDefaults.standard.string(forKey: "openPuzzle"), let puzzle = PuzzleLibrary.shared.byId[id] {
                router.path = [.realm(puzzle.size), .puzzle(puzzle.id)]
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
