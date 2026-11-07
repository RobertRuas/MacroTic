import AppKit

enum FeedbackMailer {
    static func compose() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let subject = "Feedback do MacroTic (v\(version))"
        let body = "Descreva aqui o seu feedback ou o problema encontrado:\n\n\n\n—\nVersão: \(version)"
        guard
            let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "mailto:92ruas@gmail.com?subject=\(subjectEncoded)&body=\(bodyEncoded)")
        else { return }
        NSWorkspace.shared.open(url)
    }
}
