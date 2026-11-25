// Everything the portfolio window shows: values, gains, targets and chart slices.

import SwiftUI

enum AllocationGrouping: String, CaseIterable, Identifiable {
    case holding
    case assetClass

    var id: Self { self }

    var label: String {
        switch self {
        case .holding: "Holding"
        case .assetClass: "Asset class"
        }
    }
}

/// Everything the window shows, derived from the portfolio in one pass.
struct PortfolioSnapshot {
    struct PositionLine: Identifiable {
        let position: Position
        let account: Account
        let value: Double
        /// Share of the whole portfolio.
        let portfolioShare: Double
        /// Share of this holding across all accounts.
        let holdingShare: Double

        var id: Position.ID { position.id }
        var cost: Double { position.costBasis }
        var gain: Double { value - cost }
        var returnFraction: Double? { cost > 0 ? gain / cost : nil }
    }

    struct HoldingLine: Identifiable {
        let asset: Asset
        let positions: [PositionLine]
        let shares: Double
        let value: Double
        let cost: Double
        /// Share of the whole portfolio.
        let share: Double
        /// Share of the total the target is measured against (see `ignoresUntargeted`); `nil` without a target.
        let shareOfTargetBase: Double?
        /// How much of the new cash to put here.
        let suggestedBuy: Double
        /// Dollars needed to reach target today (negative when over target).
        let gapToTarget: Double

        var id: Asset.ID { asset.id }
        var gain: Double { value - cost }
        var returnFraction: Double? { cost > 0 ? gain / cost : nil }
        var targetFraction: Double? { asset.targetPercent.map { $0 / 100 } }
        var drift: Double? {
            guard let targetFraction, let shareOfTargetBase else { return nil }
            return shareOfTargetBase - targetFraction
        }
    }

    struct AccountLine: Identifiable {
        let account: Account
        let value: Double
        let cost: Double
        let share: Double

        var id: Account.ID { account.id }
        var gain: Double { value - cost }
        var returnFraction: Double? { cost > 0 ? gain / cost : nil }
    }

    struct Slice: Identifiable {
        let id: String
        let label: String
        let detail: String
        let color: Color
        let value: Double
        let share: Double
        let targetFraction: Double?
    }

    let holdings: [HoldingLine]
    /// Largest first.
    let accounts: [AccountLine]
    let totalValue: Double
    let totalCost: Double
    let targetPercentSum: Double
    let cashToInvest: Double
    /// Whether targets are shares of only the holdings that have assigned targets, rather than of everything.
    let ignoresUntargeted: Bool

    var gain: Double { totalValue - totalCost }
    var returnFraction: Double? { totalCost > 0 ? gain / totalCost : nil }
    var suggestedBuyTotal: Double { holdings.reduce(0) { $0 + $1.suggestedBuy } }

    init(portfolio: Portfolio, cashToInvest: Double, ignoringUntargeted: Bool = false) {
        let accountsByID = Dictionary(uniqueKeysWithValues: portfolio.accounts.map { ($0.id, $0) })

        struct Raw {
            let asset: Asset
            let held: [(position: Position, account: Account)]
            let shares: Double
            let value: Double
            let cost: Double
        }

        let raws: [Raw] = PortfolioStore.tableOrder(portfolio.assets).map { asset in
            let held = portfolio.positions
                .filter { $0.assetID == asset.id }
                .compactMap { position in accountsByID[position.accountID].map { (position: position, account: $0) } }
            let shares = held.reduce(0) { $0 + $1.position.shares }
            let cost = held.reduce(0) { $0 + $1.position.costBasis }
            return Raw(asset: asset, held: held, shares: shares, value: shares * asset.price, cost: cost)
        }

        let total = raws.reduce(0) { $0 + $1.value }
        let targets = raws.map { ($0.asset.targetPercent ?? 0) / 100 }
        let targetSum = targets.reduce(0, +)

        // Targets are shares of the whole portfolio, or optionally of only the holdings that have assigned targets.
        let targetBase = ignoringUntargeted
            ? raws.filter { $0.asset.targetPercent != nil }.reduce(0) { $0 + $1.value }
            : total

        // Split new cash across holdings below target, in proportion to how far below they are.
        // If the cash covers every gap, the remainder follows the targets.
        let cash = max(0, cashToInvest)
        let newBase = targetBase + cash
        let deficits = zip(raws, targets).map { raw, target in max(0, newBase * target - raw.value) }
        let deficitSum = deficits.reduce(0, +)
        let buys: [Double] = raws.indices.map { index in
            guard cash > 0 else { return 0 }
            if deficitSum <= cash {
                let leftover = cash - deficitSum
                return deficits[index] + (targetSum > 0 ? leftover * targets[index] / targetSum : 0)
            }
            return cash * deficits[index] / deficitSum
        }

        holdings = raws.enumerated().map { index, raw in
            let lines = raw.held.map { entry in
                let value = entry.position.shares * raw.asset.price
                return PositionLine(
                    position: entry.position,
                    account: entry.account,
                    value: value,
                    portfolioShare: total > 0 ? value / total : 0,
                    holdingShare: raw.value > 0 ? value / raw.value : 0
                )
            }
            .sorted { $0.value > $1.value }

            return HoldingLine(
                asset: raw.asset,
                positions: lines,
                shares: raw.shares,
                value: raw.value,
                cost: raw.cost,
                share: total > 0 ? raw.value / total : 0,
                shareOfTargetBase: raw.asset.targetPercent == nil ? nil : (targetBase > 0 ? raw.value / targetBase : 0),
                suggestedBuy: buys[index],
                gapToTarget: raw.asset.targetPercent == nil ? 0 : targetBase * targets[index] - raw.value
            )
        }

        accounts = portfolio.accounts.map { account in
            var value = 0.0
            var cost = 0.0
            for raw in raws {
                for entry in raw.held where entry.account.id == account.id {
                    value += entry.position.shares * raw.asset.price
                    cost += entry.position.costBasis
                }
            }
            return AccountLine(account: account, value: value, cost: cost, share: total > 0 ? value / total : 0)
        }
        .sorted { $0.value > $1.value }

        totalValue = total
        totalCost = raws.reduce(0) { $0 + $1.cost }
        targetPercentSum = targetSum * 100
        self.cashToInvest = cash
        ignoresUntargeted = ignoringUntargeted
    }

