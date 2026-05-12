import SwiftUI
#if os(macOS)
import AppKit
#else
import UniformTypeIdentifiers
import UIKit
#endif

struct WindowSceneRootView: View {
    @StateObject private var model: AppModel
    @ObservedObject private var sessionStore: WorkspaceWindowSessionStore
    @ObservedObject private var updateChecker: AppUpdateChecker
    private let sceneID: String
    @State private var isPresentingGitHubURLPrompt = false
    #if os(macOS)
    @ObservedObject private var externalWorkspaceOpenCoordinator = ExternalWorkspaceOpenCoordinator.shared
    @ObservedObject private var commandLineToolManager = MacCommandLineToolManager.shared
    @State private var hasAttemptedInitialFolderPrompt = false
    @State private var postInstallGuide: CommandLineToolPostInstallGuide?
    @Environment(\.openWindow) private var openWindow
    #else
    @State private var isPresentingFolderImporter = false
    #endif
    @Environment(\.scenePhase) private var scenePhase

    init(
        launchOptions: HarnessLaunchOptions,
        sceneID: String,
        sessionStore: WorkspaceWindowSessionStore,
        githubWorkspaceLoader: any GitHubWorkspaceLoading,
        updateChecker: AppUpdateChecker
    ) {
        self.sceneID = sceneID
        self.sessionStore = sessionStore
        self.updateChecker = updateChecker
        _model = StateObject(
            wrappedValue: AppModel(
                launchOptions: launchOptions,
                initialSession: sessionStore.claimLaunchSession(for: sceneID),
                githubWorkspaceLoader: githubWorkspaceLoader
            )
        )
    }

