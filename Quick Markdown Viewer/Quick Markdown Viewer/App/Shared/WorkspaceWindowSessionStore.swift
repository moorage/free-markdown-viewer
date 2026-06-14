import Combine
import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

enum WorkspaceSessionSource: Codable, Equatable, Sendable {
    case local(rootPath: String, securityScopedBookmarkData: Data?)
    case github(GitHubWorkspaceSessionSource)
}

struct WorkspaceWindowSession: Codable, Equatable, Sendable {
    let source: WorkspaceSessionSource
    let selectedFile: String?
    let ignorePatterns: WorkspaceIgnorePatterns

    init(
        source: WorkspaceSessionSource,
        selectedFile: String?,
        ignorePatterns: WorkspaceIgnorePatterns = .default
    ) {
        self.source = source
        self.selectedFile = selectedFile
        self.ignorePatterns = ignorePatterns
    }

    init(
        rootPath: String,
        selectedFile: String?,
        securityScopedBookmarkData: Data?,
        ignorePatterns: WorkspaceIgnorePatterns = .default
    ) {
        self.init(
            source: .local(rootPath: rootPath, securityScopedBookmarkData: securityScopedBookmarkData),
            selectedFile: selectedFile,
            ignorePatterns: ignorePatterns
        )
    }

    var rootURL: URL {
        switch source {
        case let .local(rootPath, _):
            return URL(fileURLWithPath: rootPath)
        case let .github(remoteSource):
            return URL(fileURLWithPath: remoteSource.cachedRootPath, isDirectory: true)
        }
    }

    var rootPath: String {
        switch source {
        case let .local(rootPath, _):
            return rootPath
        case let .github(remoteSource):
            return remoteSource.cachedRootPath
        }
    }

    var securityScopedBookmarkData: Data? {
        switch source {
        case let .local(_, bookmarkData):
            return bookmarkData
        case .github:
            return nil
        }
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case selectedFile
        case ignorePatterns
        case rootPath
        case securityScopedBookmarkData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let source = try container.decodeIfPresent(WorkspaceSessionSource.self, forKey: .source) {
            self.source = source
            selectedFile = try container.decodeIfPresent(String.self, forKey: .selectedFile)
            ignorePatterns = try container.decodeIfPresent(WorkspaceIgnorePatterns.self, forKey: .ignorePatterns) ?? .default
            return
        }

        let rootPath = try container.decode(String.self, forKey: .rootPath)
        let bookmarkData = try container.decodeIfPresent(Data.self, forKey: .securityScopedBookmarkData)
        source = .local(rootPath: rootPath, securityScopedBookmarkData: bookmarkData)
        selectedFile = try container.decodeIfPresent(String.self, forKey: .selectedFile)
        ignorePatterns = try container.decodeIfPresent(WorkspaceIgnorePatterns.self, forKey: .ignorePatterns) ?? .default
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(selectedFile, forKey: .selectedFile)
        try container.encode(ignorePatterns, forKey: .ignorePatterns)
    }
}

struct AutomaticFolderPromptPolicy {
    private var didConsumeInitialLaunchScene = false
    private var suppressedSceneIDs: Set<String> = []

    mutating func suppressAutomaticFolderPrompt(for sceneID: String) {
        suppressedSceneIDs.insert(sceneID)
    }

    mutating func shouldSuppressAutomaticFolderPrompt(
        for sceneID: String,
        hasRestoredSession: Bool
    ) -> Bool {
        if suppressedSceneIDs.contains(sceneID) {
            return true
        }
        if hasRestoredSession {
            didConsumeInitialLaunchScene = true
            return true
        }
        guard !didConsumeInitialLaunchScene else { return false }
        didConsumeInitialLaunchScene = true
        return true
    }
}

@MainActor
final class WorkspaceWindowSessionStore: ObservableObject {
    private static let persistenceKey = "workspaceWindowSessions"

    private let shouldRestoreSessions: Bool
    private let userDefaults: UserDefaults
    private var pendingPrimarySession: WorkspaceWindowSession?
    private var pendingAdditionalSessions: [WorkspaceWindowSession] = []
    private var scheduledSessions: [String: WorkspaceWindowSession] = [:]
    private var claimedSessions: [String: WorkspaceWindowSession] = [:]
    private var activeSessions: [String: WorkspaceWindowSession] = [:]
    private var activeSceneOrder: [String] = []
    private var pendingRemovalTasks: [String: Task<Void, Never>] = [:]
    private var didScheduleAdditionalWindows = false
    private var automaticFolderPromptPolicy = AutomaticFolderPromptPolicy()
    private var isTerminating = false
    #if os(macOS)
    private var willTerminateObserver: NSObjectProtocol?
    #endif

