import SwiftUI

enum StepRowLayout {
    static let selector: CGFloat = 26
    static let handle: CGFloat = 16
    static let index: CGFloat = 22
    static let icon: CGFloat = 24
    static let title: CGFloat = 116
    static let spacing: CGFloat = 8
}

struct MacroStepRowView: View {
    let step: Binding<MacroStep>
    let position: Int
    let total: Int
    var isSelected: Bool = false
    var debugMode: Bool = false
    var locked: Bool = false
    var onSelect: () -> Void = {}
    var onRunFrom: () -> Void = {}
    let onReorder: (UUID) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    let onRemove: () -> Void
    var isDropTarget: Bool = false
    var onDropTargetChange: (Bool) -> Void = { _ in }

    private var kind: MacroStepKind { step.wrappedValue.kind }

    var body: some View {
        HStack(spacing: StepRowLayout.spacing) {
            selector

            dragHandle
                .disabled(locked)

            Text("\(position + 1)")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: StepRowLayout.index, alignment: .trailing)

            Image(systemName: kind.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: StepRowLayout.icon, height: StepRowLayout.icon)
                .background(kind.tint, in: RoundedRectangle(cornerRadius: 6))

            Text(kind.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: StepRowLayout.title, alignment: .leading)

            editor
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(locked)

            if let issue = step.wrappedValue.configurationIssue {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .help("Passo incompleto: \(issue). Será interrompido ao executar.")
            }

            rowActions
                .disabled(locked)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 38)
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.accentColor)
                .frame(height: 2.5)
                .opacity(isDropTarget ? 1 : 0)
                .padding(.horizontal, 12)
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .dropDestination(for: String.self) { items, _ in
            guard !locked, let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            onReorder(id)
            return true
        } isTargeted: { targeted in
            if !locked { onDropTargetChange(targeted) }
        }
        .overlay(alignment: .trailing) {
            if debugMode && step.wrappedValue.supportsDebugPreview {
                Image(systemName: "eye")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.teal)
                    .padding(.trailing, 2)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            guard debugMode else { return }
            if hovering && step.wrappedValue.supportsDebugPreview {
                DebugPreviewOverlay.shared.show(for: step.wrappedValue)
            } else {
                DebugPreviewOverlay.shared.hide()
            }
        }
    }

    private var selector: some View {
        Button(action: onSelect) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                .frame(width: StepRowLayout.selector, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Selecionar para mover (⌘↑/⌘↓) ou excluir")
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(width: StepRowLayout.handle, height: 28)
            .contentShape(Rectangle())
            .help("Arraste para reordenar")
            .draggable(step.wrappedValue.id.uuidString) {
                HStack(spacing: 6) {
                    Image(systemName: kind.icon)
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(kind.tint, in: RoundedRectangle(cornerRadius: 6))
                    Text(kind.title)
                        .font(.caption.weight(.medium))
                }
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
    }

    private var rowActions: some View {
        HStack(spacing: 2) {
            Button(action: onDuplicate) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IconActionButtonStyle())
            .help("Duplicar ação")

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IconActionButtonStyle(tint: .red))
            .help("Remover ação")

            Menu {
                Button {
                    onRunFrom()
                } label: {
                    Label("Executar a partir daqui", systemImage: "play.fill")
                }

                Divider()

                Button(action: onMoveUp) {
                    Label("Mover para cima", systemImage: "chevron.up")
                }
                .disabled(position == 0)

                Button(action: onMoveDown) {
                    Label("Mover para baixo", systemImage: "chevron.down")
                }
                .disabled(position == total - 1)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24, height: 24)
            .help("Mais opções")
        }
    }

    @ViewBuilder
    private var editor: some View {
        if kind.usesDelay {
            delayEditor
        } else if kind.usesShortcutRecorder {
            shortcutEditor
        } else if kind.usesCoordinates {
            clickEditor
        } else if kind.usesDragCoordinates {
            dragEditor
        } else if kind.usesScroll {
            scrollEditor
        } else if kind.usesWindowPicker {
            windowEditor
        } else if kind.usesRandomNumber {
            randomNumberEditor
        } else {
            textEditor
        }
    }

    private var randomNumberEditor: some View {
        HStack(spacing: 6) {
            Text("Entre")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "1",
                value: Binding(
                    get: { step.wrappedValue.randomMin },
                    set: { step.wrappedValue.randomMin = $0 }
                ),
                format: .number.grouping(.never)
            )
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 70)
            .controlSize(.small)

            Text("e")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "100",
                value: Binding(
                    get: { step.wrappedValue.randomMax },
                    set: { step.wrappedValue.randomMax = $0 }
                ),
                format: .number.grouping(.never)
            )
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 70)
            .controlSize(.small)

            Picker("", selection: step.textMode) {
                ForEach(TextInputMode.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 130)
            .controlSize(.small)

            Spacer(minLength: 0)
        }
    }

    private var delayEditor: some View {
        HStack(spacing: 6) {
            TextField(
                "500",
                value: Binding(
                    get: { Int((step.wrappedValue.delay * 1000).rounded()) },
                    set: { step.wrappedValue.delay = Double(max($0, 0)) / 1000 }
                ),
                format: .number.grouping(.never)
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 72)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .controlSize(.small)

            Text("ms")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
    }

    private var textEditor: some View {
        HStack(spacing: 8) {
            AutoFocusTextField(
                stepID: step.wrappedValue.id,
                placeholder: kind.placeholder,
                text: step.value
            )
            .frame(height: 22)
            .frame(maxWidth: .infinity)

            Picker("", selection: step.textMode) {
                ForEach(TextInputMode.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 130)
            .controlSize(.small)
        }
    }

    private var shortcutEditor: some View {
        HStack(spacing: 8) {
            if step.wrappedValue.value.isEmpty {
                Text("Nenhum atalho")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(step.wrappedValue.value)
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            }

            Button {
                ShortcutCapturePicker.pickShortcut { shortcut in
                    DispatchQueue.main.async { step.wrappedValue.value = shortcut }
                }
            } label: {
                Label(
                    step.wrappedValue.value.isEmpty ? "Capturar" : "Recapturar",
                    systemImage: "record.circle"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer(minLength: 0)
        }
    }

    private var clickEditor: some View {
        HStack(spacing: 8) {
            if step.wrappedValue.hasCoordinates {
                Text("x: \(Int(step.wrappedValue.clickX))  y: \(Int(step.wrappedValue.clickY))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            } else {
                Text("Sem posição")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            Button {
                ScreenCoordinatePicker.pickPoint { point in
                    DispatchQueue.main.async {
                        var s = step.wrappedValue
                        s.clickX = point.x
                        s.clickY = point.y
                        s.value = "(\(Int(point.x)), \(Int(point.y)))"
                        step.wrappedValue = s
                    }
                }
            } label: {
                Label(
                    step.wrappedValue.hasCoordinates ? "Recapturar" : "Capturar",
                    systemImage: "scope"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer(minLength: 0)
        }
    }

    private var dragEditor: some View {
        HStack(spacing: 6) {
            if step.wrappedValue.hasDragCoordinates {
                Text("(\(Int(step.wrappedValue.dragStartX)), \(Int(step.wrappedValue.dragStartY)))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("(\(Int(step.wrappedValue.dragEndX)), \(Int(step.wrappedValue.dragEndY)))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else {
                Text("Sem trajeto")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            Button {
                ScreenCoordinatePicker.pickDrag { start, end in
                    DispatchQueue.main.async {
                        var s = step.wrappedValue
                        s.dragStartX = start.x
                        s.dragStartY = start.y
                        s.dragEndX = end.x
                        s.dragEndY = end.y
                        s.value = "(\(Int(start.x)),\(Int(start.y))) → (\(Int(end.x)),\(Int(end.y)))"
                        step.wrappedValue = s
                    }
                }
            } label: {
                Label(
                    step.wrappedValue.hasDragCoordinates ? "Recapturar" : "Capturar",
                    systemImage: "arrow.up.and.down.and.arrow.left.and.right"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer(minLength: 0)
        }
    }

    private var scrollEditor: some View {
        HStack(spacing: 6) {
            Picker("", selection: Binding(
                get: { step.wrappedValue.scrollDirection },
                set: { step.wrappedValue.scrollDirection = $0; refreshScrollLabel() }
            )) {
                ForEach(ScrollDirection.allCases) { dir in
                    Label(dir.title, systemImage: dir.icon).tag(dir)
                }
            }
            .labelsHidden()
            .frame(width: 88)
            .controlSize(.small)

            TextField(
                "3",
                value: Binding(
                    get: { Int(step.wrappedValue.scrollAmount) },
                    set: { step.wrappedValue.scrollAmount = Double(min(max($0, 1), 100_000)); refreshScrollLabel() }
                ),
                format: .number.grouping(.never)
            )
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: 56)
            .controlSize(.small)

            Picker("", selection: Binding(
                get: { step.wrappedValue.scrollUnit },
                set: {
                    let previous = step.wrappedValue.scrollUnit
                    step.wrappedValue.scrollUnit = $0
                    if previous != $0 {
                        step.wrappedValue.scrollAmount = $0 == .pixels
                            ? max(step.wrappedValue.scrollAmount * 100, 300)
                            : min(max((step.wrappedValue.scrollAmount / 100).rounded(), 1), 100)
                    }
                    refreshScrollLabel()
                }
            )) {
                ForEach(ScrollUnit.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .frame(width: 80)
            .controlSize(.small)

            Button {
                ScrollCapturePicker.pickScroll { result in
                    DispatchQueue.main.async {
                        var s = step.wrappedValue
                        s.scrollDirection = result.direction
                        s.scrollAmount = result.amount
                        s.scrollUnit = .lines
                        s.scrollMovesMouse = true
                        s.scrollX = result.point.x
                        s.scrollY = result.point.y
                        s.value = s.scrollSummary
                        step.wrappedValue = s
                    }
                }
            } label: {
                Image(systemName: "record.circle")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Gravar scroll")

            Toggle(isOn: step.scrollMovesMouse) {
                Image(systemName: "cursorarrow")
                    .font(.caption)
            }
            .toggleStyle(.button)
            .controlSize(.small)
            .help("Mover mouse antes do scroll")

            if step.wrappedValue.scrollMovesMouse {
                Button {
                    ScreenCoordinatePicker.pickPoint { point in
                        DispatchQueue.main.async {
                            step.wrappedValue.scrollX = point.x
                            step.wrappedValue.scrollY = point.y
                        }
                    }
                } label: {
                    Image(systemName: "scope")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(step.wrappedValue.hasScrollPosition
                      ? "x: \(Int(step.wrappedValue.scrollX)), y: \(Int(step.wrappedValue.scrollY))"
                      : "Capturar posição do mouse")
            }

            Spacer(minLength: 0)
        }
    }

    private var windowEditor: some View {
        let options = WindowCatalog.titles(including: step.wrappedValue.value)
        return HStack {
            Picker("", selection: step.value) {
                if step.wrappedValue.value.isEmpty {
                    Text("Selecionar janela…").tag("")
                }
                ForEach(options, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(maxWidth: 300)

            Spacer(minLength: 0)
        }
    }

    private func refreshScrollLabel() {
        step.wrappedValue.value = step.wrappedValue.scrollSummary
    }
}