    var body: some View {
        ContentView(
            model: model,
            onOpenFolder: openFolderAction,
            onOpenGitHubURLPrompt: openGitHubURLPromptAction,
            onPrintSelectedDocument: printSelectedDocumentAction,
            onPrintAllDocuments: printAllDocumentsAction,
            onInstallCommandLineTool: installCommandLineToolAction,
            shouldShowCommandLineToolPrompt: shouldShowCommandLineToolPrompt
        )
            #if os(macOS)
            .focusedSceneValue(\.openFolderAction, OpenFolderAction(handler: openFolder))
            .focusedSceneValue(\.openGitHubURLAction, OpenGitHubURLAction(handler: openGitHubURLPrompt))
            .focusedSceneValue(\.revealInFinderAction, revealInFinderAction)
            .focusedSceneValue(\.printSelectedDocumentAction, printSelectedDocumentFocusedAction)
            .focusedSceneValue(\.printAllDocumentsAction, printAllDocumentsFocusedAction)
            .focusedSceneValue(\.increaseFontSizeAction, IncreaseFontSizeAction(handler: model.increaseFontSize))
            .focusedSceneValue(\.decreaseFontSizeAction, DecreaseFontSizeAction(handler: model.decreaseFontSize))
            .onAppear {
                sessionStore.scheduleAdditionalWindows(openWindow: openWindow)
                commandLineToolManager.setInstallCommandLineToolPresenter(installCommandLineTool)
                commandLineToolManager.refreshInstallState()
                handleExternalWorkspaceOpen(requestID: externalWorkspaceOpenCoordinator.latestRequestID)
                requestInitialFolderPromptIfNeeded()
            }
            .onDisappear {
                commandLineToolManager.setInstallCommandLineToolPresenter(nil)
                sessionStore.removeActiveSession(for: sceneID)
            }
            .onChange(of: externalWorkspaceOpenCoordinator.latestRequestID) { requestID in
                handleExternalWorkspaceOpen(requestID: requestID)
            }
            #endif
            .task {
                if !model.launchOptions.uiTestMode {
                    updateChecker.checkAutomaticallyIfNeeded()
                }
            }
            .onChange(of: model.selectedPath) { _ in
                sessionStore.updateActiveSession(model.restorationSession, for: sceneID)
            }
            .onChange(of: model.currentWorkspaceRootURL?.path) { _ in
                if isPresentingGitHubURLPrompt,
                   model.isLoadingWorkspace == false,
                   model.githubURLLoadErrorMessage == nil,
                   model.currentWorkspaceRootURL != nil {
                    isPresentingGitHubURLPrompt = false
                }
            }
            .onChange(of: model.windowTitle) { _ in
                sessionStore.updateActiveSession(model.restorationSession, for: sceneID)
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase != .active {
                    sessionStore.persistActiveSessions()
                } else {
                    if !model.launchOptions.uiTestMode {
                        updateChecker.checkAutomaticallyIfNeeded()
                    }
                    #if os(macOS)
                    commandLineToolManager.setInstallCommandLineToolPresenter(installCommandLineTool)
                    commandLineToolManager.refreshInstallState()
                    handleExternalWorkspaceOpen(requestID: externalWorkspaceOpenCoordinator.latestRequestID)
                    #endif
                }
            }
            #if os(macOS)
            .sheet(item: $postInstallGuide) { guide in
                CommandLineToolPostInstallSheet(
                    guide: guide,
                    onCopy: copyPostInstallCommandToPasteboard,
                    onDone: { postInstallGuide = nil }
                )
            }
            #endif
            .sheet(isPresented: $isPresentingGitHubURLPrompt) {
                GitHubURLPromptSheet(
                    model: model,
                    onClose: { isPresentingGitHubURLPrompt = false }
                )
            }
            .alert(
                updateChecker.activeAlert?.title ?? "Software Update",
                isPresented: updateAlertPresentedBinding,
                presenting: updateChecker.activeAlert
            ) { alert in
                updateAlertActions(for: alert)
            } message: { alert in
                Text(alert.message)
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

    private var openGitHubURLPromptAction: (() -> Void)? {
        openGitHubURLPrompt
    }

    private var updateAlertPresentedBinding: Binding<Bool> {
        Binding(
            get: { updateChecker.activeAlert != nil },
            set: { isPresented in
                if !isPresented {
                    updateChecker.dismissActiveAlert()
                }
            }
        )
    }

    private var printSelectedDocumentAction: (() -> Void)? {
        printSelectedDocument
    }

    private var printAllDocumentsAction: (() -> Void)? {
        printAllDocuments
    }

    private func printSelectedDocument() {
        Task {
            await presentPrint(scope: .selectedFile)
        }
    }

    private func printAllDocuments() {
        Task {
            await presentPrint(scope: .allFiles)
        }
    }

    @ViewBuilder
    private func updateAlertActions(for alert: AppUpdateChecker.AlertState) -> some View {
        switch alert.kind {
        case let .updateAvailable(info):
            Button("Download") {
                openUpdateStoreURL(info.storeURL)
            }
            Button("Skip") {
                updateChecker.dismissActiveAlert()
            }
            Button("Skip This Version") {
                updateChecker.skipActiveVersionUntilNextVersion()
            }
        case .upToDate, .failed:
            Button("OK") {
                updateChecker.dismissActiveAlert()
            }
        }
    }

    private func openUpdateStoreURL(_ url: URL) {
        updateChecker.dismissActiveAlert()
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    @MainActor
    private func presentPrint(scope: DocumentPrintScope) async {
        do {
            let composition = try await model.makePrintComposition(scope: scope)
            model.clearPrintError()
            model.recordPrintPresentationStarted(scope: scope)
            if model.launchOptions.uiTestMode {
                model.recordPrintPresentationSucceeded()
                return
            }
            #if os(macOS)
            PlatformPrintPresenter.present(composition, from: NSApp.keyWindow)
            #else
            PlatformPrintPresenter.present(composition)
            #endif
            model.recordPrintPresentationSucceeded()
        } catch {
            model.recordPrintError(error)
        }
    }

    #if os(macOS)
    private var installCommandLineToolAction: (() -> Void)? {
        installCommandLineTool
    }

    private var shouldShowCommandLineToolPrompt: Bool {
        commandLineToolManager.shouldOfferInstallPrompt
    }

    private var revealInFinderAction: RevealInFinderAction? {
        guard model.canRevealSelectedFileInFinder else { return nil }
        return RevealInFinderAction(handler: revealInFinder)
    }

    private var printSelectedDocumentFocusedAction: PrintSelectedDocumentAction? {
        guard model.canPrintSelectedDocument else { return nil }
        return PrintSelectedDocumentAction(handler: printSelectedDocument)
    }

    private var printAllDocumentsFocusedAction: PrintAllDocumentsAction? {
        guard model.canPrintAllDocuments else { return nil }
        return PrintAllDocumentsAction(handler: printAllDocuments)
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

    private func openGitHubURLPrompt() {
        isPresentingGitHubURLPrompt = true
    }

    private func installCommandLineTool() {
        commandLineToolManager.clearLastError()
        postInstallGuide = nil
        NSApp.activate(ignoringOtherApps: true)

        if let uiTestInstallURL = commandLineToolManager.pendingUITestInstallURL {
            completeInstallCommandLineTool(at: uiTestInstallURL)
            return
        }

        let installURL = commandLineToolManager.preferredInstallURL
        if completeInstallCommandLineTool(at: installURL, presentErrors: false) {
            return
        }

        guard commandLineToolManager.lastInstallFailureRequiresAccessGrant else {
            commandLineToolManager.presentLastInstallErrorIfNeeded()
            return
        }

        guard requestInstallCommandLineToolAccess() else {
            return
        }

        _ = completeInstallCommandLineTool(at: installURL, presentErrors: true)
    }

    @discardableResult
    private func completeInstallCommandLineTool(at installURL: URL, presentErrors: Bool = true) -> Bool {
        guard commandLineToolManager.installCommandLineTool(at: installURL, presentErrors: presentErrors) else {
            return false
        }

        let shellCommand = MacCommandLineToolManager.postInstallShellCommand()
        postInstallGuide = CommandLineToolPostInstallGuide(
            installURL: installURL,
            shellCommand: shellCommand ?? "Bundled setup script is missing from this app build.",
            isBundledScriptCommand: shellCommand != nil
        )
        return true
    }

    private func requestInstallCommandLineToolAccess() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Allow Access to Install `qmv`"
        alert.informativeText = "Quick Markdown Viewer always installs `qmv` to ~/.local/bin/qmv. macOS requires one-time access to your home folder so the app can create ~/.local/bin and write the launcher there."
        alert.addButton(withTitle: "Choose Home Folder")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return false
        }

        let panel = NSOpenPanel()
        panel.title = "Allow Access to Install `qmv`"
        panel.message = "Choose your home folder so Quick Markdown Viewer can create ~/.local/bin/qmv."
        panel.prompt = "Allow Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = commandLineToolManager.homeDirectoryURL

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return false
        }

        return commandLineToolManager.rememberHomeDirectoryAccess(from: selectedURL)
    }

    private func copyPostInstallCommandToPasteboard(_ command: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)
    }

