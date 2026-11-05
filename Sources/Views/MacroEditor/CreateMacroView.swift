import SwiftUI

struct CreateMacroView: View {
    let draft: MacroDraft
    let executor: MacroExecutor
    let recorder: ActionRecorder
    let onRun: (Macro) -> Void
    let onStopRun: () -> Void
    let onToggleRecord: () -> Void
    var isEditing: Bool = false
    var existingNames: [String] = []
    var editingMacroID: UUID? = nil
    let onCancel: () -> Void
    let onSave: (Macro) -> Void

    private var isDuplicateName: Bool {
        let trimmed = draft.trimmedName.lowercased()
        guard !trimmed.isEmpty else { return false }
        return existingNames.contains { $0.lowercased() == trimmed }
    }

    var body: some View {
        VStack(spacing: 0) {
            identityHeader
            executionBar
            Divider()
            stepsSection
            Divider()
            footer
        }
        .frame(width: 680, height: 540)
        .background(.background)
    }

    private var identityHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Image(systemName: isEditing ? "pencil.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.tint)

                TextField(
                    "Nome da macro",
                    text: Binding(get: { draft.name }, set: { draft.name = $0 })
                )
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))

                if isDuplicateName {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .help("Já existe uma macro com esse nome")
                }
            }

            TextField(
                "Adicione uma descrição",
                text: Binding(get: { draft.details }, set: { draft.details = $0 })
            )
            .textFieldStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 30)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var executionBar: some View {
        HStack(spacing: 14) {
            compactField(
                icon: "timer",
                iconColor: .orange,
                label: "Intervalo",
                suffix: "ms",
                width: 64,
                value: Binding(
                    get: { Int((draft.intervalBetweenSteps * 1000).rounded()) },
                    set: { draft.intervalBetweenSteps = Double(min(max($0, 0), 600_000)) / 1000 }
                )
            )

            Divider().frame(height: 18)

            HStack(spacing: 6) {
                Image(systemName: "repeat")
                    .foregroundStyle(.blue)
                    .font(.system(size: 11, weight: .medium))
                Text("Repetir")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                .frame(width: 52)
                Stepper(
                    "",
                    value: Binding(
                        get: { draft.repeatCount },
                        set: { draft.repeatCount = min(max($0, 1), 9999) }
                    ),
                    in: 1...9999
                )
                .labelsHidden()
                .controlSize(.mini)
                Text("×")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Label("⌘Esc interrompe", systemImage: "command.circle")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.35))
    }

    private func compactField(
        icon: String,
        iconColor: Color,
        label: String,
        suffix: String,
        width: CGFloat,
        value: Binding<Int>
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .font(.system(size: 11, weight: .medium))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("0", value: value, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(width: width)
            Text(suffix)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var stepsSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Ações")
                    .font(.subheadline.weight(.semibold))
                Text("\(draft.steps.count)")
                    .font(.caption)
                    .monospacedDigit()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                    .foregroundStyle(.secondary)
                Spacer()
                recordButton
                addMenu
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if draft.steps.isEmpty {
                emptyState
            } else {
                stepList
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var stepList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(draft.steps.enumerated()), id: \.element.id) { pair in
                    MacroStepRowView(
                        step: stepBinding(pair.element),
                        position: pair.offset,
                        total: draft.steps.count,
                        onReorder: { draggedID in
                            draft.dropTargetID = nil
                            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                                draft.move(draggedID, before: pair.element.id)
                            }
                        },
                        onMoveUp: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                draft.moveUp(pair.element.id)
                            }
                        },
                        onMoveDown: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                draft.moveDown(pair.element.id)
                            }
                        },
                        onDuplicate: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                draft.duplicate(pair.element.id)
                            }
                        },
                        onRemove: {
                            withAnimation(.easeInOut(duration: 0.18)) {
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
                            .opacity(0.4)
                            .padding(.leading, 60)
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.bottom, 16)
        }
    }

    private var recordButton: some View {
        Button(action: onToggleRecord) {
            Label(
                recorder.isRecording ? "Parar gravação" : "Gravar ação",
                systemImage: recorder.isRecording ? "stop.circle.fill" : "record.circle"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(recorder.isRecording ? .red : .primary)
        }
        .buttonStyle(.borderless)
        .help(recorder.isRecording
              ? "Para gravar e anexa as ações capturadas ao fim da lista"
              : "Grava um trecho e anexa ao fim da lista de ações")
    }

    private var addMenu: some View {
        Menu {
            ForEach(MacroStepKind.allCases) { kind in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        draft.add(kind)
                    }
                } label: {
                    Label(kind.title, systemImage: kind.icon)
                }
            }
        } label: {
            Label("Adicionar ação", systemImage: "plus")
                .font(.caption.weight(.medium))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Nenhuma ação ainda")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Use \u{201C}Adicionar ação\u{201D} para montar a sequência")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if executor.isRunning {
                Button {
                    onStopRun()
                } label: {
                    Label("Parar", systemImage: "stop.fill")
                }
                .tint(.red)
            } else {
                Button {
                    onRun(draft.makeMacro())
                } label: {
                    Label("Executar", systemImage: "play.fill")
                }
                .tint(.green)
                .disabled(draft.steps.isEmpty)
            }

            Spacer()

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
        .padding(.vertical, 10)
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
