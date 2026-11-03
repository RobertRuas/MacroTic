import AppKit
import SwiftUI

final class MainWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private var editorWindow: NSWindow?
    let state = AppState()

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 510),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = "MacroTic"
        window.contentMinSize = NSSize(width: 750, height: 510)
        window.contentView = NSHostingView(rootView: MainWindowView(state: state))
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        observeEditingState()
    }

    private func observeEditingState() {
        withObservationTracking { [weak self] in
            _ = self?.state.isCreatingMacro
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.applyEditingState()
                self?.observeEditingState()
            }
        }
    }

    private func applyEditingState() {
        if state.isCreatingMacro {
            showEditor()
        } else {
            hideEditor()
        }
    }

    private func showEditor() {
        if editorWindow == nil {
            let w = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 540),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            w.contentView = NSHostingView(rootView: EditorRoot(state: state))
            w.delegate = self
            w.isReleasedWhenClosed = false
            w.standardWindowButton(.zoomButton)?.isEnabled = false
            w.standardWindowButton(.miniaturizeButton)?.isEnabled = false
            editorWindow = w
        }
        editorWindow?.title = state.isEditing ? "Editar Macro" : "Nova Macro"
        window.orderOut(nil)
        editorWindow?.center()
        editorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hideEditor() {
        editorWindow?.orderOut(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === editorWindow {
            state.editingMacroID = nil
            state.isCreatingMacro = false
            return false
        }
        return true
    }
}

private struct EditorRoot: View {
    let state: AppState

    var body: some View {
        CreateMacroView(
            draft: state.macroDraft,
            tester: state.actionTester,
            executor: state.macroExecutor,
            onRun: { macro in state.macroExecutor.execute(macro) },
            onStopRun: { state.stopMacro() },
            isEditing: state.isEditing,
            existingNames: state.macroStore.macros
                .filter { $0.id != state.editingMacroID }
                .map { $0.name },
            editingMacroID: state.editingMacroID,
            onCancel: {
                state.editingMacroID = nil
                state.isCreatingMacro = false
            },
            onSave: { macro in state.saveMacro(macro) }
        )
    }
}
