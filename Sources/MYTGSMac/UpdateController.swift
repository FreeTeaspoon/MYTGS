import Foundation
import Sparkle

@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var statusMessage: String

    private let updaterController: SPUStandardUpdaterController?
    private let unavailableMessage: String?

    init(bundle: Bundle = .main) {
        guard
            let feedURLString = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let feedURL = URL(string: feedURLString),
            feedURL.scheme == "https"
        else {
            let message = "Updates are not configured for this build."
            statusMessage = message
            unavailableMessage = message
            updaterController = nil
            return
        }

        guard
            let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            !publicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            let message = "Sparkle updates need an EdDSA public key before release."
            statusMessage = message
            unavailableMessage = message
            updaterController = nil
            return
        }

        unavailableMessage = nil
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        statusMessage = "Updates configured through \(feedURL.host(percentEncoded: false) ?? "Sparkle")."
    }

    func checkForUpdates() {
        guard let updater = updaterController?.updater else {
            statusMessage = unavailableMessage ?? "Updates are not configured for this build."
            return
        }

        guard updater.canCheckForUpdates else {
            statusMessage = "Sparkle is not ready to check for updates yet."
            return
        }

        updater.checkForUpdates()
        statusMessage = "Checking for updates..."
    }
}
