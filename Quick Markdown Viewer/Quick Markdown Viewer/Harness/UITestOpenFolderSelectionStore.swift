import Foundation

@MainActor
final class UITestOpenFolderSelectionStore {
    static let shared = UITestOpenFolderSelectionStore()

    private var pendingURLs: [URL] = []
    private var fallbackURL: URL?
    private var didConfigure = false

    private init() {}

    func configureIfNeeded(using launchOptions: HarnessLaunchOptions) {
        guard launchOptions.uiTestMode else { return }
        guard !didConfigure else { return }
        didConfigure = true
        pendingURLs = launchOptions.uiTestOpenFolderURLs
        fallbackURL = pendingURLs.last ?? launchOptions.uiTestOpenFolderURL
    }

    func nextFolderURL() -> URL? {
        if !pendingURLs.isEmpty {
            return pendingURLs.removeFirst()
        }
        return fallbackURL
    }
}
