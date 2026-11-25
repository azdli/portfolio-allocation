// Data models: accounts, assets, positions and portfolio

import Foundation

enum AssetClass: String, Codable, CaseIterable, Identifiable, Hashable {
    case usStocks
    case internationalStocks
    case bonds
    case cash
    case gold
    case crypto
    case other

    var id: Self { self }

    var label: String {
        switch self {
        case .usStocks: "US stocks"
        case .internationalStocks: "International stocks"
        case .bonds: "Bonds"
        case .cash: "Cash"
        case .gold: "Gold"
        case .crypto: "Crypto"
        case .other: "Other"
        }
    }
}

struct Account: Identifiable, Codable, Hashable {
    var id = UUID()
    var brokerage: String
    var name: String

    var displayName: String {
        let brokerage = brokerage.trimmed
        let name = name.trimmed
        switch (brokerage.isEmpty, name.isEmpty) {
        case (false, false): return "\(brokerage) · \(name)"
        case (false, true): return brokerage
        case (true, false): return name
        case (true, true): return "Untitled account"
        }
    }
}

/// A fund, stock or other security. Price and target live here, so one edit applies to every account.
struct Asset: Identifiable, Codable, Hashable {
    var id = UUID()
    var symbol: String
    var name: String
    var assetClass: AssetClass
    var price: Double
    /// Target share of the whole portfolio in percent (40 means 40%). `nil` means no target.
    var targetPercent: Double?
}

/// One asset held in one account, entered as the totals shown on the brokerage's positions page.
struct Position: Identifiable, Codable, Hashable {
    var id = UUID()
    var assetID: Asset.ID
    var accountID: Account.ID
    var shares: Double
    var costBasis: Double
}

struct Portfolio: Codable, Equatable {
    var accounts: [Account] = []
    var assets: [Asset] = []
    var positions: [Position] = []
}

// Lookups live on the value so the Add Holding sheet can query its pre-save copy.
extension Portfolio {
    func asset(withSymbol symbol: String) -> Asset? {
        let symbol = symbol.trimmed
        guard !symbol.isEmpty else { return nil }
        return assets.first { $0.symbol.caseInsensitiveCompare(symbol) == .orderedSame }
    }

    func position(assetID: Asset.ID, accountID: Account.ID) -> Position? {
        positions.first { $0.assetID == assetID && $0.accountID == accountID }
    }

    /// The highest target an asset can have while all targets total at most 100%.
    /// Pass `nil` for an asset that doesn't exist yet.
    func maximumTarget(for assetID: Asset.ID?) -> Double {
        let others = assets
            .filter { $0.id != assetID }
            .compactMap(\.targetPercent)
            .reduce(0, +)
        return (max(0, 100 - others) * 100).rounded() / 100
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
