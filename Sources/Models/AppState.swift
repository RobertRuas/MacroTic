import AppKit
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
            var updated = macroDraft.makeMacro(
                preservingID: editID,
                createdAt: original.createdAt,
                lastUsedAt: original.lastUsedAt,
                executionCount: original.executionCount
            )
            updated.isFavorite = original.isFavorite
            macroStore.save(updated)
        } else {
            macroStore.save(macro)
            // After a first save, keep editing the same macro so further saves update it
            // (and "Salvar Alterações" doesn't keep creating duplicates).
            editingMacroID = macro.id
        }
    }

    func closeEditor() {
        editingMacroID = nil
        isCreatingMacro = false
    }

    func deleteMacro(_ id: UUID) {
        let name = macroStore.macros.first(where: { $0.id == id })?.name ?? ""
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = name.isEmpty ? "Apagar esta macro?" : "Apagar a macro \u{201C}\(name)\u{201D}?"
        alert.informativeText = "Esta ação não pode ser desfeita."
        alert.addButton(withTitle: "Cancelar")
        let deleteButton = alert.addButton(withTitle: "Apagar")
        deleteButton.hasDestructiveAction = true
        guard alert.runModal() == .alertSecondButtonReturn else { return }
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