    // MARK: - Chart

    /// The most holdings the chart can colour individually
    static let maxColoredHoldings = 8

    func slices(for grouping: AllocationGrouping) -> [Slice] {
        struct Part {
            let id: String
            let label: String
            let detail: String
            let value: Double
            let share: Double
            let targetFraction: Double?
            let isOther: Bool
        }

        func combinedTarget(_ lines: [HoldingLine]) -> Double? {
            let targets = lines.compactMap(\.targetFraction)
            return targets.isEmpty ? nil : targets.reduce(0, +)
        }

        var parts: [Part]
        switch grouping {
        case .holding:
            var kept = holdings
            var folded: [HoldingLine] = []
            if holdings.count > Self.maxColoredHoldings {
                let largest = Set(holdings.sorted { $0.value > $1.value }.prefix(Self.maxColoredHoldings - 1).map(\.id))
                kept = holdings.filter { largest.contains($0.id) }
                folded = holdings.filter { !largest.contains($0.id) }
            }
            parts = kept.map {
                Part(id: $0.id.uuidString, label: $0.asset.symbol, detail: $0.asset.name,
                     value: $0.value, share: $0.share, targetFraction: $0.targetFraction, isOther: false)
            }
            if !folded.isEmpty {
                parts.append(Part(
                    id: "other-holdings",
                    label: "Other",
                    detail: folded.map(\.asset.symbol).joined(separator: ", "),
                    value: folded.reduce(0) { $0 + $1.value },
                    share: folded.reduce(0) { $0 + $1.share },
                    targetFraction: combinedTarget(folded),
                    isOther: true
                ))
            }

        case .assetClass:
            parts = AssetClass.allCases.compactMap { assetClass in
                let members = holdings.filter { $0.asset.assetClass == assetClass }
                guard !members.isEmpty else { return nil }
                return Part(
                    id: assetClass.rawValue,
                    label: assetClass.label,
                    detail: members.map(\.asset.symbol).joined(separator: ", "),
                    value: members.reduce(0) { $0 + $1.value },
                    share: members.reduce(0) { $0 + $1.share },
                    targetFraction: combinedTarget(members),
                    isOther: assetClass == .other
                )
            }
        }

        // Largest first; a grey "Other" always goes last.
        parts.sort { a, b in
            if a.isOther != b.isOther { return b.isOther }
            if a.value != b.value { return a.value > b.value }
            return a.label.localizedStandardCompare(b.label) == .orderedAscending
        }

        // Colors go by position so neighboring slices are always a checked, distinguishable pair.
        let colors = Palette.sliceColors(count: parts.filter { !$0.isOther }.count)
        var next = 0
        return parts.map { part in
            let color: Color
            if part.isOther {
                color = Palette.other
            } else {
                color = colors[next]
                next += 1
            }
            return Slice(id: part.id, label: part.label, detail: part.detail, color: color,
                         value: part.value, share: part.share, targetFraction: part.targetFraction)
        }
    }

    /// The longest legend of any grouping, so switching groupings never changes the card's height.
    var maxLegendRows: Int {
        AllocationGrouping.allCases.map { slices(for: $0).count }.max() ?? 0
    }
}
