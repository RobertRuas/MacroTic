import AppKit
import ApplicationServices

@main
enum MacroTicApp {
    static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.delegate = appDelegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController!

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // While a macro runs the app's windows are hidden on purpose (only the HUD panel stays).
        // Don't let that count as "the last window closed" and quit the app mid-run.
        if windowController?.isPresentingRun == true { return false }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        windowController = MainWindowController()
        NSApp.activate(ignoringOtherApps: true)
        requestAccessibilityPermissionIfNeeded()
    }

    private func requestAccessibilityPermissionIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
