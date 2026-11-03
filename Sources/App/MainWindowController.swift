import AppKit
import SwiftUI

final class MainWindowController {
    private let window: NSWindow
    let state = AppState()

    init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "MacroTic"
        window.contentMinSize = NSSize(width: 600, height: 400)
        window.contentView = NSHostingView(rootView: MainWindowView(state: state))
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
