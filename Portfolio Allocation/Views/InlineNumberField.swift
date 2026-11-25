// A number that reads as plain table text and edits in place when clicked

import AppKit
import SwiftUI

/// A number that reads as plain table text. Hovering shows a faint highlight sized to the number, clicking turns it into an editable field, and Return, Tab or clicking away saves it.
struct InlineNumberField: View {
    let label: String
    let value: Double?
    var placeholder: String = ""
    /// Whether clearing the field is a valid edit (reported as `nil`).
    var allowsEmpty = false
    let format: (Double) -> String
    /// Lets the owner change an entered value before it's saved (for example, to cap it). Returns the value to save, or `nil` to save nothing.
    var adjust: ((Double) -> Double?)? = nil
    let onCommit: (Double?) -> Void

    @State private var text = ""
    @State private var isHovering = false
    @State private var discardOnBlur = false
    @FocusState private var isFocused: Bool

    var body: some View {
        // An invisible copy of the text that the box's width
        Text(measuredText)
            .lineLimit(1)
            .fixedSize()
            .padding(.leading, 5)
            .hidden()
            .overlay(alignment: .trailing) {
                TextField(label, text: $text, prompt: Text(placeholder))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    // Match neighboring table text
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.trailing)
                    .focused($isFocused)
            }
            // Standard macOS text-field padding
            .padding(.horizontal, 3)
            .padding(.vertical, 4)
            .background(fill, in: Self.border)
            .overlay {
                Self.border
                    .strokeBorder(Color.accentColor, lineWidth: 1.5)
                    .opacity(isFocused ? 1 : 0)
            }
            .contentShape(.rect)
            .onHover { isHovering = $0 }
            // Let the box spill into the column gap so the digits line up with read-only cells.
            .padding(.trailing, -5)
            .onAppear { text = displayText }
            // If the row collapses or the window closes mid-edit, keep what was typed.
            .onDisappear { commit() }
            .onChange(of: value) {
                if !isFocused { text = displayText }
            }
            .onChange(of: isFocused) { _, focused in
                if focused {
                    // Select the whole value so typing replaces it
                    DispatchQueue.main.async {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    }
                } else if discardOnBlur {
                    discardOnBlur = false
                    text = displayText
                } else {
                    commit()
                }
            }
            .onSubmit { isFocused = false }
            .onExitCommand {
                discardOnBlur = true
                isFocused = false
            }
            .accessibilityLabel(label)
    }

    private var measuredText: String {
        if !text.isEmpty { return text }
        return placeholder.isEmpty ? "0" : placeholder
    }

    private static let border: TextInputBorderShape = .textInputBorder

    private var fill: Color {
        if isFocused { return Color(nsColor: .textBackgroundColor) }
        // A system fill, so the hover highlight strengthens with Increase Contrast.
        return isHovering ? Color(nsColor: .secondarySystemFill) : .clear
    }

    private var displayText: String {
        value.map(format) ?? ""
    }

    private func commit() {
        let entered = text.trimmed
        defer { text = displayText }
        guard entered != displayText else { return }
        if entered.isEmpty {
            if allowsEmpty, value != nil { onCommit(nil) }
            return
        }
        guard let parsed = Fmt.parse(entered), parsed >= 0 else { return }
        let result: Double? = if let adjust { adjust(parsed) } else { parsed }
        guard let result, result != value else { return }
        onCommit(result)
    }
}
