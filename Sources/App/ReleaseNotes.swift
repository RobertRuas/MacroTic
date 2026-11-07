import Foundation

/// Release notes shown in the "Novidades" window, bundled in the app (no network, no external references).
/// Add an entry for each new version: the key is the CFBundleShortVersionString, the value is the list of
/// user-facing novelties shown as bullets. Versions without an entry show a generic "atualizado" message.
enum ReleaseNotes {
    static let byVersion: [String: [String]] = [
        "0.2.6": [
            "Agora o MacroTic avisa com uma telinha as novidades sempre que você atualiza.",
            "Confirmação antes de apagar uma macro, evitando exclusões acidentais.",
            "Backup da biblioteca: exporte e importe todas as suas macros em Configurações.",
            "Validação das ações: uma ação sem posição ou atalho definido avisa com um sinal laranja e interrompe com uma mensagem clara, em vez de falhar no meio da execução.",
            "Aviso claro e atalho para os Ajustes quando falta a permissão de Acessibilidade ao gravar.",
            "Mais segurança para suas macros: proteção contra perda do arquivo caso ele seja corrompido.",
        ],
    ]

    static func notes(for version: String) -> [String]? {
        byVersion[version]
    }
}
