import AppKit
import SwiftUI

final class MainWindowController: NSObject, NSWindowDelegate, NSToolbarDelegate {
    private let window: NSWindow
    private var editorWindow: NSWindow?
    private var hudPanel: NSPanel?
    private var windowsHiddenForRun: [NSWindow] = []
    let state = AppState()

    /// True while a macro run is being presented (app windows hidden, HUD shown).
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

    // MARK: - Execution HUD

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
        // Pick the screen BEFORE hiding windows (NSScreen.main can go nil once the app has no key window).
        let targetScreen = window.screen ?? editorWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
        // Show the HUD first so there is always something visible, then hide the app windows.
        showHUD(on: targetScreen)
        // Only hide the app windows if the HUD is really on screen — never leave nothing visible.
        guard let panel = hudPanel, panel.isVisible else { return }
        windowsHiddenForRun = NSApp.windows.filter { win in
            win.isVisible && win !== panel && !(win is NSPanel)
        }
        for win in windowsHiddenForRun { win.orderOut(nil) }
    }

    private func endRunPresentation() {
        hudPanel?.orderOut(nil)
        for win in windowsHiddenForRun { win.makeKeyAndOrderFront(nil) }
        windowsHiddenForRun = []
        if !NSApp.isActive { NSApp.activate(ignoringOtherApps: true) }
    }

    private func showHUD(on screen: NSScreen?) {
        if hudPanel == nil {
            let panel = NonFocusingHUDPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 60),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isReleasedWhenClosed = false
            panel.level = .statusBar
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            // Never let the status HUD take keyboard focus away from the app being automated:
            // it can't become the key/main window, and only ever takes focus if a control truly needs it.
            panel.becomesKeyOnlyIfNeeded = true
            // Critical: NSPanel hides itself when the app deactivates (default true). The whole point
            // is for the HUD to stay visible while the macro drives OTHER apps, so disable that.
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
            panel.contentView = NSHostingView(
                rootView: ExecutionHUDView(
                    executor: state.macroExecutor,
                    onStop: { [weak self] in self?.state.stopMacro() }
                )
            )
            hudPanel = panel
        }

        guard let panel = hudPanel, let hosting = panel.contentView else { return }
        hosting.layoutSubtreeIfNeeded()
        var size = hosting.fittingSize
        if size.width < 100 || size.height < 20 { size = NSSize(width: 320, height: 60) }
        panel.setContentSize(size)

        let margin: CGFloat = 20
        let frame = (screen ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        panel.setFrameOrigin(NSPoint(
            x: frame.maxX - size.width - margin,
            y: frame.maxY - size.height - margin
        ))
        panel.orderFrontRegardless()
    }
}

/// Status HUD panel that can never steal keyboard focus from the app a macro is driving.
private final class NonFocusingHUDPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
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
