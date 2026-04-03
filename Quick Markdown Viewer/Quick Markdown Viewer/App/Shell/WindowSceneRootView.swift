import SwiftUI
#if os(macOS)
import AppKit
#else
import UniformTypeIdentifiers
#endif

struct WindowSceneRootView: View {
    @StateObject private var model: AppModel
    @ObservedObject private var sessionStore: WorkspaceWindowSessionStore
    private let sceneID: String
    #if os(macOS)
    @State private var hasAttemptedInitialFolderPrompt = false
    @Environment(\.openWindow) private var openWindow
    #else
    @State private var isPresentingFolderImporter = false
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
            .focusedSceneValue(\.revealInFinderAction, revealInFinderAction)
            .focusedSceneValue(\.increaseFontSizeAction, IncreaseFontSizeAction(handler: model.increaseFontSize))
            .focusedSceneValue(\.decreaseFontSizeAction, DecreaseFontSizeAction(handler: model.decreaseFontSize))
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
            #if !os(macOS)
            .fileImporter(
                isPresented: $isPresentingFolderImporter,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false,
                onCompletion: handleFolderImport
            )
            #endif
    }

    private var openFolderAction: (() -> Void)? {
        openFolder
    }

    #if os(macOS)
    private var revealInFinderAction: RevealInFinderAction? {
        guard model.canRevealSelectedFileInFinder else { return nil }
        return RevealInFinderAction(handler: revealInFinder)
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

    private func revealInFinder() {
        guard let selectedFileURL = model.selectedFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selectedFileURL])
    }
    #else
    private func openFolder() {
        if model.launchOptions.uiTestMode, let testFolderURL = UITestOpenFolderSelectionStore.shared.nextFolderURL() {
            model.openFolder(at: testFolderURL)
            return
        }

        isPresentingFolderImporter = true
    }

    private func handleFolderImport(_ result: Result<[URL], Error>) {
        guard case let .success(selectedURLs) = result, let selectedURL = selectedURLs.first else {
            return
        }
        model.openFolder(at: selectedURL)
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

struct RevealInFinderAction {
    let handler: () -> Void

    func callAsFunction() {
        handler()
    }
}

struct IncreaseFontSizeAction {
    let handler: () -> Void

    func callAsFunction() {
        handler()
    }
}

struct DecreaseFontSizeAction {
    let handler: () -> Void

    func callAsFunction() {
        handler()
    }
}

private struct OpenFolderActionKey: FocusedValueKey {
    typealias Value = OpenFolderAction
}

private struct RevealInFinderActionKey: FocusedValueKey {
    typealias Value = RevealInFinderAction
}

private struct IncreaseFontSizeActionKey: FocusedValueKey {
    typealias Value = IncreaseFontSizeAction
}

private struct DecreaseFontSizeActionKey: FocusedValueKey {
    typealias Value = DecreaseFontSizeAction
}

extension FocusedValues {
    var openFolderAction: OpenFolderAction? {
        get { self[OpenFolderActionKey.self] }
        set { self[OpenFolderActionKey.self] = newValue }
    }

    var revealInFinderAction: RevealInFinderAction? {
        get { self[RevealInFinderActionKey.self] }
        set { self[RevealInFinderActionKey.self] = newValue }
    }

    var increaseFontSizeAction: IncreaseFontSizeAction? {
        get { self[IncreaseFontSizeActionKey.self] }
        set { self[IncreaseFontSizeActionKey.self] = newValue }
    }

    var decreaseFontSizeAction: DecreaseFontSizeAction? {
        get { self[DecreaseFontSizeActionKey.self] }
        set { self[DecreaseFontSizeActionKey.self] = newValue }
    }
}

struct WindowOpenFolderCommands: Commands {
    @FocusedValue(\.openFolderAction) private var openFolderAction
    @FocusedValue(\.revealInFinderAction) private var revealInFinderAction
    @FocusedValue(\.increaseFontSizeAction) private var increaseFontSizeAction
    @FocusedValue(\.decreaseFontSizeAction) private var decreaseFontSizeAction

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Divider()
            Button("Open Folder…") {
                openFolderAction?()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(openFolderAction == nil)

            Button("Show in Finder") {
                revealInFinderAction?()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(revealInFinderAction == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Increase Font Size") {
                increaseFontSizeAction?()
            }
            .keyboardShortcut("=", modifiers: [.command])
            .disabled(increaseFontSizeAction == nil)

            Button("Decrease Font Size") {
                decreaseFontSizeAction?()
            }
            .keyboardShortcut("-", modifiers: [.command])
            .disabled(decreaseFontSizeAction == nil)
        }
    }
}
#endif
