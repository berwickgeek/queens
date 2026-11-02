import Foundation
import Observation
import StoreKit

/// The free tier and the one-time unlock. Free players get `perDay` solves a day once they have
/// `firstSolves` behind them, so the first sitting is never cut short. Hints and Pin are always free,
/// and a puzzle already under way can always be finished; only fresh starts wait for midnight.
@MainActor @Observable
final class Unlock {
    static let productID = "cc.jaym.queens.unlock"
    nonisolated static let perDay = 5
    nonisolated static let firstSolves = 10

    private(set) var unlocked: Bool
    private(set) var product: Product?
    private(set) var purchasing = false

    private static let cacheKey = "unlocked"
    private var updates: Task<Void, Never>?

    init() {
        // Cached so an offline launch does not flash the limit before StoreKit answers.
        unlocked = UserDefaults.standard.bool(forKey: Self.cacheKey)
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
        Task { await refresh(); await load() }
    }

    nonisolated static func limitReached(lifetime: Int, today: Int) -> Bool {
        lifetime >= firstSolves && today >= perDay
    }

    /// True when a fresh start has to wait: not unlocked and today's free solves are used up.
    func blocks(_ store: ProgressStore) -> Bool {
        #if DEBUG
        // Device installs from devicectl get no StoreKit config, so there is nothing to buy.
        // Debug builds only enforce the limit when the dailyLimit launch flag asks for it.
        return UserDefaults.standard.bool(forKey: "dailyLimit") && !unlocked
        #else
        return !unlocked && Self.limitReached(lifetime: store.lifetimeSolved, today: store.solvedToday)
        #endif
    }

    func purchase() async {
        guard let product, !purchasing else { return }
        purchasing = true
        defer { purchasing = false }
        guard case .success(let result) = try? await product.purchase(),
              case .verified(let t) = result else { return }
        await t.finish()
        await refresh()
    }

    /// Restore is only needed on a new Apple ID device; StoreKit 2 syncs entitlements on its own.
    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    private func load() async {
        product = try? await Product.products(for: [Self.productID]).first
    }

    private func refresh() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil {
                owned = true
            }
        }
        unlocked = owned
        UserDefaults.standard.set(owned, forKey: Self.cacheKey)
    }
}
