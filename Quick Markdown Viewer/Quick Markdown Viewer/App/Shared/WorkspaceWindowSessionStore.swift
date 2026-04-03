import Combine
import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

struct WorkspaceWindowSession: Codable, Equatable, Sendable {
    let rootPath: String
    let selectedFile: String?
    let securityScopedBookmarkData: Data?

    var rootURL: URL {
        URL(fileURLWithPath: rootPath)
    }
}

struct AutomaticFolderPromptPolicy {
    private var didConsumeInitialLaunchScene = false

    mutating func shouldSuppressAutomaticFolderPrompt(
        for sceneID: String,
        hasRestoredSession: Bool
    ) -> Bool {
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

    func shouldSuppressAutomaticFolderPrompt(for sceneID: String) -> Bool {
        automaticFolderPromptPolicy.shouldSuppressAutomaticFolderPrompt(
            for: sceneID,
            hasRestoredSession: claimedSessions[sceneID] != nil
        )
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