    private func handleExternalWorkspaceOpen(requestID: UUID?) {
        guard let requestID, let request = externalWorkspaceOpenCoordinator.claimRequest(id: requestID) else {
            return
        }

        if shouldReuseCurrentWindowForExternalOpen {
            model.openFolder(at: request.rootURL, selectedPathOverride: request.selectedPath)
        } else {
            sessionStore.scheduleExternalWorkspaceWindow(
                for: WorkspaceWindowSession(
                    rootPath: request.rootURL.path,
                    selectedFile: request.selectedPath?.rawValue,
                    securityScopedBookmarkData: WorkspaceSecurityScope.bookmarkData(for: request.rootURL)
                ),
                openWindow: openWindow
            )
        }
    }

    private var shouldReuseCurrentWindowForExternalOpen: Bool {
        model.currentWorkspaceRootURL == nil && model.selectedPath == nil
    }

    private func revealInFinder() {
        guard let selectedFileURL = model.selectedFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selectedFileURL])
    }
    #else
    private var installCommandLineToolAction: (() -> Void)? {
        nil
    }

    private var shouldShowCommandLineToolPrompt: Bool {
        false
    }

    private func openFolder() {
        if model.launchOptions.uiTestMode, let testFolderURL = UITestOpenFolderSelectionStore.shared.nextFolderURL() {
            model.openFolder(at: testFolderURL)
            return
        }

        isPresentingFolderImporter = true
    }

    private func openGitHubURLPrompt() {
        isPresentingGitHubURLPrompt = true
    }

    private func handleFolderImport(_ result: Result<[URL], Error>) {
        guard case let .success(selectedURLs) = result, let selectedURL = selectedURLs.first else {
            return
        }
        model.openFolder(at: selectedURL)
    }
    #endif
}

private struct GitHubURLPromptSheet: View {
    @ObservedObject var model: AppModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Open GitHub URL")
                    .font(.title2.weight(.semibold))

                Text("Load a public GitHub repository root or tree URL and browse its Markdown files like a local folder.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                GitHubURLLoadForm(
                    model: model,
                    textFieldAccessibilityID: AccessibilityIDs.githubURLSheetField,
                    loadButtonAccessibilityID: AccessibilityIDs.githubURLSheetLoadButton,
                    errorAccessibilityID: AccessibilityIDs.githubURLSheetErrorMessage
                )

                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(minWidth: 420, minHeight: 220, alignment: .topLeading)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onClose()
                    }
                }
            }
        }
    }
}

#if os(macOS)
private struct CommandLineToolPostInstallGuide: Identifiable, Equatable {
    let installURL: URL
    let shellCommand: String
    let isBundledScriptCommand: Bool

    var id: String {
        installURL.path
    }
}

