// Portfolio home. Edits it and loads and saves it as an encrypted file.

import CryptoKit
import Foundation
import Observation

struct StoreAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Owns the portfolio and saves it, encrypted, after every change.
@Observable
final class PortfolioStore {
    private(set) var portfolio: Portfolio {
        didSet { save() }
    }

    var alert: StoreAlert?

    /// Set when a saved portfolio exists but can't be opened right now (for example, keychain access was denied).
    private(set) var lockedReason: String?

    var isLocked: Bool { lockedReason != nil }

    /// Whether an encrypted portfolio file is on disk.
    private(set) var hasSavedFile = false

    /// Where the encrypted portfolio is saved. Every change is written here immediately.
    @ObservationIgnored let fileURL: URL
    @ObservationIgnored private let keychainService: String
    @ObservationIgnored private var key: SymmetricKey?
    @ObservationIgnored private var isLoading = false

    init(fileURL: URL = PortfolioStore.defaultFileURL, keychainService: String = PortfolioStore.defaultKeychainService) {
        self.fileURL = fileURL
        self.keychainService = keychainService
        self.portfolio = Portfolio()
        loadFromDisk()
    }

    /// `~/Library/Containers/<app>/Data/Library/Application Support/Portfolio Allocation/portfolio.encrypted`
    static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "Portfolio Allocation", directoryHint: .isDirectory)
            .appending(path: "portfolio.encrypted", directoryHint: .notDirectory)
    }

    static let defaultKeychainService = "local.portfolio-allocation"

    func snapshot(cashToInvest: Double, ignoringUntargeted: Bool = false) -> PortfolioSnapshot {
        PortfolioSnapshot(portfolio: portfolio, cashToInvest: cashToInvest, ignoringUntargeted: ignoringUntargeted)
    }

    // MARK: - Lookups

    /// Symbols held in an account, in table order.
    func symbols(in accountID: Account.ID) -> [String] {
        let held = Set(portfolio.positions.filter { $0.accountID == accountID }.map(\.assetID))
        return Self.tableOrder(portfolio.assets).filter { held.contains($0.id) }.map(\.symbol)
    }

    /// Assets in the order they were added, with the cash class last.
    static func tableOrder(_ assets: [Asset]) -> [Asset] {
        assets.filter { $0.assetClass != .cash } + assets.filter { $0.assetClass == .cash }
    }

    // MARK: - Targets

    /// The highest target an asset can have while all targets total at most 100%.
    func maximumTarget(for assetID: Asset.ID?) -> Double {
        portfolio.maximumTarget(for: assetID)
    }

    /// Caps an entered target so all targets total at most 100%
    func cappedTarget(_ entered: Double, for assetID: Asset.ID?, current: Double?) -> Double? {
        let maximum = maximumTarget(for: assetID)
        guard entered > maximum else { return entered }
        return maximum > 0 ? maximum : current
    }

    func setTarget(_ targetPercent: Double?, for assetID: Asset.ID) {
        guard let index = portfolio.assets.firstIndex(where: { $0.id == assetID }) else { return }
        portfolio.assets[index].targetPercent = targetPercent.map { min($0, maximumTarget(for: assetID)) }
    }

    // MARK: - Editing assets

    func setPrice(_ price: Double, for assetID: Asset.ID) {
        guard let index = portfolio.assets.firstIndex(where: { $0.id == assetID }) else { return }
        portfolio.assets[index].price = price
    }

    func removeAsset(_ assetID: Asset.ID) {
        var updated = portfolio
        updated.positions.removeAll { $0.assetID == assetID }
        updated.assets.removeAll { $0.id == assetID }
        portfolio = updated
    }

    // MARK: - Editing positions

    func setShares(_ shares: Double, for positionID: Position.ID) {
        guard let index = portfolio.positions.firstIndex(where: { $0.id == positionID }) else { return }
        portfolio.positions[index].shares = shares
    }

    func setCostBasis(_ costBasis: Double, for positionID: Position.ID) {
        guard let index = portfolio.positions.firstIndex(where: { $0.id == positionID }) else { return }
        portfolio.positions[index].costBasis = costBasis
    }

    /// Removes one account's position. An asset left with no positions leaves the portfolio
    func removePosition(_ positionID: Position.ID) {
        var updated = portfolio
        updated.positions.removeAll { $0.id == positionID }
        Self.removeUnheldAssets(from: &updated)
        portfolio = updated
    }

    struct NewAsset {
        var symbol: String
        var name: String
        var assetClass: AssetClass
        var price: Double
        var targetPercent: Double?
    }

    enum AssetChoice {
        case existing(Asset.ID)
        case new(NewAsset)
    }

    func addPosition(_ choice: AssetChoice, accountID: Account.ID, shares: Double, costBasis: Double) {
        var updated = portfolio
        let assetID: Asset.ID
        switch choice {
        case .existing(let id):
            assetID = id
        case .new(let new):
            let asset = Asset(
                symbol: new.symbol,
                name: new.name,
                assetClass: new.assetClass,
                price: new.price,
                targetPercent: new.targetPercent.map { min($0, maximumTarget(for: nil)) }
            )
            updated.assets.append(asset)
            assetID = asset.id
        }
        updated.positions.append(Position(assetID: assetID, accountID: accountID, shares: shares, costBasis: costBasis))
        portfolio = updated
    }

    // MARK: - Editing accounts

    @discardableResult
    func addAccount(brokerage: String, name: String) -> Account.ID {
        let account = Account(brokerage: brokerage, name: name)
        portfolio.accounts.append(account)
        return account.id
    }

    func updateAccount(_ account: Account) {
        guard let index = portfolio.accounts.firstIndex(where: { $0.id == account.id }) else { return }
        portfolio.accounts[index] = account
    }

    /// Deletes the account and its positions. Assets no longer held anywhere leave the portfolio
    func deleteAccount(_ accountID: Account.ID) {
        var updated = portfolio
        updated.positions.removeAll { $0.accountID == accountID }
        updated.accounts.removeAll { $0.id == accountID }
        Self.removeUnheldAssets(from: &updated)
        portfolio = updated
    }

    func loadSamplePortfolio() {
        portfolio = SampleData.portfolio
    }

    private static func removeUnheldAssets(from portfolio: inout Portfolio) {
        let held = Set(portfolio.positions.map(\.assetID))
        portfolio.assets.removeAll { !held.contains($0.id) }
    }

    // MARK: - Loading

    /// Reads the encrypted portfolio.
    func loadFromDisk() {
        isLoading = true
        defer { isLoading = false }
        lockedReason = nil

        if exists(fileURL) {
            loadEncrypted()
        } else {
            portfolio = Portfolio()
        }
        hasSavedFile = exists(fileURL)
    }

    // MARK: - Deleting

    /// Permanently deletes the portfolio and starts empty. The key is deleted first.
    func deleteAllData() throws {
        try KeychainKey.delete(service: keychainService)
        key = nil

        let folder = fileURL.deletingLastPathComponent()
        let setAside = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .filter { $0.lastPathComponent.hasPrefix("portfolio-unreadable-") } ?? []
        for url in [fileURL] + setAside where exists(url) {
            try FileManager.default.removeItem(at: url)
        }

        isLoading = true
        portfolio = Portfolio()
        isLoading = false
        lockedReason = nil
        hasSavedFile = false
    }

    private func loadEncrypted() {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            lockedReason = "Your portfolio file couldn't be read: \(error.localizedDescription)"
            return
        }

        let key: SymmetricKey
        do {
            key = try KeychainKey.load(service: keychainService)
        } catch KeychainKey.Failure.notFound {
            let kept = setAside(fileURL)
            portfolio = Portfolio()
            alert = StoreAlert(
                title: "Your Portfolio Couldn't Be Decrypted",
                message: "Its encryption key is no longer in your keychain, so the file can't be opened on this Mac. It was kept as “\(kept)” in case the key is restored. You're starting with an empty portfolio."
            )
            return
        } catch {
            // Access refused (or the keychain is unavailable). Leave the file as is.
            lockedReason = "Portfolio Allocation couldn't get its encryption key from your keychain (\(error.localizedDescription)). Your portfolio is safe and unchanged. Choose Try Again, and allow access when macOS asks."
            return
        }

        do {
            portfolio = try JSONDecoder().decode(Portfolio.self, from: PortfolioCrypto.open(data, with: key))
            self.key = key
        } catch {
            let kept = setAside(fileURL)
            self.key = key
            portfolio = Portfolio()
            alert = StoreAlert(
                title: "Your Portfolio File Is Damaged",
                message: "It couldn't be decrypted, possibly because it was changed outside the app. It was kept as “\(kept)”. You're starting with an empty portfolio."
            )
        }
    }

    // MARK: - Saving

    private func save() {
        guard !isLoading, !isLocked else { return }
        do {
            let key = try key ?? KeychainKey.loadOrCreate(service: keychainService)
            self.key = key
            try write(portfolio, with: key)
        } catch {
            NSLog("Portfolio Allocation: couldn't save portfolio: \(error)")
            alert = StoreAlert(
                title: "Your Change Couldn't Be Saved",
                message: error.localizedDescription
            )
        }
    }

    private func write(_ portfolio: Portfolio, with key: SymmetricKey) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        try PortfolioCrypto.seal(encoder.encode(portfolio), with: key).write(to: fileURL, options: .atomic)
        hasSavedFile = true
    }

    // MARK: - Helpers

    private func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    /// Renames a file that can't be used so it's kept but out of the way. Returns the new name.
    private func setAside(_ url: URL) -> String {
        let stamp = Int(Date().timeIntervalSince1970)
        let name = "\(url.deletingPathExtension().lastPathComponent)-unreadable-\(stamp).\(url.pathExtension)"
        try? FileManager.default.moveItem(at: url, to: url.deletingLastPathComponent().appending(path: name))
        NSLog("Portfolio Allocation: set aside \(url.lastPathComponent) as \(name)")
        return name
    }
}
