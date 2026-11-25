// The main window, menu commands, Settings, About panel and app delegate.

import SwiftUI

@main
struct PortfolioAllocationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = PortfolioStore()
    @State private var router = AppRouter()

    var body: some Scene {
        Window("Portfolio Allocation", id: "main") {
            ContentView()
                .environment(store)
                .environment(router)
        }
        .defaultSize(width: 1320, height: 920)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Portfolio Allocation") {
                    NSApp.orderFrontStandardAboutPanel(options: [.credits: AboutInfo.credits])
                }
            }
            // Every command lives in the menu bar; the toolbar repeats the frequent ones.
            CommandGroup(replacing: .newItem) {
                Button("New Holding…") { router.sheet = .addHolding }
                    .keyboardShortcut("n")
                    .disabled(store.isLocked)
                Button("Manage Accounts…") { router.sheet = .accounts }
                    .keyboardShortcut("a", modifiers: [.command, .shift])
                    .disabled(store.isLocked)
            }
        }

        // Adds "Settings…" (⌘,) to the app menu.
        Settings {
            SettingsView()
                .environment(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var clickAwayMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Before any window appears, so a forced Light or Dark never flashes the other.
        AppearancePreference.saved.apply()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        clickAwayMonitor = ClickAwayEndsEditing.install()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Save in-progress edits before quitting
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let window = NSApp.keyWindow, window.firstResponder is NSTextView else { return .terminateNow }
        window.makeFirstResponder(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

/// About panel
enum AboutInfo {
    static var credits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.paragraphSpacing = 6
        let text = """
        Track holdings across your brokerage accounts, see your allocation at a glance, \
        and find what to buy next.
        Your data is encrypted and stored only on this Mac.
        GitHub: azdli
        """
        return NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ])
    }
}

@Observable
final class AppRouter {
    var sheet: AppSheet?
}

enum AppSheet: String, Identifiable {
    case addHolding
    case accounts

    var id: Self { self }
}
