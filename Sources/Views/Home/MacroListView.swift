import SwiftUI

struct MacroListView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            recentSection
            Divider()
            allSection
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Usados Recentemente")
            MacroRowView(
                name: "Login Automático",
                description: "Preenche email e senha no portal",
                lastUsed: "Há 2 min",
                executionCount: 47
            )
            MacroRowView(
                name: "Exportar Relatório",
                description: "Navega até relatórios e exporta PDF",
                lastUsed: "Há 1 hora",
                executionCount: 23
            )
            MacroRowView(
                name: "Fechar Popups",
                description: "Fecha todas as janelas de notificação",
                lastUsed: "Há 3 horas",
                executionCount: 112
            )
        }
        .padding(.horizontal, 12)
    }

    private var allSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Todas as Macros")
            MacroRowView(
                name: "Login Automático",
                description: "Preenche email e senha no portal",
                lastUsed: "Há 2 min",
                executionCount: 47
            )
            MacroRowView(
                name: "Exportar Relatório",
                description: "Navega até relatórios e exporta PDF",
                lastUsed: "Há 1 hora",
                executionCount: 23
            )
            MacroRowView(
                name: "Fechar Popups",
                description: "Fecha todas as janelas de notificação",
                lastUsed: "Há 3 horas",
                executionCount: 112
            )
            MacroRowView(
                name: "Preencher Formulário",
                description: "Preenche campos do cadastro de cliente",
                lastUsed: "Ontem",
                executionCount: 8
            )
            MacroRowView(
                name: "Backup Diário",
                description: "Copia arquivos para pasta de backup",
                lastUsed: "2 dias atrás",
                executionCount: 31
            )
        }
        .padding(.horizontal, 12)
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
