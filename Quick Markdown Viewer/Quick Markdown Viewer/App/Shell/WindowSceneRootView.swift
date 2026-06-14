import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
enum MacSearchCommand: Equatable {
    case currentDocument
    case allDocuments
    case nextResult
}

@MainActor
enum MacSearchCommandDispatcher {
    private static var handlerID: UUID?
    private static var handler: ((MacSearchCommand) -> Void)?

    static func setHandler(id: UUID, _ handler: @escaping (MacSearchCommand) -> Void) {
        handlerID = id
        self.handler = handler
    }

    static func clearHandler(id: UUID) {
        guard handlerID == id else { return }
        handlerID = nil
        handler = nil
    }

    static func send(_ command: MacSearchCommand) {
        handler?(command)
    }
}
#endif

struct WindowSceneRootView: View {
    @StateObject private var model: AppModel
    @ObservedObject private var sessionStore: WorkspaceWindowSessionStore
    private let sceneID: String
    @State private var isPresentingGitHubURLPrompt = false
    @State private var printTask: Task<Void, Never>?
    #if os(macOS)
    @ObservedObject private var externalWorkspaceOpenCoordinator = ExternalWorkspaceOpenCoordinator.shared
    @ObservedObject private var commandLineToolManager = MacCommandLineToolManager.shared
    @State private var hasAttemptedInitialFolderPrompt = false
    @State private var initialFolderPromptTask: Task<Void, Never>?
    @State private var additionalWindowScheduleTask: Task<Void, Never>?
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
        githubWorkspaceLoader: any GitHubWorkspaceLoading
    ) {
        self.sceneID = sceneID
        self.sessionStore = sessionStore
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
            onCancelPrintPreparation: cancelPrintPreparationAction,
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
            .onDrop(of: [UTType.fileURL.identifier, UTType.url.identifier], isTargeted: nil) { providers in
                openDroppedWorkspaces(from: providers)
            }
            .onAppear {
                commandLineToolManager.setInstallCommandLineToolPresenter(installCommandLineTool)
                commandLineToolManager.refreshInstallState()
                handleExternalWorkspaceOpen(requestID: externalWorkspaceOpenCoordinator.latestRequestID)
                scheduleAdditionalWindowsIfNeeded()
                requestInitialFolderPromptIfNeeded()
            }
            .onDisappear {
                initialFolderPromptTask?.cancel()
                initialFolderPromptTask = nil
                additionalWindowScheduleTask?.cancel()
                additionalWindowScheduleTask = nil
                commandLineToolManager.setInstallCommandLineToolPresenter(nil)
                sessionStore.removeActiveSession(for: sceneID)
            }
            .onChange(of: externalWorkspaceOpenCoordinator.latestRequestID) { requestID in
                handleExternalWorkspaceOpen(requestID: requestID)
            }
            #endif
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

    private var printSelectedDocumentAction: (() -> Void)? {
        printSelectedDocument
    }

    private var printAllDocumentsAction: (() -> Void)? {
        printAllDocuments
    }

    private var cancelPrintPreparationAction: (() -> Void)? {
        guard model.isPreparingPrint else { return nil }
        return cancelPrintPreparation
    }

    private func printSelectedDocument() {
        startPrint(scope: .selectedFile)
    }

    private func printAllDocuments() {
        startPrint(scope: .allFiles)
    }

    private func startPrint(scope: DocumentPrintScope) {
        guard printTask == nil else { return }
        printTask = Task {
            await presentPrint(scope: scope)
            await MainActor.run {
                printTask = nil
            }
        }
    }

    private func cancelPrintPreparation() {
        printTask?.cancel()
        printTask = nil
        model.recordPrintCancelled()
    }

    @MainActor
    private func presentPrint(scope: DocumentPrintScope) async {
        do {
            let composition = try await model.makePrintComposition(scope: scope)
            try Task.checkCancellation()
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
        } catch is CancellationError {
            model.recordPrintCancelled(scope: scope)
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

    private func scheduleAdditionalWindowsIfNeeded() {
        guard additionalWindowScheduleTask == nil else { return }
        additionalWindowScheduleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            guard !externalWorkspaceOpenCoordinator.hasPendingRequests else { return }
            sessionStore.scheduleAdditionalWindows(openWindow: openWindow)
        }
    }

    private func requestInitialFolderPromptIfNeeded() {
        guard !hasAttemptedInitialFolderPrompt else { return }
        hasAttemptedInitialFolderPrompt = true

        if sessionStore.shouldSuppressAutomaticFolderPrompt(for: sceneID) {
            return
        }
        guard model.shouldAutoPromptForFolderOnLaunch else { return }

        initialFolderPromptTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            guard !externalWorkspaceOpenCoordinator.hasPendingRequests else { return }
            guard !sessionStore.shouldSuppressAutomaticFolderPrompt(for: sceneID) else { return }
            guard model.shouldAutoPromptForFolderOnLaunch else { return }
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

    private func openDroppedWorkspaces(from providers: [NSItemProvider]) -> Bool {
        var acceptedDrop = false

        for provider in providers {
            guard let typeIdentifier = droppedFileTypeIdentifier(for: provider) else { continue }
            acceptedDrop = true
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                guard error == nil,
                      let fileURL = ExternalWorkspaceOpenCoordinator.fileURL(fromDroppedItem: item),
                      let request = ExternalWorkspaceOpenCoordinator.normalizedRequest(
                        for: fileURL,
                        presentation: .newWindow
                      ) else {
                    return
                }
                Task { @MainActor in
                    ExternalWorkspaceOpenCoordinator.shared.enqueue(request)
                }
            }
        }

        if acceptedDrop {
            sessionStore.suppressAutomaticFolderPrompt(for: sceneID)
        }
        return acceptedDrop
    }

    private func droppedFileTypeIdentifier(for provider: NSItemProvider) -> String? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return UTType.fileURL.identifier
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            return UTType.url.identifier
        }
        return nil
    }

    private func handleExternalWorkspaceOpen(requestID: UUID?) {
        guard let requestID, let request = externalWorkspaceOpenCoordinator.claimRequest(id: requestID) else {
            return
        }
        sessionStore.suppressAutomaticFolderPrompt(for: sceneID)

        if request.presentation == .reuseEmptyWindow && shouldReuseCurrentWindowForExternalOpen {
            sessionStore.discardPendingAdditionalWindows()
            model.openFolder(
                at: request.rootURL,
                selectedPathOverride: request.selectedPath,
                explicitSelectedFileURL: request.explicitSelectedFileURL
            )
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
        if model.currentWorkspaceRootURL == nil && model.selectedPath == nil {
            return true
        }
        return sessionStore.canReplaceClaimedLaunchSession(for: sceneID)
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

struct SearchCurrentDocumentAction {
    let handler: () -> Void

    func callAsFunction() {
        handler()
    }
}

struct SearchAllDocumentsAction {
    let handler: () -> Void

    func callAsFunction() {
        handler()
    }
}

struct SelectNextSearchResultAction {
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

private struct SearchCurrentDocumentActionKey: FocusedValueKey {
    typealias Value = SearchCurrentDocumentAction
}

private struct SearchAllDocumentsActionKey: FocusedValueKey {
    typealias Value = SearchAllDocumentsAction
}

private struct SelectNextSearchResultActionKey: FocusedValueKey {
    typealias Value = SelectNextSearchResultAction
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

    var searchCurrentDocumentAction: SearchCurrentDocumentAction? {
        get { self[SearchCurrentDocumentActionKey.self] }
        set { self[SearchCurrentDocumentActionKey.self] = newValue }
    }

    var searchAllDocumentsAction: SearchAllDocumentsAction? {
        get { self[SearchAllDocumentsActionKey.self] }
        set { self[SearchAllDocumentsActionKey.self] = newValue }
    }

    var selectNextSearchResultAction: SelectNextSearchResultAction? {
        get { self[SelectNextSearchResultActionKey.self] }
        set { self[SelectNextSearchResultActionKey.self] = newValue }
    }
}

struct WindowOpenFolderCommands: Commands {
    @ObservedObject var commandLineToolManager: MacCommandLineToolManager
    @FocusedValue(\.openFolderAction) private var openFolderAction
    @FocusedValue(\.openGitHubURLAction) private var openGitHubURLAction
    @FocusedValue(\.revealInFinderAction) private var revealInFinderAction
    @FocusedValue(\.printSelectedDocumentAction) private var printSelectedDocumentAction
    @FocusedValue(\.printAllDocumentsAction) private var printAllDocumentsAction
    @FocusedValue(\.increaseFontSizeAction) private var increaseFontSizeAction
    @FocusedValue(\.decreaseFontSizeAction) private var decreaseFontSizeAction
    @FocusedValue(\.searchCurrentDocumentAction) private var searchCurrentDocumentAction
    @FocusedValue(\.searchAllDocumentsAction) private var searchAllDocumentsAction
    @FocusedValue(\.selectNextSearchResultAction) private var selectNextSearchResultAction

    var body: some Commands {
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

        CommandGroup(replacing: .textEditing) {
            Button("Find in Document") {
                searchCurrentDocumentAction?()
            }
            .keyboardShortcut("f", modifiers: [.command])
            .disabled(searchCurrentDocumentAction == nil)

            Button("Find in All Documents") {
                searchAllDocumentsAction?()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(searchAllDocumentsAction == nil)

            Button("Find Next") {
                selectNextSearchResultAction?()
            }
            .keyboardShortcut("g", modifiers: [.command])
            .disabled(selectNextSearchResultAction == nil)

            Divider()

            Button("Select All") {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: [.command])
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
