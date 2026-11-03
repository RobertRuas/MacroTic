import SwiftUI

@Observable
final class AppState {
    var selectedSection: AppSection? = .home

    var isCreatingMacro: Bool = false
    var macroDraft = MacroDraft()
    var editingMacroID: UUID? = nil

    let macroStore = MacroStore()
    let macroExecutor = MacroExecutor()
    let actionRecorder = ActionRecorder()
    let inspectorState = InspectorState()

    @ObservationIgnored
    let updater = UpdaterController()

    @ObservationIgnored
    lazy var inspectorPanel = InspectorPanelController(inspectorState: inspectorState)

    var isEditing: Bool { editingMacroID != nil }

    func beginCreatingMacro() {
        editingMacroID = nil
        macroDraft = MacroDraft()
        isCreatingMacro = true
    }

    func beginEditingMacro(_ macro: Macro) {
        editingMacroID = macro.id
        macroDraft = MacroDraft()
        macroDraft.loadFrom(macro)
        isCreatingMacro = true
    }

    func saveMacro(_ macro: Macro) {
        if let editID = editingMacroID,
           let original = macroStore.macros.first(where: { $0.id == editID }) {
            let updated = macroDraft.makeMacro(
                preservingID: editID,
                createdAt: original.createdAt,
                lastUsedAt: original.lastUsedAt,
                executionCount: original.executionCount
            )
            macroStore.save(updated)
        } else {
            macroStore.save(macro)
        }
        editingMacroID = nil
        isCreatingMacro = false
    }

    func deleteMacro(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.25)) {
            macroStore.delete(id)
        }
    }

    func playMacro(_ macro: Macro) {
        macroExecutor.execute(macro)
        macroStore.markUsed(macro.id)
    }

    func stopMacro() {
        macroExecutor.stop()
    }

    func toggleInspector() {
        inspectorPanel.toggle()
    }

    func startRecording() {
        actionRecorder.startRecording()
    }

    func stopRecording() {
        actionRecorder.stopRecording()
        editingMacroID = nil
        macroDraft = actionRecorder.makeDraft()
        isCreatingMacro = true
    }
}
