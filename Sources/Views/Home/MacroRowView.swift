import SwiftUI

struct MacroRowView: View {
    let macro: Macro
    let isRunning: Bool
    let onPlay: () -> Void
    let onStop: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: macro.iconName)
                .font(.title2)
                .foregroundStyle(.blue)

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

            if isRunning {
                Button {
                    onStop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                        .background(.red.opacity(0.1), in: Circle())
                }
                .buttonStyle(.borderless)
                .help("Parar execução")

                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    onPlay()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .frame(width: 28, height: 28)
                        .background(.green.opacity(0.1), in: Circle())
                }
                .buttonStyle(.borderless)
                .help("Executar macro")
            }

            VStack(alignment: .trailing, spacing: 2) {
                if macro.executionCount > 0 {
                    Text("\(macro.executionCount)x")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(macro.lastUsedLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text("\(macro.steps.count) ações")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button {
                onPlay()
            } label: {
                Label("Executar", systemImage: "play")
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
