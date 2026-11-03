import SwiftUI

struct MacroRowView: View {
    let macro: Macro
    let isRunning: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: macro.iconName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 9)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(macro.name)
                    .font(.system(.body, weight: .semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !macro.details.isEmpty {
                        Text(macro.details)
                            .lineLimit(1)
                    }

                    Text("\(macro.steps.count) ações")
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if macro.executionCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(macro.executionCount)×")
                        .font(.system(.caption, design: .monospaced, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Text(macro.lastUsedLabel)
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }

            HStack(spacing: 2) {
                if isRunning {
                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconActionButtonStyle(tint: .red))
                    .help("Parar execução")
                    .transition(.scale.combined(with: .opacity))

                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                } else {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                            .frame(width: 28, height: 28)
                            .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconActionButtonStyle(tint: .green))
                    .help("Executar macro")
                    .transition(.scale.combined(with: .opacity))

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                            .frame(width: 28, height: 28)
                            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconActionButtonStyle(tint: .orange))
                    .help("Editar macro")
                    .transition(.scale.combined(with: .opacity))

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(IconActionButtonStyle(tint: .red))
                    .help("Apagar macro")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isRunning)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onPlay()
            } label: {
                Label("Executar", systemImage: "play")
            }
            Button {
                onEdit()
            } label: {
                Label("Editar", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Apagar", systemImage: "trash")
            }
        }
    }
}
