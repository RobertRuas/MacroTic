import AppKit
import SwiftUI

final class MainWindowController {
    private let window: NSWindow
    let state = AppState()

    init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MacroTic"
        window.contentMinSize = NSSize(width: 560, height: 380)
        window.contentView = NSHostingView(rootView: MainWindowView(state: state))
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
