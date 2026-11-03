import AppKit
import SwiftUI

final class InspectorPanelController {
    private var panel: NSPanel?
    private let inspectorState: InspectorState

    init(inspectorState: InspectorState) {
        self.inspectorState = inspectorState
    }

    func show() {
        if panel != nil { return }

        let contentView = NSHostingView(rootView: InspectorPanelView(inspector: inspectorState))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 140),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Inspetor"
        panel.contentView = contentView
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = panel.frame
            let origin = NSPoint(
                x: screenFrame.maxX - panelFrame.width - 20,
                y: screenFrame.maxY - panelFrame.height - 20
            )
            panel.setFrameOrigin(origin)
        }

        panel.orderFront(nil)
        self.panel = panel
        inspectorState.start()
    }

    func close() {
        inspectorState.stop()
        panel?.close()
        panel = nil
    }

    func toggle() {
        if panel != nil {
            close()
        } else {
            show()
        }
    }
}
