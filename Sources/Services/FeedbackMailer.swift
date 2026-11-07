import AppKit

enum FeedbackMailer {
    private static let recipient = "92ruas@gmail.com"

    static func compose() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let subject = "Feedback do MacroTic (v\(version))"
        let body = "Descreva aqui o seu feedback ou o problema encontrado:\n\n\n\n—\nVersão: \(version)"

        AppLog.shared.log("Abrindo composição de feedback para o desenvolvedor.")

        // Preferred path: a real e-mail draft WITH the log file attached, via the system
        // e-mail composer (uses the user's default mail client).
        if attachViaSharingService(subject: subject, body: body) { return }

        // Fallback: mailto (can't attach files) — embed the recent logs inline so they still reach the dev.
        composeViaMailto(subject: subject, body: body)
    }

    /// Opens an e-mail draft with the log file attached. Returns false if it couldn't (no mail client / can't perform).
    private static func attachViaSharingService(subject: String, body: String) -> Bool {
        let logURL = AppLog.shared.logFileURL
        guard FileManager.default.fileExists(atPath: logURL.path),
              let service = NSSharingService(named: .composeEmail) else { return false }
        service.recipients = [recipient]
        service.subject = subject
        let items: [Any] = [body, logURL]
        guard service.canPerform(withItems: items) else { return false }
        service.perform(withItems: items)
        return true
    }

    private static func composeViaMailto(subject: String, body: String) {
        let logTail = AppLog.shared.recentText(maxBytes: 1500)
        var fullBody = body
        if !logTail.isEmpty {
            fullBody += "\n\n----- Últimos logs de erro -----\n\(logTail)"
        }
        guard
            let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let bodyEncoded = fullBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "mailto:\(recipient)?subject=\(subjectEncoded)&body=\(bodyEncoded)")
        else { return }
        NSWorkspace.shared.open(url)
    }
}
