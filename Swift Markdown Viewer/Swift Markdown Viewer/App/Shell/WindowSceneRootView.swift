import SwiftUI
#if os(macOS)
import AppKit
#endif

struct WindowSceneRootView: View {
    @StateObject private var model: AppModel
    @ObservedObject private var sessionStore: WorkspaceWindowSessionStore
    private let sceneID: String
    #if os(macOS)
    @State private var hasAttemptedInitialFolderPrompt = false
    @Environment(\.openWindow) private var openWindow
    #endif
    @Environment(\.scenePhase) private var scenePhase

    init(
        launchOptions: HarnessLaunchOptions,
        sceneID: String,
        sessionStore: WorkspaceWindowSessionStore
    ) {
        self.sceneID = sceneID
        self.sessionStore = sessionStore
        _model = StateObject(
            wrappedValue: AppModel(
                launchOptions: launchOptions,
                initialSession: sessionStore.claimLaunchSession(for: sceneID)
            )
        )
    }

    var body: some View {
        ContentView(model: model, onOpenFolder: openFolderAction)
            #if os(macOS)
            .focusedSceneValue(\.openFolderAction, OpenFolderAction(handler: openFolder))
            .onAppear {
                sessionStore.scheduleAdditionalWindows(openWindow: openWindow)
                requestInitialFolderPromptIfNeeded()
            }
            .onDisappear {
                sessionStore.removeActiveSession(for: sceneID)
            }
            #endif
            .onChange(of: model.selectedPath) { _ in
                sessionStore.updateActiveSession(model.restorationSession, for: sceneID)
            }
            .onChange(of: model.windowTitle) { _ in
                sessionStore.updateActiveSession(model.restorationSession, for: sceneID)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase != .active {
                    sessionStore.persistActiveSessions()
                }
            }
    }

    #if os(macOS)
    private var openFolderAction: (() -> Void)? {
        openFolder
    }

    private func requestInitialFolderPromptIfNeeded() {
        guard !hasAttemptedInitialFolderPrompt else { return }
        hasAttemptedInitialFolderPrompt = true

        if sessionStore.shouldSuppressAutomaticFolderPrompt(for: sceneID) {
            return
        }
        guard model.shouldAutoPromptForFolderOnLaunch else { return }

        DispatchQueue.main.async {
            openFolder()
        }
    }

    private func openFolder() {
        if model.launchOptions.uiTestMode, let testFolderURL = UITestOpenFolderSelectionStore.shared.nextFolderURL() {
            model.openFolder(at: testFolderURL)
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Open Folder"
        panel.prompt = "Open"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        model.openFolder(at: selectedURL)
    }
    #else
    private var openFolderAction: (() -> Void)? {
        nil
    }
    #endif
}

#if os(macOS)
struct OpenFolderAction {
    let handler: () -> Void

    func callAsFunction() {
        handler()
    }
}

private struct OpenFolderActionKey: FocusedValueKey {
    typealias Value = OpenFolderAction
}

extension FocusedValues {
    var openFolderAction: OpenFolderAction? {
        get { self[OpenFolderActionKey.self] }
        set { self[OpenFolderActionKey.self] = newValue }
    }
}

struct WindowOpenFolderCommands: Commands {
    @FocusedValue(\.openFolderAction) private var openFolderAction

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
            Button("Open Folder…") {
                openFolderAction?()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(openFolderAction == nil)
        }
    }
}
#endif
