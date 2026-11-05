import ApplicationServices
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

    @ObservationIgnored
    let updater = UpdaterController()

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
        guard !macroExecutor.isRunning else { return }
        macroExecutor.execute(macro)
        if AXIsProcessTrusted() {
            macroStore.markUsed(macro.id)
        }
    }

    func stopMacro() {
        macroExecutor.stop()
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

    func toggleEditorRecording() {
        if actionRecorder.isRecording {
            actionRecorder.stopRecording()
            withAnimation(.easeInOut(duration: 0.22)) {
                macroDraft.steps.append(contentsOf: actionRecorder.recordedSteps)
            }
        } else {
            actionRecorder.startRecording()
        }
    }
}