private struct CommandLineToolPostInstallSheet: View {
    let guide: CommandLineToolPostInstallGuide
    let onCopy: (String) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Finish Terminal Setup")
                .font(.title2.weight(.semibold))
                .accessibilityIdentifier(AccessibilityIDs.commandLineToolPostInstallTitle)

            Text(guide.isBundledScriptCommand ? "Run this short command in Terminal. It executes the setup script bundled inside Quick Markdown Viewer to add ~/.local/bin to PATH if needed, reload the right shell rc file, and verify `qmv` again." : "This app build is missing the bundled Terminal setup script.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(AccessibilityIDs.commandLineToolPostInstallMessage)

            ScrollView {
                Text(guide.shellCommand)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .frame(minHeight: 240)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .accessibilityIdentifier(AccessibilityIDs.commandLineToolPostInstallCommand)

            HStack {
                Spacer()
                Button("Copy Command") {
                    onCopy(guide.shellCommand)
                }
                .disabled(guide.isBundledScriptCommand == false)
                .accessibilityIdentifier(AccessibilityIDs.commandLineToolPostInstallCopyButton)

                Button("Done") {
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier(AccessibilityIDs.commandLineToolPostInstallDoneButton)
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 420)
    }
}

struct OpenFolderAction {
    let handler: () -> Void

    func callAsFunction() {
        handler()
    }
}

struct OpenGitHubURLAction {
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

struct PrintSelectedDocumentAction {
    let handler: () -> Void

    func callAsFunction() {
        handler()
    }
}

struct PrintAllDocumentsAction {
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

private struct OpenGitHubURLActionKey: FocusedValueKey {
    typealias Value = OpenGitHubURLAction
}

private struct RevealInFinderActionKey: FocusedValueKey {
    typealias Value = RevealInFinderAction
}

private struct PrintSelectedDocumentActionKey: FocusedValueKey {
    typealias Value = PrintSelectedDocumentAction
}

private struct PrintAllDocumentsActionKey: FocusedValueKey {
    typealias Value = PrintAllDocumentsAction
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

    var openGitHubURLAction: OpenGitHubURLAction? {
        get { self[OpenGitHubURLActionKey.self] }
        set { self[OpenGitHubURLActionKey.self] = newValue }
    }

    var revealInFinderAction: RevealInFinderAction? {
        get { self[RevealInFinderActionKey.self] }
        set { self[RevealInFinderActionKey.self] = newValue }
    }

    var printSelectedDocumentAction: PrintSelectedDocumentAction? {
        get { self[PrintSelectedDocumentActionKey.self] }
        set { self[PrintSelectedDocumentActionKey.self] = newValue }
    }

    var printAllDocumentsAction: PrintAllDocumentsAction? {
        get { self[PrintAllDocumentsActionKey.self] }
        set { self[PrintAllDocumentsActionKey.self] = newValue }
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
    @ObservedObject var commandLineToolManager: MacCommandLineToolManager
    @ObservedObject var updateChecker: AppUpdateChecker
    @FocusedValue(\.openFolderAction) private var openFolderAction
    @FocusedValue(\.openGitHubURLAction) private var openGitHubURLAction
    @FocusedValue(\.revealInFinderAction) private var revealInFinderAction
    @FocusedValue(\.printSelectedDocumentAction) private var printSelectedDocumentAction
    @FocusedValue(\.printAllDocumentsAction) private var printAllDocumentsAction
    @FocusedValue(\.increaseFontSizeAction) private var increaseFontSizeAction
    @FocusedValue(\.decreaseFontSizeAction) private var decreaseFontSizeAction

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                updateChecker.checkManually()
            }
            .disabled(updateChecker.isChecking)
        }

        CommandGroup(after: .newItem) {
            Divider()
            Button("Open Folder…") {
                openFolderAction?()
            }
            .keyboardShortcut("o", modifiers: [.command])
            .disabled(openFolderAction == nil)

            Button("Open GitHub URL…") {
                openGitHubURLAction?()
            }
            .keyboardShortcut("g", modifiers: [.command, .shift])
            .disabled(openGitHubURLAction == nil)

            Button("Show in Finder") {
                revealInFinderAction?()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(revealInFinderAction == nil)

            Divider()

            Button(commandLineToolManager.commandLineToolMenuTitle) {
                commandLineToolManager.performPrimaryCommandLineToolMenuAction()
            }
            .disabled(commandLineToolManager.canPerformCommandLineToolMenuAction == false)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print…") {
                printSelectedDocumentAction?()
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(printSelectedDocumentAction == nil)

            Button("Print All…") {
                printAllDocumentsAction?()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(printAllDocumentsAction == nil)
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
