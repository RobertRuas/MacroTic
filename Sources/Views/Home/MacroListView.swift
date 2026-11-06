import SwiftUI

struct MacroListView: View {
    let store: MacroStore
    let executor: MacroExecutor
    let onPlay: (Macro) -> Void
    let onStop: () -> Void
    let onEdit: (Macro) -> Void
    let onDelete: (UUID) -> Void
    var onToggleFavorite: (UUID) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.macros.isEmpty {
                emptyState
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                allSection
            }
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.3), value: store.macros.count)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.quaternary)
            Text("Nenhuma macro criada")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Crie sua primeira macro para começar a automatizar.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var allSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Macros", icon: "list.bullet")
            ForEach(store.sorted) { macro in
                macroRow(macro)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .padding(.horizontal, 8)
        .animation(.easeInOut(duration: 0.25), value: store.sorted.map(\.id))
    }

    private func macroRow(_ macro: Macro) -> some View {
        MacroRowView(
            macro: macro,
            isRunning: executor.isRunning && executor.runningMacroID == macro.id,
            onPlay: { onPlay(macro) },
            onStop: { onStop() },
            onEdit: { onEdit(macro) },
            onDelete: { onDelete(macro.id) },
            onToggleFavorite: { onToggleFavorite(macro.id) }
        )
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .padding(.leading, 10)
    }
}
