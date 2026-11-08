import AppKit
import SwiftUI

final class MainWindowController: NSObject, NSWindowDelegate, NSToolbarDelegate {
    private let window: NSWindow
    private var editorWindow: NSWindow?
    private var windowsHiddenForRun: [NSWindow] = []
    let state = AppState()

    /// True while a macro run is being presented (app windows hidden).
    /// Used by AppDelegate so hiding the last window during a run doesn't quit the app.
    var isPresentingRun: Bool { !windowsHiddenForRun.isEmpty }

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
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        observeEditingState()
        observeRunState()
        state.updater.checkForUpdatesAtStartup()
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
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            w.contentView = NSHostingView(rootView: EditorRoot(state: state))
            w.contentMinSize = NSSize(width: 620, height: 480)
            w.delegate = self
            w.isReleasedWhenClosed = false
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
            state.closeEditor()
            return false
        }
        // Main window: close normally only from the home screen.
        // From any other screen (Settings/Manual), confirm before closing the app.
        if state.selectedSection == .home {
            return true
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Fechar o MacroTic?"
        alert.informativeText = "Você não está na tela inicial. Deseja mesmo fechar o aplicativo?"
        alert.addButton(withTitle: "Cancelar")
        let closeButton = alert.addButton(withTitle: "Fechar")
        closeButton.hasDestructiveAction = true
        return alert.runModal() == .alertSecondButtonReturn
    }

    // MARK: - Execution presentation

    private func observeRunState() {
        withObservationTracking { [weak self] in
            _ = self?.state.macroExecutor.isRunning
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.applyRunState()
                self?.observeRunState()
            }
        }
    }

    private func applyRunState() {
        if state.macroExecutor.isRunning {
            beginRunPresentation()
        } else {
            endRunPresentation()
        }
    }

    private func beginRunPresentation() {
        guard windowsHiddenForRun.isEmpty else { return }
        DebugPreviewOverlay.shared.hide()
        // No status window: just move MacroTic's own windows out of the way so they can't sit on
        // top of (or intercept events meant for) the app being automated. ⌘Esc stops the run.
        windowsHiddenForRun = NSApp.windows.filter { win in
            win.isVisible && !(win is NSPanel)
        }
        for win in windowsHiddenForRun { win.orderOut(nil) }
    }

    private func endRunPresentation() {
        for win in windowsHiddenForRun { win.makeKeyAndOrderFront(nil) }
        windowsHiddenForRun = []
        if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
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
            onRunFrom: { index in state.macroExecutor.execute(state.macroDraft.makeMacro(), startAt: index) },
            onRunSelected: { steps in
                guard !steps.isEmpty else { return }
                let draft = state.macroDraft
                let macro = Macro(
                    name: draft.trimmedName.isEmpty ? "Seleção" : draft.trimmedName,
                    details: "",
                    iconName: draft.iconName,
                    steps: steps,
                    intervalBetweenSteps: draft.intervalBetweenSteps,
                    repeatCount: 1
                )
                state.macroExecutor.execute(macro)
            },
            onStopRun: { state.stopMacro() },
            onToggleRecord: { state.toggleEditorRecording() },
            isEditing: state.isEditing,
            existingNames: state.macroStore.macros
                .filter { $0.id != state.editingMacroID }
                .map { $0.name },
            editingMacroID: state.editingMacroID,
            onCancel: { state.closeEditor() },
            onClose: { state.closeEditor() },
            onSave: { macro in state.saveMacro(macro) }
        )
    }
}
