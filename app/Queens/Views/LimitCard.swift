import SwiftUI

/// Shown in place of the board when today's free solves are used up. No countdown: the
/// message is that tomorrow brings more, not that the player is being timed.
struct LimitCard: View {
    let puzzle: Puzzle
    @Environment(Unlock.self) private var unlock
    @Environment(Router.self) private var router

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            VStack(spacing: 14) {
                CrownTally(placed: Unlock.perDay, total: Unlock.perDay, gilded: true, size: 22)
                Text("That's your five for today")
                    .font(.headlineSm)
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("New crowns arrive at midnight. Or unlock every kingdom once and play as much as you like.")
                    .font(.bodyMd)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await unlock.purchase() }
                } label: {
                    if unlock.purchasing {
                        ProgressView().tint(Theme.paper)
                    } else if let product = unlock.product {
                        Text("Unlock all for \(product.displayPrice)")
                    } else {
                        Text("Unlock all")
                    }
                }
                .buttonStyle(PillButtonStyle(prominent: true))
                .disabled(unlock.product == nil || unlock.purchasing)
                .padding(.top, 4)
                Text("One payment, no ads, shared with your family.")
                    .font(.bodySm)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.border, lineWidth: 1))

            HStack(spacing: 12) {
                Button { router.toMap(of: puzzle) } label: {
                    Label("To the map", systemImage: "map")
                }
                .labelStyle(.titleAndIcon)
                Button("Restore purchase") { Task { await unlock.restore() } }
            }
            .buttonStyle(PillButtonStyle())
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity)
    }
}
