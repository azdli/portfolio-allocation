// The holdings table

import AppKit
import SwiftUI

/// Column widths shared by  rows of the holdings table.
enum Column {
    static let spacing: CGFloat = 10
    static let holdingMinWidth: CGFloat = 190
    static let shares: CGFloat = 84
    static let price: CGFloat = 92
    static let value: CGFloat = 112
    static let cost: CGFloat = 108
    static let gain: CGFloat = 108
    static let returnPercent: CGFloat = 70
    static let allocation: CGFloat = 80
    static let target: CGFloat = 64
    static let buy: CGFloat = 128
    static let rowInset: CGFloat = 16
    /// Indent for account rows
    static let childIndent: CGFloat = 18
}

struct HoldingsSection: View {
    @Environment(PortfolioStore.self) private var store
    let snapshot: PortfolioSnapshot
    @Binding var cashText: String
    @Binding var expanded: Set<Asset.ID>

    @State private var pendingRemoval: Removal?
    @FocusState private var isCashFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            columnHeader
            Divider()

            ForEach(snapshot.holdings) { holding in
                let isExpanded = expanded.contains(holding.id)
                HoldingRow(
                    line: holding,
                    cashToInvest: snapshot.cashToInvest,
                    ignoresUntargeted: snapshot.ignoresUntargeted,
                    isExpanded: isExpanded,
                    toggle: { toggle(holding.id) },
                    requestDelete: { pendingRemoval = .asset(holding.asset, accountCount: holding.positions.count) }
                )
                Divider()

                if isExpanded {
                    ForEach(holding.positions) { line in
                        PositionRow(
                            line: line,
                            asset: holding.asset,
                            requestRemove: {
                                pendingRemoval = .position(line, asset: holding.asset, isLastPosition: holding.positions.count == 1)
                            }
                        )
                        Divider()
                    }
                }
            }

            totalRow
        }
        .card(padding: 0)
        .alert(pendingRemoval?.title ?? "", item: $pendingRemoval) { removal in
            Button("Remove", role: .destructive) { perform(removal) }
            Button("Cancel", role: .cancel) {}
        } message: { removal in
            Text(removal.message)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text("Holdings")
                .font(.headline)
            Spacer()
            Text("New cash to invest")
                .foregroundStyle(.secondary)
            TextField("New cash to invest", text: $cashText, prompt: Text("$0"))
                .labelsHidden()
                .textFieldStyle(.bordered)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 110)
                .focused($isCashFieldFocused)
                .onSubmit(tidyCashText)
                .onChange(of: isCashFieldFocused) { _, focused in
                    if !focused { tidyCashText() }
                }
        }
        .padding(.horizontal, Column.rowInset)
        .padding(.vertical, 12)
    }

    private var columnHeader: some View {
        HStack(spacing: Column.spacing) {
            Text("Holding")
                .frame(minWidth: Column.holdingMinWidth, maxWidth: .infinity, alignment: .leading)
            Text("Shares").cell(Column.shares)
            Text("Price").cell(Column.price)
            Text("Market value").cell(Column.value)
            Text("Cost basis").cell(Column.cost)
            Text("Unrealized G/L").cell(Column.gain)
            Text("Return").cell(Column.returnPercent)
            Text("Allocation").cell(Column.allocation)
            Text("Target").cell(Column.target)
            Text(snapshot.cashToInvest > 0 ? "Buy with \(Fmt.currency(snapshot.cashToInvest, decimals: 0))" : "To target")
                .cell(Column.buy)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, Column.rowInset)
        .padding(.vertical, 8)
        .background(Palette.band)
    }

    private var totalRow: some View {
        let isOverTarget = snapshot.targetPercentSum > 100.005
        return HStack(spacing: Column.spacing) {
            Text("Total")
                .padding(.leading, Column.childIndent)
                .frame(minWidth: Column.holdingMinWidth, maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(height: 1).cell(Column.shares)
            Color.clear.frame(height: 1).cell(Column.price)
            Text(Fmt.currency(snapshot.totalValue)).cell(Column.value)
            Text(Fmt.currency(snapshot.totalCost)).cell(Column.cost)
            Text(Fmt.signedCurrency(snapshot.gain))
                .foregroundStyle(Palette.tone(snapshot.gain))
                .cell(Column.gain)
            Text(snapshot.returnFraction.map(Fmt.signedPercent) ?? "—")
                .foregroundStyle(Palette.tone(snapshot.gain))
                .cell(Column.returnPercent)
            Text(Fmt.percent(1, decimals: 0)).cell(Column.allocation)
            Text(Fmt.target(snapshot.targetPercentSum))
                .foregroundStyle(isOverTarget ? Palette.warning : Color.primary)
                .help(isOverTarget ? "Targets add up to more than 100%." : "")
                .cell(Column.target)
            Text(snapshot.cashToInvest > 0 ? "Buy \(Fmt.currency(snapshot.suggestedBuyTotal, decimals: 0))" : "")
                .foregroundStyle(Palette.accentText)
                .cell(Column.buy)
        }
        .fontWeight(.semibold)
        .monospacedDigit()
        .lineLimit(1)
        .padding(.horizontal, Column.rowInset)
        .padding(.vertical, 10)
        .background(Palette.band)
    }

    // MARK: - Actions

    /// Option-click opens or closes every holding, as in Finder.
    private func toggle(_ id: Asset.ID) {
        let opening = !expanded.contains(id)
        let all = NSEvent.modifierFlags.contains(.option)
        withAnimation(.snappy(duration: 0.2)) {
            if all {
                expanded = opening ? Set(snapshot.holdings.map(\.id)) : []
            } else if opening {
                expanded.insert(id)
            } else {
                expanded.remove(id)
            }
        }
    }

    private func tidyCashText() {
        guard let amount = Fmt.parse(cashText), amount > 0 else {
            cashText = ""
            return
        }
        cashText = Fmt.currency(amount, decimals: amount.rounded() == amount ? 0 : 2)
    }

    private func perform(_ removal: Removal) {
        switch removal {
        case .position(let line, _, _):
            store.removePosition(line.id)
        case .asset(let asset, _):
            expanded.remove(asset.id)
            store.removeAsset(asset.id)
        }
    }
}

