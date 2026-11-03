import SwiftUI

struct TestLabView: View {
    let state: AppState

    private var tester: ActionTester { state.actionTester }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                stepsCard
                optionsCard
                logCard
            }
            .padding(24)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Laboratório de Testes")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Monte uma ação, execute e veja se funciona. Use a contagem regressiva para focar o app de destino antes da execução.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ações")
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(MacroStepKind.allCases) { kind in
                        Button {
                            tester.addStep(kind)
                        } label: {
                            Label(kind.title, systemImage: kind.icon)
                        }
                    }
                } label: {
                    Label("Adicionar", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            if tester.steps.isEmpty {
                Text("Nenhuma ação. Clique em Adicionar para criar uma e testá-la.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(tester.steps.enumerated()), id: \.element.id) { index, step in
                        stepRow(index: index, step: step)
                    }
                }
            }

            if tester.steps.count > 1 {
                HStack {
                    Spacer()
                    Button {
                        tester.testAll()
                    } label: {
                        Label("Testar todas em sequência", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tester.isBusy)
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func stepRow(index: Int, step: MacroStep) -> some View {
        let id = step.id
        let isRunning = tester.runningStepID == id

        return HStack(spacing: 8) {
            MacroStepRowView(
                step: Binding(
                    get: { tester.steps.first(where: { $0.id == id }) ?? step },
                    set: { newValue in
                        if let i = tester.steps.firstIndex(where: { $0.id == id }) {
                            tester.steps[i] = newValue
                        }
                    }
                ),
                position: index,
                total: tester.steps.count,
                isSelected: isRunning,
                isTesting: isRunning,
                testDisabled: tester.isBusy,
                onTest: { tester.test(step) },
                onReorder: { dragged in tester.move(dragged, before: id) },
                onMoveUp: { tester.moveUp(id) },
                onMoveDown: { tester.moveDown(id) },
                onDuplicate: { tester.duplicateStep(id) },
                onRemove: { tester.removeStep(id) }
            )

            Button {
                tester.test(step)
            } label: {
                if isRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Testar", systemImage: "play.fill")
                        .font(.caption)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(tester.isBusy)
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Opções de execução")
                .font(.headline)

            Stepper(
                "Contagem antes de executar: \(tester.countdownSeconds) s",
                value: Binding(
                    get: { tester.countdownSeconds },
                    set: { tester.countdownSeconds = $0 }
                ),
                in: 0...10
            )

            HStack {
                Text("Intervalo entre ações: \(String(format: "%.1f", tester.intervalBetweenSteps)) s")
                Slider(
                    value: Binding(
                        get: { tester.intervalBetweenSteps },
                        set: { tester.intervalBetweenSteps = $0 }
                    ),
                    in: 0.1...5,
                    step: 0.1
                )
                .frame(maxWidth: 200)
            }

            Toggle(
                "Ocultar o MacroTic durante o teste",
                isOn: Binding(
                    get: { tester.hidesApp },
                    set: { tester.hidesApp = $0 }
                )
            )

            if tester.isBusy {
                HStack(spacing: 10) {
                    if tester.remainingCountdown > 0 {
                        Text("Executando em \(tester.remainingCountdown)…")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    } else {
                        ProgressView().controlSize(.small)
                        Text("Executando…")
                    }
                    Spacer()
                    Button("Cancelar", role: .cancel) {
                        tester.cancel()
                    }
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Resultados")
                    .font(.headline)
                Spacer()
                if !tester.log.isEmpty {
                    Button("Limpar") { tester.clearLog() }
                        .buttonStyle(.borderless)
                }
            }

            if tester.log.isEmpty {
                Text("Os resultados dos testes aparecem aqui.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tester.log) { entry in
                    HStack(spacing: 10) {
                        Image(systemName: entry.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(entry.success ? .green : .red)
                        Text(entry.timeLabel)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(entry.kind.title)
                            .font(.callout)
                            .fontWeight(.medium)
                        Text(entry.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(entry.durationLabel)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}
