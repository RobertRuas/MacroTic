import Foundation
import Sparkle

@Observable
final class UpdaterController {
    @ObservationIgnored
    private let standardController: SPUStandardUpdaterController

    @ObservationIgnored
    private var observation: NSKeyValueObservation?

    private(set) var canCheckForUpdates = false

    let isAvailable = Bundle.main.bundleURL.pathExtension == "app"

    init() {
        standardController = SPUStandardUpdaterController(
            startingUpdater: Bundle.main.bundleURL.pathExtension == "app",
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        canCheckForUpdates = standardController.updater.canCheckForUpdates
        observation = standardController.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, change in
            DispatchQueue.main.async {
                self?.canCheckForUpdates = change.newValue ?? false
            }
        }
    }

    func checkForUpdates() {
        guard isAvailable else { return }
        standardController.checkForUpdates(nil)
    }
}
