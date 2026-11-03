import Foundation

struct TestLogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let kind: MacroStepKind
    let detail: String
    let success: Bool
    let duration: TimeInterval

    var timeLabel: String {
        date.formatted(.dateTime.hour().minute().second())
    }

    var durationLabel: String {
        String(format: "%.2f s", duration)
    }
}
