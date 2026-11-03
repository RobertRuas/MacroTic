import SwiftUI

struct MacroRowView: View {
    let macro: Macro
    let isRunning: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: macro.iconName)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(macro.name)
                    .fontWeight(.medium)
                if !macro.details.isEmpty {
                    Text(macro.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                if isRunning {
                    Button {
                        onStop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(width: 26, height: 26)
                            .background(.red.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.borderless)
                    .help("Parar execução")
                    .transition(.scale.combined(with: .opacity))

                    ProgressView()
                        .controlSize(.small)
                        .transition(.opacity)
                } else {
                    Button {
                        onPlay()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .frame(width: 26, height: 26)
                            .background(.green.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.borderless)
                    .help("Executar macro")
                    .transition(.scale.combined(with: .opacity))

                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .frame(width: 26, height: 26)
                            .background(.orange.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.borderless)
                    .help("Editar macro")
                    .transition(.scale.combined(with: .opacity))

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(width: 26, height: 26)
                            .background(.red.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.borderless)
                    .help("Apagar macro")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isRunning)

            VStack(alignment: .trailing, spacing: 2) {
                Text(macro.createdAtLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if macro.executionCount > 0 {
                    Text("\(macro.executionCount)x · \(macro.lastUsedLabel)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Text("\(macro.steps.count) ações")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
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
