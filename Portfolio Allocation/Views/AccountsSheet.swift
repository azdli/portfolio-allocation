// Add, rename and delete brokerage accounts.

import SwiftUI

struct AccountsSheet: View {
    @Environment(PortfolioStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editingID: Account.ID?
    @State private var pendingDelete: Account?

    var body: some View {
        let snapshot = store.snapshot(cashToInvest: 0)
        let values = Dictionary(uniqueKeysWithValues: snapshot.accounts.map { ($0.id, $0.value) })

        VStack(alignment: .leading, spacing: 0) {
            SheetHeader("Accounts")

            ScrollViewReader { proxy in
                Form {
                    Section {
                        if store.portfolio.accounts.isEmpty {
                            Text("No accounts yet.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(store.portfolio.accounts) { account in
                            AccountEditorRow(
                                account: account,
                                value: values[account.id] ?? 0,
                                holdings: store.symbols(in: account.id),
                                isEditing: editingID == account.id,
                                toggle: {
                                    withAnimation(.snappy(duration: 0.2)) {
                                        editingID = editingID == account.id ? nil : account.id
                                    }
                                },
                                requestDelete: { pendingDelete = account }
                            )
                        }
                    }
                }
                .formStyle(.grouped)
                .onChange(of: editingID) { _, id in
                    guard let id else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation(.snappy(duration: 0.2)) {
                            proxy.scrollTo(AccountEditorRow.editorID(id))
                        }
                    }
                }
            }
        }
        // macOS adds the 65 pt button bar below this for a 620 pt sheet
        .frame(width: 520, height: 555)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        editingID = store.addAccount(brokerage: "", name: "")
                    }
                } label: {
                    Label("Add Account", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .alert(pendingDelete.map { "Delete \($0.displayName)?" } ?? "", item: $pendingDelete) { account in
            Button("Delete", role: .destructive) {
                if editingID == account.id { editingID = nil }
                store.deleteAccount(account.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { account in
            let symbols = store.symbols(in: account.id)
            if symbols.isEmpty {
                Text("This account has no holdings.")
            } else {
                Text("This also removes its \(symbols.count == 1 ? "position" : "\(symbols.count) positions") (\(symbols.joined(separator: ", "))).")
            }
        }
    }
}

private struct AccountEditorRow: View {
    @Environment(PortfolioStore.self) private var store
    let account: Account
    let value: Double
    let holdings: [String]
    let isEditing: Bool
    let toggle: () -> Void
    let requestDelete: () -> Void

    private enum Field { case brokerage, name }
    @FocusState private var focusedField: Field?

    /// Identifies an account's edit area so the sheet can scroll it into view.
    static func editorID(_ accountID: Account.ID) -> String { "editor-\(accountID.uuidString)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.displayName)
                        .fontWeight(.semibold)
                    Text(holdings.isEmpty ? "No holdings" : holdings.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(Fmt.currency(value))
                    .monospacedDigit()
                Button(action: toggle) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Rename or delete this account")
                .accessibilityLabel("Edit \(account.displayName)")
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("Brokerage") {
                        TextField("Brokerage", text: binding(\.brokerage), prompt: Text("e.g. Fidelity"))
                            .labelsHidden()
                            .multilineTextAlignment(.leading)
                            .focused($focusedField, equals: .brokerage)
                    }
                    LabeledContent("Account name") {
                        TextField("Account name", text: binding(\.name), prompt: Text("e.g. Roth IRA"))
                            .labelsHidden()
                            .multilineTextAlignment(.leading)
                            .focused($focusedField, equals: .name)
                    }
                    HStack {
                        Button("Delete Account…", role: .destructive, action: requestDelete)
                        Spacer()
                        Button("Done", action: toggle)
                    }
                }
                // Bordered, left-aligned fields on a tinted panel to make it clear where to type.
                .textFieldStyle(.bordered)
                .padding(10)
                .background(Color.accentColor.opacity(0.08), in: .rect(cornerRadius: 8, style: .continuous))
                .id(Self.editorID(account.id))
                .onAppear { focusedField = .brokerage }
            }
        }
        .padding(.vertical, 2)
    }

    private func binding(_ keyPath: WritableKeyPath<Account, String>) -> Binding<String> {
        Binding(
            get: { account[keyPath: keyPath] },
            set: { newValue in
                var updated = account
                updated[keyPath: keyPath] = newValue
                store.updateAccount(updated)
            }
        )
    }
}
