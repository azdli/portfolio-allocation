// The Settings window

import AppKit
import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearance"

    var id: Self { self }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    static var saved: AppearancePreference {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppearancePreference.init) ?? .system
    }

    /// Sets the appearance for every window, sheet and the About panel at once.
    /// `nil` for system setting.
    func apply() {
        NSApp.appearance = switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

/// On: targets are shares of only the holdings that have a target value. Off (default): of the whole portfolio.
enum TargetPreference {
    static let ignoresUntargetedKey = "ignoresUntargetedHoldings"
}

struct SettingsView: View {
    @Environment(PortfolioStore.self) private var store
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system
    @AppStorage(TargetPreference.ignoresUntargetedKey) private var ignoresUntargeted = false
    @State private var isConfirmingDelete = false
    @State private var deleteError: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Appearance")
                    Spacer()
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppearancePreference.allCases) { preference in
                            Text(preference.label).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .controlSize(.large)
                    .fixedSize()
                }
            }

            Section {
                Toggle("Only count holdings with a target", isOn: $ignoresUntargeted)
            } header: {
                Text("Targets")
            } footer: {
                Text("When on, targets are shares of just the holdings that have one, and To Target and buy suggestions leave the rest out. When off, targets are shares of your whole portfolio.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Saved to") {
                    Text(store.fileURL.path(percentEncoded: false))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Button("Show in Finder", action: revealDataFile)
                    Spacer()
                    Button("Delete Portfolio…", role: .destructive) { isConfirmingDelete = true }
                }
                .disabled(!store.hasSavedFile)
            } header: {
                Text("Data")
            } footer: {
                Text("Every change is saved the moment you make it. The file is encrypted with a key kept in your login keychain, so only this app on this Mac can open it.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 460)
        .onChange(of: appearance) { _, newValue in
            newValue.apply()
        }
        .alert("Delete Your Portfolio?", isPresented: $isConfirmingDelete) {
            Button("Delete Portfolio", role: .destructive, action: deletePortfolio)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all of your accounts, holdings and targets, along with the encryption key that protects them. It can't be undone.")
        }
        .alert("Your Portfolio Couldn't Be Deleted", item: $deleteError) { _ in
            Button("OK") {}
        } message: { message in
            Text(message)
        }
    }

    private func revealDataFile() {
        NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
    }

    private func deletePortfolio() {
        do {
            try store.deleteAllData()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}
