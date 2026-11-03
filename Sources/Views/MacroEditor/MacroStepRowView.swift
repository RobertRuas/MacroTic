import SwiftUI

struct MacroStepRowView: View {
    let step: Binding<MacroStep>
    let position: Int
    let total: Int
    let isSelected: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void
    let onSelect: () -> Void

    private var kind: MacroStepKind { step.wrappedValue.kind }

    var body: some View {
        HStack(spacing: 12) {
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
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                }
                .disabled(position == 0)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                }
                .disabled(position == total - 1)

                Button(action: onRemove) {
                    Image(systemName: "trash")
                }
                .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
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
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
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
            TextField(kind.placeholder, text: step.value)
                .textFieldStyle(.roundedBorder)
                .font(.callout)
        }
    }

    private var delayEditor: some View {
        HStack(spacing: 10) {
            Slider(value: step.delay, in: 0.1...10, step: 0.1)
                .frame(maxWidth: 180)
            Text(String(format: "%.1f s", step.wrappedValue.delay))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var shortcutEditor: some View {
        HStack(spacing: 8) {
            KeyShortcutRecorder(
                value: step.value,
                isRecording: Binding(
                    get: { false },
                    set: { _ in }
                )
            )
            .frame(height: 26)

            if !step.wrappedValue.value.isEmpty {
                Text(step.wrappedValue.value)
                    .font(.callout)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            }
        }
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
        HStack(spacing: 10) {
            Picker(
                "Direção",
                selection: Binding(
                    get: { step.wrappedValue.scrollDirection },
                    set: { newDir in
                        var s = step.wrappedValue
                        s.scrollDirection = newDir
                        s.value = "\(newDir.title) ×\(Int(s.scrollAmount))"
                        step.wrappedValue = s
                    }
                )
            ) {
                ForEach(ScrollDirection.allCases) { dir in
                    Label(dir.title, systemImage: dir.icon).tag(dir)
                }
            }
            .labelsHidden()
            .frame(width: 100)

            Slider(
                value: Binding(
                    get: { step.wrappedValue.scrollAmount },
                    set: { newAmount in
                        var s = step.wrappedValue
                        s.scrollAmount = newAmount
                        s.value = "\(s.scrollDirection.title) ×\(Int(newAmount))"
                        step.wrappedValue = s
                    }
                ),
                in: 1...20,
                step: 1
            )
            .frame(maxWidth: 100)

            Text("×\(Int(step.wrappedValue.scrollAmount))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var windowEditor: some View {
        HStack(spacing: 8) {
            if !step.wrappedValue.value.isEmpty {
                Text(step.wrappedValue.value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            WindowPickerButton(selectedValue: step.value)
        }
    }
}

private struct WindowPickerButton: View {
    let selectedValue: Binding<String>

    var body: some View {
        Button {
            showWindowPicker()
        } label: {
            Label(
                selectedValue.wrappedValue.isEmpty ? "Selecionar janela" : "Alterar",
                systemImage: "macwindow"
            )
            .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func showWindowPicker() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 340),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Selecionar Janela"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.center()

        let pickerView = WindowPickerView(
            selectedValue: selectedValue,
            onDismiss: { panel.orderOut(nil) }
        )
        panel.contentView = NSHostingView(rootView: pickerView)
        panel.makeKeyAndOrderFront(nil)
    }
}
