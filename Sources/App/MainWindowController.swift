import AppKit
import SwiftUI

final class MainWindowController: NSObject, NSWindowDelegate, NSToolbarDelegate {
    private let window: NSWindow
    private var editorWindow: NSWindow?
    let state = AppState()

    private static let settingsItemID = NSToolbarItem.Identifier("settings")

    private static var titleWithVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        return "MacroTic — v\(version)"
    }

    override init() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 510),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = Self.titleWithVersion
        window.contentMinSize = NSSize(width: 750, height: 510)
        window.contentView = NSHostingView(rootView: MainWindowView(state: state))
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.center()
        window.makeKeyAndOrderFront(nil)
        observeEditingState()
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard itemIdentifier == Self.settingsItemID else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = "Configurações"
        item.toolTip = "Configurações"
        item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Configurações")
        item.target = self
        item.action = #selector(toggleSettings)
        return item
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.settingsItemID]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.settingsItemID]
    }

    @objc private func toggleSettings() {
        state.selectedSection = state.selectedSection == .settings ? .home : .settings
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
            executor: state.macroExecutor,
            recorder: state.actionRecorder,
            onRun: { macro in state.macroExecutor.execute(macro) },
            onStopRun: { state.stopMacro() },
            onToggleRecord: { state.toggleEditorRecording() },
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
