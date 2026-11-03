import SwiftUI

@Observable
final class AppState {
    var selectedSection: AppSection? = .home

    @ObservationIgnored
    let updater = UpdaterController()
}
