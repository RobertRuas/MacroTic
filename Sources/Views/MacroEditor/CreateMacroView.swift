import SwiftUI

struct CreateMacroView: View {
    let draft: MacroDraft
    let tester: ActionTester
    let executor: MacroExecutor
    let onRun: (Macro) -> Void
    let onStopRun: () -> Void
    var isEditing: Bool = false
    var existingNames: [String] = []
    var editingMacroID: UUID? = nil
    let onCancel: () -> Void
    let onSave: (Macro) -> Void

    private var isDuplicateName: Bool {
        let trimmed = draft.trimmedName.lowercased()
        guard !trimmed.isEmpty else { return false }
        return existingNames.contains { name in
            name.lowercased() == trimmed
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    identitySection
                    executionSection
                    stepsSection
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(width: 780, height: 600)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(isEditing ? "Editar Macro" : "Nova Macro")
                    .font(.headline)
                Text(isEditing ? "Altere o nome ou a sequência de ações." : "Dê um nome e monte a sequência de ações.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var identitySection: some View {
        VStack(spacing: 0) {
            HStack {
                TextField(
                    "Nome da macro",
                    text: Binding(get: { draft.name }, set: { draft.name = $0 })
                )
                .textFieldStyle(.plain)
                .padding(.vertical, 9)

                if isDuplicateName {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .help("Já existe uma macro com esse nome")
                }
            }

            if isDuplicateName {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.caption2)
                    Text("Já existe uma macro com esse nome.")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)
            }

            Divider()

            TextField(
                "Descrição (opcional)",
                text: Binding(get: { draft.details }, set: { draft.details = $0 })
            )
            .textFieldStyle(.plain)
            .padding(.vertical, 9)
        }
        .padding(.horizontal, 14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    private var executionSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 0) {
                intervalColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                    .frame(height: 56)
                    .padding(.horizontal, 14)
                repeatColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            Text("Espera entre cada ação e quantas vezes a sequência repete. ⌘Esc interrompe.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var intervalColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Intervalo").font(.callout)
            } icon: {
                Image(systemName: "timer").foregroundStyle(.orange)
            }

            HStack(spacing: 6) {
                TextField(
                    "0",
                    value: Binding(
                        get: { Int((draft.intervalBetweenSteps * 1000).rounded()) },
                        set: { draft.intervalBetweenSteps = Double(min(max($0, 0), 600_000)) / 1000 }
                    ),
                    format: .number.grouping(.never)
                )
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 64)

                Text("ms")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach([100, 500, 1000, 2000], id: \.self) { ms in
                    Button("\(ms)") { draft.intervalBetweenSteps = Double(ms) / 1000 }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
            }
        }
    }

    private var repeatColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Repetições").font(.callout)
            } icon: {
                Image(systemName: "repeat").foregroundStyle(.blue)
            }

            HStack(spacing: 6) {
                TextField(
                    "1",
                    value: Binding(
                        get: { draft.repeatCount },
                        set: { draft.repeatCount = min(max($0, 1), 9999) }
                    ),
                    format: .number.grouping(.never)
                )
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: 56)

                Stepper("", value: Binding(
                    get: { draft.repeatCount },
                    set: { draft.repeatCount = min(max($0, 1), 9999) }
                ), in: 1...9999)
                .labelsHidden()

                ForEach([1, 3, 5, 10, 50], id: \.self) { n in
                    Button("\(n)×") { draft.repeatCount = n }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(draft.repeatCount == n ? .accentColor : nil)
                }
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionTitle("Ações")
                Spacer()
                addMenu
            }

            VStack(spacing: 0) {
                if draft.steps.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(draft.steps.enumerated()), id: \.element.id) { pair in
                        MacroStepRowView(
                            step: stepBinding(pair.element),
                            position: pair.offset,
                            total: draft.steps.count,
                            isSelected: tester.runningStepID == pair.element.id,
                            isTesting: tester.runningStepID == pair.element.id,
                            testDisabled: tester.isBusy,
                            onTest: { tester.test(pair.element) },
                            onReorder: { draggedID in
                                draft.dropTargetID = nil
                                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                                    draft.move(draggedID, before: pair.element.id)
                                }
                            },
                            onMoveUp: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    draft.moveUp(pair.element.id)
                                }
                            },
                            onMoveDown: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    draft.moveDown(pair.element.id)
                                }
                            },
                            onDuplicate: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    draft.duplicate(pair.element.id)
                                }
                            },
                            onRemove: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    draft.remove(pair.element.id)
                                }
                            },
                            isDropTarget: draft.dropTargetID == pair.element.id,
                            onDropTargetChange: { targeted in
                                if targeted { draft.dropTargetID = pair.element.id }
                                else if draft.dropTargetID == pair.element.id { draft.dropTargetID = nil }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        if pair.offset < draft.steps.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var addMenu: some View {
        Menu {
            ForEach(MacroStepKind.allCases) { kind in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        draft.add(kind)
                    }
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

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Nenhuma ação ainda")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Use \u{201C}Adicionar\u{201D} para montar a sequência.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var footer: some View {
        HStack {
            Text(stepCountLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if executor.isRunning {
                Button {
                    onStopRun()
                } label: {
                    Label("Parar (⌘Esc)", systemImage: "stop.fill")
                }
                .tint(.red)
            } else {
                Button {
                    onRun(draft.makeMacro())
                } label: {
                    Label("Executar macro", systemImage: "play.fill")
                }
                .tint(.green)
                .disabled(draft.steps.isEmpty || tester.isBusy)
            }
            Button("Cancelar", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button(isEditing ? "Salvar Alterações" : "Salvar") {
                onSave(draft.makeMacro())
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!draft.isValid || isDuplicateName)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var stepCountLabel: String {
        draft.steps.count == 1 ? "1 ação" : "\(draft.steps.count) ações"
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }

    private func stepBinding(_ step: MacroStep) -> Binding<MacroStep> {
        Binding(
            get: { draft.steps.first(where: { $0.id == step.id }) ?? step },
            set: { newValue in
                if let index = draft.steps.firstIndex(where: { $0.id == step.id }) {
                    draft.steps[index] = newValue
                }
            }
        )
    }
}
