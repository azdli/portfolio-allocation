// Enter a new position's totals in one of your accounts.

import SwiftUI

/// First-time entry of a position: the totals shown on a brokerage's positions page.
struct AddHoldingSheet: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var symbol = ""
    @State private var name = ""
    @State private var assetClass: AssetClass = .usStocks
    @State private var priceText = ""
    @State private var targetText = ""
    @State private var accountID: Account.ID?
    /// The account the last holding was added to
    @AppStorage("lastAddHoldingAccount") private var lastAccountID = ""
    @State private var sharesText = ""
    @State private var costText = ""

    @State private var portfolioBeforeSave: Portfolio?

    private var portfolio: Portfolio { portfolioBeforeSave ?? store.portfolio }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader("Add Holding")

            if portfolio.accounts.isEmpty {
                noAccounts
            } else {
                form
            }
        }
        // macOS adds the 65 pt button bar below this for a 565 pt sheet.
        .frame(width: 480, height: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            if !portfolio.accounts.isEmpty {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Holding", action: add)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!canAdd)
                }
            }
        }
        .onAppear {
            if accountID == nil {
                // The last-used account if it still exists; otherwise the first account
                let remembered = portfolio.accounts.first { $0.id.uuidString == lastAccountID }
                accountID = (remembered ?? portfolio.accounts.first)?.id
            }
        }
    }

    // MARK: - Content

    private var noAccounts: some View {
        ContentUnavailableView {
            Label("No Accounts Yet", systemImage: "building.columns")
        } description: {
            Text("Add the brokerage accounts you hold assets in, then add holdings to them.")
        } actions: {
            Button("Open Accounts") { router.sheet = .accounts }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxHeight: .infinity)
    }

    private var form: some View {
        Form {
            Section("Security") {
                TextField("Symbol", text: $symbol, prompt: Text("e.g. VTI or SPAXX"))
                if let asset = existingAsset {
                    LabeledContent("Name", value: asset.name)
                    LabeledContent("Asset class", value: asset.assetClass.label)
                    LabeledContent("Price", value: Fmt.currency(asset.price))
                    LabeledContent("Target", value: asset.targetPercent.map(Fmt.target) ?? "—")
                } else {
                    TextField("Name", text: $name, prompt: Text("e.g. Vanguard Total Stock Market ETF"))
                    Picker("Asset class", selection: $assetClass) {
                        ForEach(AssetClass.allCases) { assetClass in
                            Text(assetClass.label).tag(assetClass)
                        }
                    }
                    TextField("Current price", text: $priceText, prompt: Text("$0.00"))
                    TextField("Target", text: $targetText, prompt: Text("Optional, e.g. 25%"))
                    if let note = cappedTarget.note {
                        Text(note)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Position") {
                Picker("Account", selection: $accountID) {
                    ForEach(portfolio.accounts) { account in
                        Text(account.displayName).tag(Optional(account.id))
                    }
                }
                TextField("Total shares", text: $sharesText, prompt: Text("0"))
                TextField("Total cost basis", text: $costText, prompt: Text("$0.00"))
            }

            if let conflictMessage {
                Section {
                    Label {
                        Text(conflictMessage)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .formStyle(.grouped)
        // Price suggestion as money market funds usually trade at $1
        .onChange(of: assetClass) { _, newClass in
            if newClass == .cash, priceText.trimmed.isEmpty { priceText = "$1.00" }
        }
    }

    // MARK: - Derived state

    private var existingAsset: Asset? {
        portfolio.asset(withSymbol: symbol)
    }

    private var selectedAccount: Account? {
        portfolio.accounts.first { $0.id == accountID }
    }

    private var conflictMessage: String? {
        guard let asset = existingAsset,
              let account = selectedAccount,
              portfolio.position(assetID: asset.id, accountID: account.id) != nil
        else { return nil }
        return "\(asset.symbol) is already in \(account.displayName). Update its shares and cost basis in the holdings table instead."
    }

    private var shares: Double? {
        Fmt.parse(sharesText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var cost: Double? {
        Fmt.parse(costText).flatMap { $0 >= 0 ? $0 : nil }
    }

    private var price: Double? {
        Fmt.parse(priceText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var targetIsValid: Bool {
        targetText.trimmed.isEmpty || (Fmt.parse(targetText).map { $0 >= 0 } ?? false)
    }

    /// The target that will be saved, capped at 100%
    private var cappedTarget: (value: Double?, note: String?) {
        guard !targetText.trimmed.isEmpty, let entered = Fmt.parse(targetText), entered >= 0 else { return (nil, nil) }
        let maximum = portfolio.maximumTarget(for: nil)
        guard entered > maximum else { return (entered, nil) }
        if maximum <= 0 {
            return (nil, "Your other targets already total 100%, so this holding will be added without a target.")
        }
        return (maximum, "Targets can't total more than 100%, so this will be set to \(Fmt.target(maximum)).")
    }

    private var canAdd: Bool {
        guard selectedAccount != nil,
              conflictMessage == nil,
              !symbol.trimmed.isEmpty,
              shares != nil,
              cost != nil
        else { return false }
        return existingAsset != nil || (price != nil && targetIsValid)
    }

    // MARK: - Saving

    private func add() {
        guard portfolioBeforeSave == nil, canAdd, let accountID, let shares, let cost else { return }

        let choice: PortfolioStore.AssetChoice
        if let existing = existingAsset {
            choice = .existing(existing.id)
        } else {
            let symbol = symbol.trimmed.uppercased()
            choice = .new(PortfolioStore.NewAsset(
                symbol: symbol,
                name: name.trimmed.isEmpty ? symbol : name.trimmed,
                assetClass: assetClass,
                price: price ?? 0,
                targetPercent: cappedTarget.value
            ))
        }

        portfolioBeforeSave = store.portfolio
        store.addPosition(choice, accountID: accountID, shares: shares, costBasis: cost)
        lastAccountID = accountID.uuidString
        dismiss()
    }
}
