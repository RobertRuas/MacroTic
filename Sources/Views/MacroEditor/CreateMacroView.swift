import SwiftUI

struct CreateMacroView: View {
    let draft: MacroDraft
    let executor: MacroExecutor
    let recorder: ActionRecorder
    let onRun: (Macro) -> Void
    var onRunFrom: (Int) -> Void = { _ in }
    var onRunSelected: ([MacroStep]) -> Void = { _ in }
    let onStopRun: () -> Void
    let onToggleRecord: () -> Void
    var isEditing: Bool = false
    var existingNames: [String] = []
    var editingMacroID: UUID? = nil
    let onCancel: () -> Void
    var onClose: () -> Void = {}
    let onSave: (Macro) -> Void

    private var isDuplicateName: Bool {
        let trimmed = draft.trimmedName.lowercased()
        guard !trimmed.isEmpty else { return false }
        return existingNames.contains { $0.lowercased() == trimmed }
    }

    var body: some View {
        VStack(spacing: 0) {
            identityHeader
                .disabled(editingLocked)
            executionBar
                .disabled(editingLocked)
            if editingLocked {
                lockedBanner
            }
            Divider()
            stepsSection
            Divider()
            footer
        }
        .frame(minWidth: 620, idealWidth: 680, maxWidth: .infinity,
               minHeight: 480, idealHeight: 540, maxHeight: .infinity)
        .background(.background)
        .background(selectionShortcuts)
        .onDisappear { DebugPreviewOverlay.shared.hide() }
    }

