// Summary, allocation and holdings cards, plus the empty and locked states. Main app window

import SwiftUI

struct ContentView: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(AppRouter.self) private var router
    @AppStorage(TargetPreference.ignoresUntargetedKey) private var ignoresUntargeted = false
    @State private var cashText = ""
    /// Which holdings show their accounts; remembered between launches.
    @State private var expanded: Set<Asset.ID> = ContentView.savedExpansion

    var body: some View {
        @Bindable var router = router
        @Bindable var bindableStore = store
        let snapshot = store.snapshot(cashToInvest: Fmt.parse(cashText) ?? 0, ignoringUntargeted: ignoresUntargeted)

        Group {
            if let reason = store.lockedReason {
                LockedPortfolioView(reason: reason)
            } else if store.portfolio.positions.isEmpty {
                EmptyPortfolioView()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            SummaryCard(snapshot: snapshot)
                            AllocationCard(snapshot: snapshot)
                        }
                        // Both cards take the taller card's height.
                        .fixedSize(horizontal: false, vertical: true)

                        HoldingsSection(snapshot: snapshot, cashText: $cashText, expanded: $expanded)
                    }
                    .padding(20)
                }
                .pageBackground()
            }
        }
        .frame(minWidth: 1200, minHeight: 700)
        .onChange(of: expanded) { _, ids in
            UserDefaults.standard.set(ids.map(\.uuidString).sorted(), forKey: Self.expansionKey)
        }
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    router.sheet = .accounts
                } label: {
                    Label("Accounts", systemImage: "building.columns")
                }
                .help("Manage accounts (⇧⌘A)")
                .disabled(store.isLocked)

                Button {
                    router.sheet = .addHolding
                } label: {
                    Label("Add Holding", systemImage: "plus")
                }
                .help("Add a holding (⌘N)")
                .disabled(store.isLocked)
            }
        }
        .sheet(item: $router.sheet) { sheet in
            Group {
                switch sheet {
                case .addHolding: AddHoldingSheet()
                case .accounts: AccountsSheet()
                }
            }
            .environment(store)
            .environment(router)
        }
        .alert(store.alert?.title ?? "", item: $bindableStore.alert) { _ in
            Button("OK") {}
        } message: { alert in
            Text(alert.message)
        }
    }

    private static let expansionKey = "expandedHoldings"

    private static var savedExpansion: Set<Asset.ID> {
        Set((UserDefaults.standard.stringArray(forKey: expansionKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    private var subtitle: String {
        let holdings = store.portfolio.assets.count
        let accounts = store.portfolio.accounts.count
        return "\(holdings) \(holdings == 1 ? "holding" : "holdings") · \(accounts) \(accounts == 1 ? "account" : "accounts")"
    }
}

struct EmptyPortfolioView: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        let hasAccounts = !store.portfolio.accounts.isEmpty
        ContentUnavailableView {
            Label("No Holdings Yet", systemImage: "chart.pie")
        } description: {
            if hasAccounts {
                Text("Add each position from your brokerage's positions page: its total shares and total cost basis.")
            } else {
                Text("Start by adding the brokerage accounts you hold assets in. Then add each position from the brokerage's positions page.")
            }
        } actions: {
            if hasAccounts {
                Button("Add Holding") { router.sheet = .addHolding }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Add Accounts") { router.sheet = .accounts }
                    .buttonStyle(.borderedProminent)
            }
            Button("Load Sample Portfolio") { store.loadSamplePortfolio() }
        }
    }
}

/// Shown when the saved portfolio exists but can't be opened right now
struct LockedPortfolioView: View {
    @Environment(PortfolioStore.self) private var store
    let reason: String

    var body: some View {
        ContentUnavailableView {
            Label("Portfolio Locked", systemImage: "lock")
        } description: {
            Text(reason)
        } actions: {
            Button("Try Again") { store.loadFromDisk() }
                .buttonStyle(.borderedProminent)
        }
    }
}
