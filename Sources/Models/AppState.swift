import SwiftUI

@Observable
final class AppState {
    var selectedSection: AppSection? = .home

    var isCreatingMacro: Bool = false
    var macroDraft = MacroDraft()

    let macroStore = MacroStore()
    let macroExecutor = MacroExecutor()
    let actionRecorder = ActionRecorder()
    let inspectorState = InspectorState()

    @ObservationIgnored
    let updater = UpdaterController()

    @ObservationIgnored
    lazy var inspectorPanel = InspectorPanelController(inspectorState: inspectorState)

    func beginCreatingMacro() {
        macroDraft = MacroDraft()
        isCreatingMacro = true
    }

    func saveMacro(_ macro: Macro) {
        macroStore.save(macro)
        isCreatingMacro = false
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
        macroDraft = actionRecorder.makeDraft()
        isCreatingMacro = true
    }
}