    private var selectionShortcuts: some View {
        VStack {
            Button("") {
                withAnimation(.easeInOut(duration: 0.2)) { draft.moveSelectedUp() }
            }
            .keyboardShortcut(.upArrow, modifiers: .command)

            Button("") {
                withAnimation(.easeInOut(duration: 0.2)) { draft.moveSelectedDown() }
            }
            .keyboardShortcut(.downArrow, modifiers: .command)

            Button("") {
                withAnimation(.easeInOut(duration: 0.18)) { draft.removeSelected() }
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .disabled(draft.selectedStepIDs.isEmpty || editingLocked)
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
                headerToggle(
                    icon: editingLocked ? "lock.fill" : "lock.open",
                    active: editingLocked,
                    tint: .orange,
                    help: draft.isLocked
                        ? "Edição bloqueada (segurança) — clique para desbloquear"
                        : "Bloquear edição das ações (trava automaticamente durante a execução)"
                ) {
                    draft.isLocked.toggle()
                }
                .disabled(executor.isRunning)
                headerToggle(
                    icon: "square.grid.2x2",
                    active: draft.showQuickBar,
                    help: "Mostrar/ocultar a barra de ações"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { draft.showQuickBar.toggle() }
                }
                headerToggle(
                    icon: "ladybug",
                    active: draft.debugMode,
                    help: "Modo depuração: passe o mouse sobre uma ação de clique, arrasto, scroll ou janela para ver uma prévia na tela"
                ) {
                    draft.debugMode.toggle()
                    if !draft.debugMode { DebugPreviewOverlay.shared.hide() }
                }
                recordButton
                    .disabled(editingLocked)
                addMenu
                    .disabled(editingLocked)
                ioMenu
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if draft.showQuickBar {
                quickBar
                    .disabled(editingLocked)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if !draft.selectedStepIDs.isEmpty {
                selectionBar
            }

            Divider()

            if draft.steps.isEmpty {
                emptyState
            } else {
                tableHeader
                Divider()
                stepList
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func headerToggle(icon: String, active: Bool, tint: Color = .accentColor, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
                .frame(width: 26, height: 22)
                .background(active ? tint.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    /// Editing is blocked either when the user locked it, or automatically while the macro runs.
    private var editingLocked: Bool { draft.isLocked || executor.isRunning }

    private var lockedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.orange)
            Text(executor.isRunning && !draft.isLocked
                 ? "Edição bloqueada durante a execução"
                 : "Edição bloqueada por segurança")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            if !executor.isRunning {
                Button("Desbloquear") { draft.isLocked = false }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.orange.opacity(0.10))
    }

    private var quickBar: some View {
        HStack(spacing: 6) {
            ForEach(MacroStepKind.allCases) { kind in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { draft.add(kind) }
                } label: {
                    Image(systemName: kind.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 26)
                        .background(kind.tint, in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(kind.title)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.18))
    }

    private var selectionBar: some View {
        HStack(spacing: 10) {
            Text("\(draft.selectedStepIDs.count) selecionada(s)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Label("⌘↑/⌘↓ mover · ⌘⌫ excluir", systemImage: "keyboard")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button {
                onRunSelected(draft.selectedStepsInOrder())
            } label: {
                Label("Executar", systemImage: "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .tint(.green)
            .disabled(executor.isRunning)
            .help("Executar apenas as ações selecionadas, na ordem")

            Button {
                withAnimation(.easeInOut(duration: 0.18)) { draft.removeSelected() }
            } label: {
                Label("Excluir", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .tint(.red)
            .disabled(editingLocked)

            Button("Limpar") {
                draft.clearSelection()
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08))
    }

    private var tableHeader: some View {
        HStack(spacing: StepRowLayout.spacing) {
            Button(action: toggleSelectAll) {
                Image(systemName: draft.allSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundStyle(draft.allSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                    .frame(width: StepRowLayout.selector, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Selecionar todas")

            Color.clear.frame(width: StepRowLayout.handle, height: 1)

            Text("#")
                .frame(width: StepRowLayout.index, alignment: .trailing)

            Color.clear.frame(width: StepRowLayout.icon, height: 1)

            Text("Ação")
                .frame(width: StepRowLayout.title, alignment: .leading)

            Text("Configuração")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("")
                .frame(width: 78, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.tertiary)
        .textCase(.uppercase)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.25))
    }

    private func toggleSelectAll() {
        withAnimation(.easeInOut(duration: 0.15)) {
            if draft.allSelected { draft.clearSelection() } else { draft.selectAll() }
        }
    }

    private var stepList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(draft.steps.enumerated()), id: \.element.id) { pair in
                    MacroStepRowView(
                        step: stepBinding(pair.element),
                        position: pair.offset,
                        total: draft.steps.count,
                        isSelected: draft.selectedStepIDs.contains(pair.element.id),
                        debugMode: draft.debugMode,
                        locked: editingLocked,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                draft.toggleSelection(pair.element.id)
                            }
                        },
                        onRunFrom: { onRunFrom(pair.offset) },
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
                            .opacity(0.3)
                    }
                }
            }
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

    private var ioMenu: some View {
        Menu {
            Button {
                MacroIO.importMacro { macro in
                    withAnimation(.easeInOut(duration: 0.22)) { draft.loadFrom(macro) }
                }
            } label: {
                Label("Importar macro…", systemImage: "square.and.arrow.down")
            }
            .disabled(editingLocked)

            Button {
                MacroIO.export(draft.makeMacro())
            } label: {
                Label("Exportar macro…", systemImage: "square.and.arrow.up")
            }
            .disabled(draft.steps.isEmpty)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Importar ou exportar esta macro")
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
                .keyboardShortcut("r", modifiers: .command)
                .help("Executar a macro (⌘R)")
            }

            Spacer()

            Button("Cancelar", action: onCancel)
                .keyboardShortcut(.cancelAction)
                .help("Descartar e fechar")

            Button("Salvar Alterações") {
                onSave(draft.makeMacro())
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!draft.isValid || isDuplicateName)
            .help("Salvar sem fechar (⌘S)")

            Button("Fechar", action: onClose)
                .keyboardShortcut("w", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .help("Fechar o editor (⌘W)")
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
