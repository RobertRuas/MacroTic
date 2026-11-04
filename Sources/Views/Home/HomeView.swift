import SwiftUI

struct HomeView: View {
    let state: AppState

    var body: some View {
        VStack(spacing: 14) {
            ActionsRow(
                onNewMacro: { state.beginCreatingMacro() },
                onRecord: {
                    if state.actionRecorder.isRecording {
                        state.stopRecording()
                    } else {
                        state.startRecording()
                    }
                },
                isRecording: state.actionRecorder.isRecording
            )

            if state.macroExecutor.isRunning {
                executionBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ScrollView {
                MacroListView(
                    store: state.macroStore,
                    executor: state.macroExecutor,
                    onPlay: { macro in state.playMacro(macro) },
                    onStop: { state.stopMacro() },
                    onEdit: { macro in state.beginEditingMacro(macro) },
                    onDelete: { id in state.deleteMacro(id) }
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.background)
        .animation(.easeInOut(duration: 0.3), value: state.macroExecutor.isRunning)
    }

    private var executionBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            if case .running(let step, let total) = state.macroExecutor.state {
                Text(state.macroExecutor.totalRepetitions > 1
                     ? "Repetição \(state.macroExecutor.currentRepetition)/\(state.macroExecutor.totalRepetitions) · passo \(step + 1) de \(total)..."
                     : "Executando passo \(step + 1) de \(total)...")
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
