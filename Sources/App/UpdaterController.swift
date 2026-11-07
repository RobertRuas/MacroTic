import Foundation
import Sparkle

@Observable
final class UpdaterController {
    @ObservationIgnored
    private let updater: SPUUpdater

    @ObservationIgnored
    private let userDriver = SilentUpdateUserDriver()

    @ObservationIgnored
    private var observation: NSKeyValueObservation?

    private(set) var canCheckForUpdates = false
    private(set) var lastCheckDate: Date?

    @ObservationIgnored
    private var lastCheckObservation: NSKeyValueObservation?

    let isAvailable = Bundle.main.bundleURL.pathExtension == "app"

    var automaticallyChecksForUpdates: Bool { updater.automaticallyChecksForUpdates }
    var automaticallyDownloadsUpdates: Bool { updater.automaticallyDownloadsUpdates }
    var checkIntervalHours: Int { Int(updater.updateCheckInterval / 3600) }
    var feedURLString: String? { updater.feedURL?.absoluteString }

    init() {
        updater = SPUUpdater(
            hostBundle: Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: userDriver,
            delegate: nil
        )
        if isAvailable {
            try? updater.start()
        }
        canCheckForUpdates = updater.canCheckForUpdates
        lastCheckDate = updater.lastUpdateCheckDate
        observation = updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, change in
            DispatchQueue.main.async {
                self?.canCheckForUpdates = change.newValue ?? false
            }
        }
        lastCheckObservation = updater.observe(\.lastUpdateCheckDate, options: [.new]) { [weak self] _, change in
            DispatchQueue.main.async {
                self?.lastCheckDate = change.newValue ?? nil
            }
        }
    }

    func checkForUpdates() {
        guard isAvailable else { return }
        updater.checkForUpdates()
    }

    func checkForUpdatesAtStartup() {
        guard isAvailable else { return }
        userDriver.beginStartupCheck()
        updater.checkForUpdates()
    }
}
