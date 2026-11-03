import SwiftUI

struct CreateMacroView: View {
    let draft: MacroDraft
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
                VStack(alignment: .leading, spacing: 20) {
                    identitySection
                    stepsSection
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 580, height: 520)
        .background(keyboardShortcutHandlers)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isEditing ? "Editar Macro" : "Nova Macro")
                .font(.title2)
                .fontWeight(.semibold)
            Text(isEditing ? "Altere o nome ou a sequência de ações." : "Dê um nome e monte a sequência de ações.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Identificação")
            VStack(spacing: 0) {
                HStack {
                    TextField(
                        "Nome da macro",
                        text: Binding(get: { draft.name }, set: { draft.name = $0 })
                    )
                    .textFieldStyle(.plain)
                    .padding(.vertical, 10)

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
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 14)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Ações")
                Spacer()
                shortcutsHint
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
                            isSelected: draft.selectedStepID == pair.element.id,
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
                            onRemove: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    draft.remove(pair.element.id)
                                }
                            },
                            onSelect: { draft.selectedStepID = pair.element.id }
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

    private var shortcutsHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "command")
            Image(systemName: "arrow.up.arrow.down")
        }
        .font(.system(size: 9))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
        .help("⌘↑ Mover acima · ⌘↓ Mover abaixo")
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
            Button("Cancelar", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button(isEditing ? "Salvar Alterações" : "Salvar") {
                onSave(draft.makeMacro())
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!draft.isValid || isDuplicateName)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var keyboardShortcutHandlers: some View {
        Group {
            Button("") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    draft.moveSelectedUp()
                }
            }
            .keyboardShortcut(.upArrow, modifiers: .command)
            .hidden()

            Button("") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    draft.moveSelectedDown()
                }
            }
            .keyboardShortcut(.downArrow, modifiers: .command)
            .hidden()
        }
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
