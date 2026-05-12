import Combine
import Foundation

nonisolated struct AppStoreVersionInfo: Equatable, Sendable {
    let version: String
    let storeURL: URL
}

nonisolated struct AppStoreLookupConfiguration: Equatable, Sendable {
    static let liveAppID = "6761271951"
    static let liveBundleIdentifier = "com.souschefstudio.Free-Markdown-Viewer"

    let appID: String
    let bundleIdentifier: String
    let installedVersion: String
    let countryCode: String
    let entity: String

    init(
        appID: String = Self.liveAppID,
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? Self.liveBundleIdentifier,
        installedVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
        countryCode: String = Locale.current.region?.identifier ?? "US",
        entity: String = AppStoreLookupConfiguration.defaultEntity
    ) {
        self.appID = appID
        self.bundleIdentifier = bundleIdentifier
        self.installedVersion = installedVersion
        self.countryCode = countryCode
        self.entity = entity
    }

    nonisolated static var defaultEntity: String {
        #if os(macOS)
        return "macSoftware"
        #else
        return "software"
        #endif
    }

    var lookupURL: URL {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: appID),
            URLQueryItem(name: "country", value: countryCode),
            URLQueryItem(name: "entity", value: entity)
        ]
        return components.url!
    }
}

nonisolated protocol AppStoreVersionFetching: Sendable {
    func latestVersion(configuration: AppStoreLookupConfiguration) async throws -> AppStoreVersionInfo?
}

nonisolated struct URLSessionAppStoreVersionFetcher: AppStoreVersionFetching {
    private struct LookupResponse: Decodable {
        struct Result: Decodable {
            let bundleId: String?
            let trackViewUrl: String?
            let version: String?
        }

        let results: [Result]
    }

    func latestVersion(configuration: AppStoreLookupConfiguration) async throws -> AppStoreVersionInfo? {
        let (data, _) = try await URLSession.shared.data(from: configuration.lookupURL)
        let response = try JSONDecoder().decode(LookupResponse.self, from: data)
        let result = response.results.first { result in
            result.bundleId == nil || result.bundleId == configuration.bundleIdentifier
        }

        guard
            let version = result?.version,
            let rawURL = result?.trackViewUrl,
            let storeURL = URL(string: rawURL)
        else {
            return nil
        }

        return AppStoreVersionInfo(version: version, storeURL: storeURL)
    }
}

@MainActor
final class AppUpdateChecker: ObservableObject {
    enum AlertKind: Equatable {
        case updateAvailable(AppStoreVersionInfo)
        case upToDate(installedVersion: String)
        case failed(String)
    }

    struct AlertState: Identifiable, Equatable {
        let kind: AlertKind

        var id: String {
            switch kind {
            case let .updateAvailable(info):
                return "update-\(info.version)"
            case let .upToDate(version):
                return "current-\(version)"
            case let .failed(message):
                return "failed-\(message)"
            }
        }

        var title: String {
            switch kind {
            case .updateAvailable:
                return "Update Available"
            case .upToDate:
                return "Quick Markdown Viewer Is Up to Date"
            case .failed:
                return "Couldn't Check for Updates"
            }
        }

        var message: String {
            switch kind {
            case let .updateAvailable(info):
                return "Version \(info.version) is available on the App Store."
            case let .upToDate(version):
                return "You are running version \(version)."
            case let .failed(message):
                return message
            }
        }
    }

    @Published var activeAlert: AlertState?
    @Published private(set) var isChecking = false

    private static let skippedVersionDefaultsKey = "appUpdateChecker.skippedVersion"

    private let configuration: AppStoreLookupConfiguration
    private let fetcher: any AppStoreVersionFetching
    private let userDefaults: UserDefaults
    private var hasCheckedAutomatically = false

    init(
        configuration: AppStoreLookupConfiguration = AppStoreLookupConfiguration(),
        fetcher: any AppStoreVersionFetching = URLSessionAppStoreVersionFetcher(),
        userDefaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.fetcher = fetcher
        self.userDefaults = userDefaults
    }

    func checkAutomaticallyIfNeeded() {
        guard !hasCheckedAutomatically else { return }
        hasCheckedAutomatically = true
        Task {
            await checkForUpdates(trigger: .automatic)
        }
    }

    func checkManually() {
        Task {
            await checkForUpdates(trigger: .manual)
        }
    }

    func dismissActiveAlert() {
        activeAlert = nil
    }

    func skipActiveVersionUntilNextVersion() {
        if case let .updateAvailable(info) = activeAlert?.kind {
            userDefaults.set(info.version, forKey: Self.skippedVersionDefaultsKey)
        }
        activeAlert = nil
    }

    nonisolated static func isVersion(_ candidate: String, newerThan installed: String) -> Bool {
        compareVersions(candidate, installed) == .orderedDescending
    }

    nonisolated static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsParts = versionParts(lhs)
        let rhsParts = versionParts(rhs)
        let count = max(lhsParts.count, rhsParts.count)

        for index in 0..<count {
            let left = index < lhsParts.count ? lhsParts[index] : 0
            let right = index < rhsParts.count ? rhsParts[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }

        return .orderedSame
    }

    private enum CheckTrigger {
        case automatic
        case manual
    }

    private func checkForUpdates(trigger: CheckTrigger) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            guard let latestVersion = try await fetcher.latestVersion(configuration: configuration) else {
                if trigger == .manual {
                    activeAlert = AlertState(kind: .failed("The App Store did not return a version for this app."))
                }
                return
            }

            guard Self.isVersion(latestVersion.version, newerThan: configuration.installedVersion) else {
                if trigger == .manual {
                    activeAlert = AlertState(kind: .upToDate(installedVersion: configuration.installedVersion))
                }
                return
            }

            if trigger == .automatic,
               userDefaults.string(forKey: Self.skippedVersionDefaultsKey) == latestVersion.version {
                return
            }

            activeAlert = AlertState(kind: .updateAvailable(latestVersion))
        } catch {
            if trigger == .manual {
                activeAlert = AlertState(kind: .failed(error.localizedDescription))
            }
        }
    }

    private nonisolated static func versionParts(_ version: String) -> [Int] {
        version
            .split { !$0.isNumber }
            .map { Int($0) ?? 0 }
    }
}
