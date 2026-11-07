import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    let state: AppState
    let onClose: () -> Void

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private var lastCheckText: String {
        guard let date = state.updater.lastCheckDate else { return "Nunca" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var automaticCheckText: String {
        guard state.updater.automaticallyChecksForUpdates else { return "Desativada" }
        return "Ativada (a cada \(state.updater.checkIntervalHours)h)"
    }

    private var automaticInstallText: String {
        state.updater.automaticallyDownloadsUpdates ? "Ativada, sem confirmação" : "Desativada"
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ScrollView {
                VStack(spacing: 24) {
                    updatesSection
                    librarySection
                    creditsSection
                }
                .padding(28)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .frame(minWidth: 480, minHeight: 440)
        .background(.background)
    }

    private var toolbar: some View {
        HStack {
            Text("Configurações")
                .font(.title3.weight(.semibold))
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconActionButtonStyle())
        }
        .padding(12)
    }

    private var updatesSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Atualizações")
                    .font(.headline)
                Text("O app verifica e instala novas versões automaticamente.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 16)

            VStack(spacing: 0) {
                HStack {
                    Text("Versão")
                    Spacer()
                    Text(version)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)

                Divider()

                HStack {
                    Text("Buscar nova versão")
                    Spacer()
                    Button("Verificar atualizações") {
                        state.updater.checkForUpdates()
                    }
                    .disabled(!state.updater.canCheckForUpdates)
                }
                .padding(.vertical, 12)

                Divider()

                HStack {
                    Text("Última verificação")
                    Spacer()
                    Text(lastCheckText)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)

                Divider()

                HStack {
                    Text("Verificação automática")
                    Spacer()
                    Text(automaticCheckText)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)

                Divider()

                HStack {
                    Text("Instalação automática")
                    Spacer()
                    Text(automaticInstallText)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            }
            .padding(.horizontal, 16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

            if !state.updater.isAvailable {
                Text("Disponível apenas no app instalado (.app).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Biblioteca")
                    .font(.headline)
                Text("\(state.macroStore.macros.count) macro(s) salvas. Exporte um backup ou importe de outro arquivo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    exportLibrary()
                } label: {
                    Label("Exportar biblioteca…", systemImage: "square.and.arrow.up")
                }
                .disabled(state.macroStore.macros.isEmpty)

                Button {
                    importLibrary()
                } label: {
                    Label("Importar biblioteca…", systemImage: "square.and.arrow.down")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exportLibrary() {
        guard let data = state.macroStore.exportJSON() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "MacroTic-biblioteca.json"
        panel.title = "Exportar biblioteca"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    private func importLibrary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Importar biblioteca"
        panel.begin { response in
            guard response == .OK, let url = panel.url, let data = try? Data(contentsOf: url) else { return }
            do {
                let result = try state.macroStore.importJSON(from: data)
                presentInfo(
                    title: "Importação concluída",
                    message: "\(result.imported) importada(s); \(result.skipped) já existente(s) ignorada(s)."
                )
            } catch {
                presentInfo(title: "Falha ao importar", message: "O arquivo não é uma biblioteca de macros válida.")
            }
        }
    }

    private func presentInfo(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Créditos")
                    .font(.headline)
                Text("Desenvolvido por Robert Ruas")
                    .font(.subheadline)
                Text("92ruas@gmail.com")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Button {
                FeedbackMailer.compose()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "ladybug")
                    Text("Enviar feedback ou reportar um problema")
                }
            }

            Text("O log de erros recente é anexado ao e-mail para ajudar no diagnóstico.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
