import SwiftUI

struct HomeView: View {
    let state: AppState

    var body: some View {
        VStack(spacing: 14) {
            ActionsRow(
                onNewMacro: { state.beginCreatingMacro() },
                onInspector: { state.toggleInspector() },
                onRecord: {
                    if state.actionRecorder.isRecording {
                        state.stopRecording()
                    } else {
                        state.startRecording()
                    }
                },
                isRecording: state.actionRecorder.isRecording,
                isInspectorActive: state.inspectorState.isActive
            )

            if state.macroExecutor.isRunning {
                executionBanner
            }

            ScrollView {
                MacroListView(
                    store: state.macroStore,
                    executor: state.macroExecutor,
                    onPlay: { macro in state.playMacro(macro) },
                    onStop: { state.stopMacro() }
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
        .sheet(
            isPresented: Binding(
                get: { state.isCreatingMacro },
                set: { state.isCreatingMacro = $0 }
            )
        ) {
            CreateMacroView(
                draft: state.macroDraft,
                onCancel: { state.isCreatingMacro = false },
                onSave: { macro in state.saveMacro(macro) }
            )
        }
    }

    private var executionBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            if case .running(let step, let total) = state.macroExecutor.state {
                Text("Executando passo \(step + 1) de \(total)...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Parar") {
                state.stopMacro()
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.blue.opacity(0.3), lineWidth: 1)
        )
    }
}