/// A deletion pending confirmation.
enum Removal: Identifiable {
    case position(PortfolioSnapshot.PositionLine, asset: Asset, isLastPosition: Bool)
    case asset(Asset, accountCount: Int)

    var id: UUID {
        switch self {
        case .position(let line, _, _): line.id
        case .asset(let asset, _): asset.id
        }
    }

    var title: String {
        switch self {
        case .position(let line, let asset, _):
            "Remove \(asset.symbol) from \(line.account.displayName)?"
        case .asset(let asset, _):
            "Delete \(asset.symbol)?"
        }
    }

    var message: String {
        switch self {
        case .position(let line, let asset, let isLast):
            let detail = "Its \(Fmt.shares(line.position.shares)) shares and \(Fmt.currency(line.cost)) cost basis will be deleted."
            let leaving = isLast ? " \(asset.symbol) isn't held in any other account, so it will also be removed from your portfolio." : ""
            return detail + leaving
        case .asset(let asset, let count):
            return "This removes \(asset.symbol) from \(count == 1 ? "the account" : "all \(count) accounts") that hold it."
        }
    }
}

// MARK: - Rows

private struct HoldingRow: View {
    @Environment(PortfolioStore.self) private var store
    let line: PortfolioSnapshot.HoldingLine
    let cashToInvest: Double
    let ignoresUntargeted: Bool
    let isExpanded: Bool
    let toggle: () -> Void
    let requestDelete: () -> Void

