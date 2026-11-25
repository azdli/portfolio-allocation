// Ends text editing when you click outside a text field.

import AppKit

/// macOS moves focus only when a click lands on something that takes it, so clicking empty space
/// would leave a text field focused and its edit unsaved. Any click outside a text field ends the edit.
enum ClickAwayEndsEditing {
    /// Watches clicks in every window of the app. Keep the returned monitor for the app's lifetime.
    static func install() -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            handle(event)
            return event
        }
    }

    static func handle(_ event: NSEvent) {
        guard let window = event.window,
              window.firstResponder is NSText, // a field is being edited
              // The window's frame view has no superview, so it takes window coordinates.
              let frameView = window.contentView?.superview,
              let hit = frameView.hitTest(event.locationInWindow)
        else { return }

        var view: NSView? = hit
        while let current = view {
            if current is NSTextField || current is NSText { return }
            view = current.superview
        }
        window.makeFirstResponder(nil)
    }
}
