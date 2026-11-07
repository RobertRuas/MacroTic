import SwiftUI

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