    var body: some View {
        let asset = line.asset

        HStack(spacing: Column.spacing) {
            Button(action: toggle) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 10)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(asset.symbol)
                            .fontWeight(.semibold)
                        Text(asset.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .frame(minWidth: Column.holdingMinWidth, maxWidth: .infinity, alignment: .leading)

            Text(Fmt.shares(line.shares))
                .cell(Column.shares)

            InlineNumberField(
                label: "Price of \(asset.symbol)",
                value: asset.price,
                format: { Fmt.currency($0) },
                onCommit: { newPrice in
                    if let newPrice, newPrice > 0 { store.setPrice(newPrice, for: asset.id) }
                }
            )
            .cell(Column.price)

            Text(Fmt.currency(line.value))
                .fontWeight(.semibold)
                .cell(Column.value)
            Text(Fmt.currency(line.cost))
                .cell(Column.cost)
            Text(Fmt.signedCurrency(line.gain))
                .foregroundStyle(Palette.tone(line.gain))
                .cell(Column.gain)
            Text(line.returnFraction.map(Fmt.signedPercent) ?? "—")
                .foregroundStyle(Palette.tone(line.gain))
                .cell(Column.returnPercent)

            VStack(alignment: .trailing, spacing: 1) {
                Text(Fmt.percent(line.share))
                    .fontWeight(.semibold)
                if let drift = line.drift {
                    Text(Fmt.points(drift))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .cell(Column.allocation)
            // With untracked holdings left out, drift is measured against a smaller total
            .help(ignoresUntargeted ? line.shareOfTargetBase.map { "\(Fmt.percent($0)) of the holdings that have a target" } ?? "" : "")

            InlineNumberField(
                label: "Target for \(asset.symbol)",
                value: asset.targetPercent,
                placeholder: "—",
                allowsEmpty: true,
                format: Fmt.target,
                adjust: { store.cappedTarget($0, for: asset.id, current: asset.targetPercent) },
                onCommit: { store.setTarget($0, for: asset.id) }
            )
            .cell(Column.target)

            BuyCell(line: line, cashToInvest: cashToInvest)
                .cell(Column.buy)
        }
        .monospacedDigit()
        .lineLimit(1)
        .padding(.horizontal, Column.rowInset)
        .padding(.vertical, 7)
        .background(isExpanded ? Color.accentColor.opacity(0.07) : Color.clear)
        .contextMenu {
            Button(isExpanded ? "Hide Accounts" : "Show Accounts", action: toggle)
            Divider()
            Button("Delete \(asset.symbol)…", role: .destructive, action: requestDelete)
        }
    }
}

private struct BuyCell: View {
    let line: PortfolioSnapshot.HoldingLine
    let cashToInvest: Double

    var body: some View {
        let content = self.content
        VStack(alignment: .trailing, spacing: 1) {
            Text(content.main)
                .fontWeight(.semibold)
                .foregroundStyle(content.isBuy ? Palette.accentText : Color.secondary)
            if let detail = content.detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var content: (main: String, detail: String?, isBuy: Bool) {
        guard line.asset.targetPercent != nil else { return ("—", nil, false) }

        if cashToInvest > 0 {
            guard line.suggestedBuy >= 0.5 else { return ("—", nil, false) }
            let detail: String? = if line.asset.price > 0 {
                "≈ \(Fmt.approximateShares(line.suggestedBuy / line.asset.price)) shares"
            } else {
                nil
            }
            return ("Buy \(Fmt.currency(line.suggestedBuy, decimals: 0))", detail, true)
        }

        if line.gapToTarget >= 0.5 {
            return ("Buy \(Fmt.currency(line.gapToTarget, decimals: 0))", "to reach target", true)
        }
        if line.gapToTarget <= -0.5 {
            return ("Over \(Fmt.currency(-line.gapToTarget, decimals: 0))", "above target", false)
        }
        return ("On target", nil, false)
    }
}

private struct PositionRow: View {
    @Environment(PortfolioStore.self) private var store
    let line: PortfolioSnapshot.PositionLine
    let asset: Asset
    let requestRemove: () -> Void

    var body: some View {
        let place = "\(asset.symbol) in \(line.account.displayName)"

        HStack(spacing: Column.spacing) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(line.account.brokerage)
                        .fontWeight(.semibold)
                    Text("· \(line.account.name)")
                        .foregroundStyle(.secondary)
                }
                Text("\(Fmt.percent(line.holdingShare, decimals: 0)) of \(asset.symbol)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, Column.childIndent)
            .frame(minWidth: Column.holdingMinWidth, maxWidth: .infinity, alignment: .leading)

            InlineNumberField(
                label: "Total shares of \(place)",
                value: line.position.shares,
                format: Fmt.shares,
                onCommit: commitShares
            )
            .cell(Column.shares)

            Text(Fmt.currency(asset.price))
                .foregroundStyle(.secondary)
                .cell(Column.price)

            Text(Fmt.currency(line.value))
                .cell(Column.value)

            InlineNumberField(
                label: "Total cost basis of \(place)",
                value: line.position.costBasis,
                format: { Fmt.currency($0) },
                onCommit: { newCost in
                    if let newCost { store.setCostBasis(newCost, for: line.id) }
                }
            )
            .cell(Column.cost)

            Text(Fmt.signedCurrency(line.gain))
                .foregroundStyle(Palette.tone(line.gain))
                .cell(Column.gain)
            Text(line.returnFraction.map(Fmt.signedPercent) ?? "—")
                .foregroundStyle(Palette.tone(line.gain))
                .cell(Column.returnPercent)
            Text(Fmt.percent(line.portfolioShare))
                .foregroundStyle(.secondary)
                .cell(Column.allocation)
            Color.clear.frame(height: 1).cell(Column.target)
            Color.clear.frame(height: 1).cell(Column.buy)
        }
        .font(.callout)
        .monospacedDigit()
        .lineLimit(1)
        .padding(.horizontal, Column.rowInset)
        .padding(.vertical, 5)
        .background(Palette.nestedBand)
        .contextMenu {
            Button("Remove from \(line.account.displayName)…", role: .destructive, action: requestRemove)
        }
    }

    /// Setting shares to zero asks to remove the position
    private func commitShares(_ newValue: Double?) {
        guard let newValue else { return }
        if newValue == 0 {
            requestRemove()
        } else {
            store.setShares(newValue, for: line.id)
        }
    }
}
