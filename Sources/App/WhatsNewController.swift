import AppKit
import SwiftUI

/// Shows a small "Novidades" window with the release notes the first time the app
/// launches on a new version (i.e. right after an auto-update). Notes are fetched from
/// the matching GitHub Release for the current version; a generic message is shown if
/// they can't be fetched. Does nothing on a genuinely fresh first install.
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
        fetchNotes(for: version) { notes, url in
            present(version: version, notes: notes, url: url)
        }
    }

    private static var hasExistingLibrary: Bool {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent("MacroTic/macros.json").path)
    }

    // MARK: - Fetch

    private static func ownerRepo() -> (owner: String, repo: String)? {
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed) else { return nil }
        // https://github.com/<owner>/<repo>/releases/latest/download/appcast.xml
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }
        return (parts[0], parts[1])
    }

    private static func fetchNotes(for version: String, completion: @escaping (String?, URL?) -> Void) {
        guard let (owner, repo) = ownerRepo(),
              let api = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/tags/v\(version)") else {
            DispatchQueue.main.async { completion(nil, nil) }
            return
        }
        var request = URLRequest(url: api)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("MacroTic", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { data, _, _ in
            var notes: String?
            var htmlURL: URL?
            if let data,
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let body = (object["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                notes = (body?.isEmpty == false) ? body : nil
                if let link = object["html_url"] as? String { htmlURL = URL(string: link) }
            }
            DispatchQueue.main.async { completion(notes, htmlURL) }
        }.resume()
    }

    // MARK: - Present

    private static func present(version: String, notes: String?, url: URL?) {
        let fallback = "Você atualizou para a versão \(version).\n\nObrigado por usar o MacroTic!"
        let hosting = NSHostingController(
            rootView: WhatsNewView(
                version: version,
                notes: notes ?? fallback,
                githubURL: url,
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
    let notes: String
    var githubURL: URL?
    let onClose: () -> Void

    private var lines: [String] { notes.components(separatedBy: "\n") }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { pair in
                        lineView(pair.element)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
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

    @ViewBuilder
    private func lineView(_ raw: String) -> some View {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Spacer().frame(height: 3)
        } else if trimmed.hasPrefix("## ") || trimmed.hasPrefix("# ") {
            Text(trimmed.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces))
                .font(.headline)
                .padding(.top, 4)
        } else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 7) {
                Text("•").foregroundStyle(.secondary)
                Text(inlineMarkdown(String(trimmed.dropFirst(2))))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(inlineMarkdown(trimmed))
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }

    private func inlineMarkdown(_ string: String) -> AttributedString {
        (try? AttributedString(
            markdown: string,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(string)
    }

    private var footer: some View {
        HStack {
            if let githubURL {
                Button {
                    NSWorkspace.shared.open(githubURL)
                } label: {
                    Label("Ver no GitHub", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.link)
            }
            Spacer()
            Button("Fechar", action: onClose)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
