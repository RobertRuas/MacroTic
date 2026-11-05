import Foundation
import Sparkle

@Observable
final class UpdaterController {
    @ObservationIgnored
    private let standardController: SPUStandardUpdaterController

    @ObservationIgnored
    private var observation: NSKeyValueObservation?

    private(set) var canCheckForUpdates = false

    @ObservationIgnored
    private var didInitialCheck = false

    let isAvailable = Bundle.main.bundleURL.pathExtension == "app"

    init() {
        standardController = SPUStandardUpdaterController(
            startingUpdater: Bundle.main.bundleURL.pathExtension == "app",
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        canCheckForUpdates = standardController.updater.canCheckForUpdates
        observation = standardController.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.canCheckForUpdates = updater.canCheckForUpdates
                self.performInitialCheckIfNeeded()
            }
        }
    }

    private func performInitialCheckIfNeeded() {
        guard isAvailable, !didInitialCheck, standardController.updater.canCheckForUpdates else { return }
        didInitialCheck = true
        standardController.updater.checkForUpdatesInBackground()
    }

    func checkForUpdates() {
        guard isAvailable else { return }
        standardController.checkForUpdates(nil)
    }
}
