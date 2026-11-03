import SwiftUI

struct MacroListView: View {
    let store: MacroStore
    let executor: MacroExecutor
    let onPlay: (Macro) -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.macros.isEmpty {
                emptyState
            } else {
                if !store.recentlyUsed.isEmpty {
                    recentSection
                    Divider()
                }
                allSection
            }
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Usados Recentemente")
            ForEach(store.recentlyUsed) { macro in
                macroRow(macro)
            }
        }
        .padding(.horizontal, 12)
    }

    private var allSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Todas as Macros")
            ForEach(store.macros) { macro in
                macroRow(macro)
            }
        }
        .padding(.horizontal, 12)
    }

    private func macroRow(_ macro: Macro) -> some View {
        MacroRowView(
            macro: macro,
            isRunning: isRunningMacro(macro),
            onPlay: { onPlay(macro) },
            onStop: { onStop() },
            onDelete: { store.delete(macro.id) }
        )
    }

    private func isRunningMacro(_ macro: Macro) -> Bool {
        executor.isRunning
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }
}
