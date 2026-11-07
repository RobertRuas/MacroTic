import AppKit
import SwiftUI

/// Shows a small "Novidades" window with the release notes the first time the app
/// launches on a new version (i.e. right after an auto-update). Notes come from the
/// bundled `ReleaseNotes` list — nothing is fetched and no external service is referenced.
/// Does nothing on a genuinely fresh first install.
enum WhatsNew {
    private static let defaultsKey = "whatsNewLastVersion"
    private static var window: NSWindow?

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    private static var isPackagedApp: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    static func presentIfNeeded() {
        guard isPackagedApp else { return }
        let version = currentVersion
        guard version != "dev" else { return }

        let defaults = UserDefaults.standard
        let last = defaults.string(forKey: defaultsKey)
        guard last != version else { return }

        let isUpgrade: Bool
        if let last, !last.isEmpty {
            isUpgrade = true
        } else {
            // No record yet. Show only if there is evidence of a prior install (an upgrade from a
            // pre-this-feature version), never on a genuinely fresh first install.
            isUpgrade = hasExistingLibrary
        }

        defaults.set(version, forKey: defaultsKey)
        guard isUpgrade else { return }

        AppLog.shared.log("Primeira execução da versão \(version) — exibindo novidades.")
        present(version: version, notes: ReleaseNotes.notes(for: version))
    }

    private static var hasExistingLibrary: Bool {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent("MacroTic/macros.json").path)
    }

    private static func present(version: String, notes: [String]?) {
        let hosting = NSHostingController(
            rootView: WhatsNewView(
                version: version,
                notes: notes ?? [],
                onClose: { window?.close(); window = nil }
            )
        )
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = "Novidades"
        newWindow.styleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        newWindow.titlebarAppearsTransparent = true
        newWindow.setContentSize(NSSize(width: 480, height: 480))
        newWindow.minSize = NSSize(width: 420, height: 360)
        newWindow.isReleasedWhenClosed = false
        newWindow.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        newWindow.standardWindowButton(.zoomButton)?.isEnabled = false
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = newWindow
    }
}

private struct WhatsNewView: View {
    let version: String
    let notes: [String]
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if notes.isEmpty {
                        Text("Você atualizou para a versão \(version).")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(notes.enumerated()), id: \.offset) { pair in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.tint)
                                    .font(.callout)
                                Text(pair.element)
                                    .font(.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Novidades")
                    .font(.title2.weight(.bold))
                Text("Versão \(version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Fechar", action: onClose)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
