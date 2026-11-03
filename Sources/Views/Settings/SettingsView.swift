import SwiftUI

struct SettingsView: View {
    let state: AppState

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
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

            Spacer()
        }
        .padding(28)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, alignment: .top)
        .navigationTitle("Configurações")
    }
}