    init(
        launchOptions: HarnessLaunchOptions,
        userDefaults: UserDefaults = .standard,
        observeTermination: Bool = true
    ) {
        self.userDefaults = userDefaults
        shouldRestoreSessions =
            !launchOptions.uiTestMode &&
            launchOptions.fixtureRoot == nil &&
            launchOptions.openFile == nil &&
            launchOptions.commandDirectoryURL == nil &&
            launchOptions.dumpVisibleStateURL == nil &&
            launchOptions.dumpPerfStateURL == nil &&
            launchOptions.screenshotPathURL == nil

        guard shouldRestoreSessions else { return }

        let persisted = loadPersistedSessions()
        pendingPrimarySession = persisted.first
        pendingAdditionalSessions = Array(persisted.dropFirst())

        #if os(macOS)
        if observeTermination {
            willTerminateObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.willTerminateNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.isTerminating = true
                    self?.persistActiveSessions()
                }
            }
        }
        #endif
    }

    func claimLaunchSession(for sceneID: String) -> WorkspaceWindowSession? {
        if let session = claimedSessions[sceneID] {
            return session
        }
        if let session = scheduledSessions.removeValue(forKey: sceneID) {
            claimedSessions[sceneID] = session
            return session
        }
        if let session = pendingPrimarySession {
            pendingPrimarySession = nil
            claimedSessions[sceneID] = session
            return session
        }
        return nil
    }

    func scheduleAdditionalWindows(openWindow: OpenWindowAction) {
        guard shouldRestoreSessions, !didScheduleAdditionalWindows else { return }
        didScheduleAdditionalWindows = true

        for session in pendingAdditionalSessions {
            let sceneID = UUID().uuidString
            scheduledSessions[sceneID] = session
            openWindow(value: sceneID)
        }

        pendingAdditionalSessions.removeAll()
    }

    func discardPendingAdditionalWindows() {
        didScheduleAdditionalWindows = true
        pendingAdditionalSessions.removeAll()
    }

    func scheduleExternalWorkspaceWindow(for session: WorkspaceWindowSession, openWindow: OpenWindowAction) {
        let sceneID = UUID().uuidString
        scheduledSessions[sceneID] = session
        openWindow(value: sceneID)
    }

    func canReplaceClaimedLaunchSession(for sceneID: String) -> Bool {
        claimedSessions[sceneID] != nil && activeSessions.isEmpty
    }

    func shouldSuppressAutomaticFolderPrompt(for sceneID: String) -> Bool {
        automaticFolderPromptPolicy.shouldSuppressAutomaticFolderPrompt(
            for: sceneID,
            hasRestoredSession: claimedSessions[sceneID] != nil
        )
    }

    func suppressAutomaticFolderPrompt(for sceneID: String) {
        automaticFolderPromptPolicy.suppressAutomaticFolderPrompt(for: sceneID)
    }

    func updateActiveSession(_ session: WorkspaceWindowSession?, for sceneID: String) {
        pendingRemovalTasks[sceneID]?.cancel()
        pendingRemovalTasks.removeValue(forKey: sceneID)
        if let session {
            activeSessions[sceneID] = session
            if !activeSceneOrder.contains(sceneID) {
                activeSceneOrder.append(sceneID)
            }
        } else {
            activeSessions.removeValue(forKey: sceneID)
            activeSceneOrder.removeAll { $0 == sceneID }
        }
        persistActiveSessions()
    }

    func removeActiveSession(for sceneID: String) {
        pendingRemovalTasks[sceneID]?.cancel()
        pendingRemovalTasks[sceneID] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self else { return }
            guard !Task.isCancelled else { return }
            guard !self.isTerminating else { return }

            self.pendingRemovalTasks.removeValue(forKey: sceneID)
            self.activeSessions.removeValue(forKey: sceneID)
            self.activeSceneOrder.removeAll { $0 == sceneID }
            self.persistActiveSessions()
        }
    }

    func persistActiveSessions() {
        guard shouldRestoreSessions else { return }
        let sessions = activeSceneOrder.compactMap { activeSessions[$0] }
        if let data = try? JSONEncoder().encode(sessions) {
            userDefaults.set(data, forKey: Self.persistenceKey)
        }
    }

    private func loadPersistedSessions() -> [WorkspaceWindowSession] {
        guard let data = userDefaults.data(forKey: Self.persistenceKey),
              let sessions = try? JSONDecoder().decode([WorkspaceWindowSession].self, from: data) else {
            return []
        }
        return sessions
    }
}
