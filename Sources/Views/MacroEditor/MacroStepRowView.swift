import SwiftUI

struct MacroStepRowView: View {
    let step: Binding<MacroStep>
    let position: Int
    let total: Int
    let isSelected: Bool
    var isTesting: Bool = false
    var testDisabled: Bool = false
    let onTest: () -> Void
    let onReorder: (UUID) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDuplicate: () -> Void
    let onRemove: () -> Void
    var isDropTarget: Bool = false
    var onDropTargetChange: (Bool) -> Void = { _ in }

    private var kind: MacroStepKind { step.wrappedValue.kind }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 28)
                .contentShape(Rectangle())
                .help("Arraste para reordenar")
                .draggable(step.wrappedValue.id.uuidString) {
                    HStack(spacing: 8) {
                        Image(systemName: kind.icon)
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(kind.tint, in: RoundedRectangle(cornerRadius: 6))
                        Text("\(position + 1). \(kind.title)")
                            .font(.subheadline)
                    }
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

            Image(systemName: kind.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(kind.tint, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 5) {
                Text("\(position + 1). \(kind.title)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                editor
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                if isTesting {
                    ProgressView().controlSize(.small)
                } else {
                    Button(action: onTest) {
                        Image(systemName: "play.fill")
                    }
                    .foregroundStyle(.green)
                    .disabled(testDisabled)
                    .help("Testar esta ação")
                }

                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .disabled(position == 0)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .disabled(position == total - 1)

                Button(action: onDuplicate) {
                    Image(systemName: "doc.on.doc")
                }
                .foregroundStyle(.secondary)
                .help("Duplicar ação")

                Button(action: onRemove) {
                    Image(systemName: "trash")
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(IconActionButtonStyle())
            .font(.system(size: 12, weight: .medium))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            isSelected
                ? AnyShapeStyle(Color.accentColor.opacity(0.08))
                : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.accentColor)
                .frame(height: 3)
                .opacity(isDropTarget ? 1 : 0)
                .offset(y: -1)
        }
        .animation(.easeInOut(duration: 0.15), value: isDropTarget)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            onReorder(id)
            return true
        } isTargeted: { onDropTargetChange($0) }
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
        } else {
            textEditor
        }
    }

    private var delayEditor: some View {
        HStack(spacing: 8) {
            TextField(
                "ms",
                value: Binding(
                    get: { Int((step.wrappedValue.delay * 1000).rounded()) },
                    set: { step.wrappedValue.delay = Double(max($0, 0)) / 1000 }
                ),
                format: .number.grouping(.never)
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 90)
            .multilineTextAlignment(.trailing)

            Text("ms")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach([100, 500, 1000, 2000], id: \.self) { ms in
                Button("\(ms)") { step.wrappedValue.delay = Double(ms) / 1000 }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
    }

    private var textEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            AutoFocusTextField(
                stepID: step.wrappedValue.id,
                placeholder: kind.placeholder,
                text: step.value
            )
            .frame(height: 24)

            Picker("Modo", selection: step.textMode) {
                ForEach(TextInputMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 260)
        }
    }

    private var shortcutEditor: some View {
        let parsed = ShortcutKeyMap.parse(step.wrappedValue.value)
        let flags = parsed?.flags ?? []
        let keyName = parsed.flatMap { ShortcutKeyMap.displayName(for: $0.keyCode) } ?? ""

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    ShortcutCapturePicker.pickShortcut { shortcut in
                        DispatchQueue.main.async { step.wrappedValue.value = shortcut }
                    }
                } label: {
                    Label(
                        step.wrappedValue.value.isEmpty ? "Capturar atalho" : "Recapturar",
                        systemImage: "keyboard"
                    )
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if !step.wrappedValue.value.isEmpty {
                    Text(step.wrappedValue.value)
                        .font(.callout)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                }
            }

            HStack(spacing: 6) {
                ForEach(shortcutModifiers, id: \.symbol) { modifier in
                    Toggle(modifier.symbol, isOn: Binding(
                        get: { flags.contains(modifier.flag) },
                        set: { isOn in
                            var newFlags = flags
                            if isOn { newFlags.insert(modifier.flag) } else { newFlags.remove(modifier.flag) }
                            updateShortcut(flags: newFlags, keyName: keyName)
                        }
                    ))
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .help(modifier.name)
                }

                Picker("Tecla", selection: Binding(
                    get: { keyName },
                    set: { updateShortcut(flags: flags, keyName: $0) }
                )) {
                    if keyName.isEmpty { Text("Tecla…").tag("") }
                    ForEach(ShortcutKeyMap.allKeyNames, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .frame(width: 110)
                .controlSize(.small)
            }
        }
    }

    private var shortcutModifiers: [(symbol: String, name: String, flag: CGEventFlags)] {
        [("⌃", "Control", .maskControl), ("⌥", "Option", .maskAlternate), ("⇧", "Shift", .maskShift), ("⌘", "Command", .maskCommand)]
    }

    private func updateShortcut(flags: CGEventFlags, keyName: String) {
        step.wrappedValue.value = ShortcutKeyMap.modifierSymbols(for: flags) + keyName
    }

    private var clickEditor: some View {
        HStack(spacing: 8) {
            if step.wrappedValue.hasCoordinates {
                Text("x: \(Int(step.wrappedValue.clickX)), y: \(Int(step.wrappedValue.clickY))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
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
                    step.wrappedValue.hasCoordinates ? "Recapturar" : "Capturar posição",
                    systemImage: "scope"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var dragEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            if step.wrappedValue.hasDragCoordinates {
                HStack(spacing: 12) {
                    Label("A: (\(Int(step.wrappedValue.dragStartX)), \(Int(step.wrappedValue.dragStartY)))", systemImage: "a.circle.fill")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Label("B: (\(Int(step.wrappedValue.dragEndX)), \(Int(step.wrappedValue.dragEndY)))", systemImage: "b.circle.fill")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
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
                    step.wrappedValue.hasDragCoordinates ? "Recapturar" : "Clique e arraste na tela",
                    systemImage: "arrow.up.and.down.and.arrow.left.and.right"
                )
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var scrollEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Picker("Direção", selection: Binding(
                    get: { step.wrappedValue.scrollDirection },
                    set: { step.wrappedValue.scrollDirection = $0; refreshScrollLabel() }
                )) {
                    ForEach(ScrollDirection.allCases) { dir in
                        Label(dir.title, systemImage: dir.icon).tag(dir)
                    }
                }
                .labelsHidden()
                .frame(width: 100)

                numberField(
                    value: Binding(
                        get: { Int(step.wrappedValue.scrollAmount) },
                        set: { step.wrappedValue.scrollAmount = Double(min(max($0, 1), 100_000)); refreshScrollLabel() }
                    ),
                    width: 70
                )

                Picker("Unidade", selection: Binding(
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
                .frame(width: 90)

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
                    Label("Gravar", systemImage: "record.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                Toggle("Mover mouse antes", isOn: step.scrollMovesMouse)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                if step.wrappedValue.scrollMovesMouse {
                    if step.wrappedValue.hasScrollPosition {
                        Text("x: \(Int(step.wrappedValue.scrollX)), y: \(Int(step.wrappedValue.scrollY))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        ScreenCoordinatePicker.pickPoint { point in
                            DispatchQueue.main.async {
                                step.wrappedValue.scrollX = point.x
                                step.wrappedValue.scrollY = point.y
                            }
                        }
                    } label: {
                        Label(step.wrappedValue.hasScrollPosition ? "Recapturar" : "Capturar posição", systemImage: "scope")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func numberField(value: Binding<Int>, width: CGFloat) -> some View {
        TextField("0", value: value, format: .number.grouping(.never))
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: width)
    }

    private func refreshScrollLabel() {
        step.wrappedValue.value = step.wrappedValue.scrollSummary
    }

    private var windowEditor: some View {
        let options = WindowCatalog.titles(including: step.wrappedValue.value)
        return Picker(
            "Janela",
            selection: step.value
        ) {
            if step.wrappedValue.value.isEmpty {
                Text("Selecionar janela…").tag("")
            }
            ForEach(options, id: \.self) { Text($0).tag($0) }
        }
        .labelsHidden()
        .frame(maxWidth: 280)
    }
}
