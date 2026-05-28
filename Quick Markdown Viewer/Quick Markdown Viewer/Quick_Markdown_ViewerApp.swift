//
//  Quick_Markdown_ViewerApp.swift
//  Quick Markdown Viewer
//
//  Created by Matthew Moore on 3/19/26.
//

import SwiftUI
#if os(macOS)
import AppKit
import Combine
import Darwin
#endif

@main
struct Quick_Markdown_ViewerApp: App {
    private let launchOptions: HarnessLaunchOptions
    private let githubWorkspaceLoader: GitHubWorkspaceService
    @StateObject private var sessionStore: WorkspaceWindowSessionStore
    @StateObject private var updateChecker = AppUpdateChecker()
    #if os(macOS)
    @NSApplicationDelegateAdaptor(QuickMarkdownViewerAppDelegate.self) private var appDelegate
    #endif

    init() {
        let resolvedLaunchOptions = HarnessLaunchOptions.fromProcess()
        launchOptions = resolvedLaunchOptions
        githubWorkspaceLoader = GitHubWorkspaceService.makeDefault(launchOptions: resolvedLaunchOptions)
        UITestOpenFolderSelectionStore.shared.configureIfNeeded(using: resolvedLaunchOptions)
        #if os(macOS)
        MacCommandLineToolManager.shared.configure(using: resolvedLaunchOptions)
        #endif
        _sessionStore = StateObject(
            wrappedValue: WorkspaceWindowSessionStore(launchOptions: resolvedLaunchOptions)
        )
        #if os(macOS)
        Self.installApplicationIcon()
        #endif
    }

    var body: some Scene {
        WindowGroup(for: String.self) { $sceneID in
            WindowSceneRootView(
                launchOptions: launchOptions,
                sceneID: sceneID,
                sessionStore: sessionStore,
                githubWorkspaceLoader: githubWorkspaceLoader,
                updateChecker: updateChecker
            )
        } defaultValue: {
            UUID().uuidString
        }
        #if os(macOS)
        .commands {
            WindowOpenFolderCommands(
                commandLineToolManager: MacCommandLineToolManager.shared,
                updateChecker: updateChecker
            )
        }
        #endif
    }

    #if os(macOS)
    private static func installApplicationIcon() {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = iconImage
            return
        }

        if let iconImage = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = iconImage
        }
    }
    #endif
}

#if os(macOS)
nonisolated enum ExternalWorkspaceOpenPresentation: Equatable {
    case reuseEmptyWindow
    case newWindow
}

@MainActor
final class ExternalWorkspaceOpenCoordinator: ObservableObject {
    static let shared = ExternalWorkspaceOpenCoordinator()

    @Published private(set) var latestRequestID: UUID?
    private var pendingRequests: [UUID: ExternalWorkspaceOpenRequest] = [:]

    func enqueue(_ request: ExternalWorkspaceOpenRequest) {
        let requestID = UUID()
        pendingRequests[requestID] = request
        latestRequestID = requestID
    }

    func claimRequest(id: UUID) -> ExternalWorkspaceOpenRequest? {
        pendingRequests.removeValue(forKey: id)
    }

    nonisolated static func normalizedRequest(
        for incomingURL: URL,
        presentation: ExternalWorkspaceOpenPresentation = .reuseEmptyWindow
    ) -> ExternalWorkspaceOpenRequest? {
        let resolvedURL = incomingURL.resolvingSymlinksInPath().standardizedFileURL
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return ExternalWorkspaceOpenRequest(
                rootURL: resolvedURL,
                selectedPath: nil,
                presentation: presentation
            )
        }
        guard SupportedDocumentExtensions.contains(resolvedURL.pathExtension) else { return nil }
        let rootURL = resolvedURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        return ExternalWorkspaceOpenRequest(
            rootURL: rootURL,
            selectedPath: WorkspacePath(rawValue: resolvedURL.lastPathComponent),
            presentation: presentation
        )
    }

    nonisolated static func fileURL(fromDroppedItem item: NSSecureCoding?) -> URL? {
        guard let item else { return nil }

        if let url = item as? URL {
            return standardizedFileURL(from: url)
        }
        if let data = item as? Data {
            if let url = URL(dataRepresentation: data, relativeTo: nil) {
                return standardizedFileURL(from: url)
            }
            if let value = String(data: data, encoding: .utf8) {
                return fileURL(fromDroppedString: value)
            }
        }
        if let value = item as? String {
            return fileURL(fromDroppedString: value)
        }
        return nil
    }

    private nonisolated static func fileURL(fromDroppedString value: String) -> URL? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmedValue), url.isFileURL {
            return standardizedFileURL(from: url)
        }
        guard trimmedValue.hasPrefix("/") else { return nil }
        return standardizedFileURL(from: URL(fileURLWithPath: trimmedValue))
    }

    private nonisolated static func standardizedFileURL(from url: URL) -> URL? {
        guard url.isFileURL else { return nil }
        return url.resolvingSymlinksInPath().standardizedFileURL
    }
}

nonisolated struct ExternalWorkspaceOpenRequest: Equatable {
    let rootURL: URL
    let selectedPath: WorkspacePath?
    let presentation: ExternalWorkspaceOpenPresentation

    init(
        rootURL: URL,
        selectedPath: WorkspacePath?,
        presentation: ExternalWorkspaceOpenPresentation = .reuseEmptyWindow
    ) {
        self.rootURL = rootURL
        self.selectedPath = selectedPath
        self.presentation = presentation
    }
}

final class QuickMarkdownViewerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MacSearchMenuController.shared.install()
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            guard let request = ExternalWorkspaceOpenCoordinator.normalizedRequest(for: url) else {
                continue
            }
            ExternalWorkspaceOpenCoordinator.shared.enqueue(request)
        }

        sender.reply(toOpenOrPrint: .success)
    }

    func application(
        _ application: NSApplication,
        printFiles filenames: [String],
        withSettings printSettings: [NSPrintInfo.AttributeKey: Any],
        showPrintPanels: Bool
    ) -> NSApplication.PrintReply {
        guard filenames.isEmpty == false else {
            return .printingFailure
        }

        let fileURLs = filenames.map(URL.init(fileURLWithPath:))
        Task { @MainActor in
            do {
                let composition = try await AppModel.makePrintComposition(forExternalPrintFileURLs: fileURLs)
                PlatformPrintPresenter.present(
                    composition,
                    from: application.keyWindow,
                    printInfo: PlatformPrintPresenter.printInfo(from: printSettings),
                    showsPrintPanel: showPrintPanels
                )
                application.reply(toOpenOrPrint: .success)
            } catch {
                application.reply(toOpenOrPrint: .failure)
            }
        }

        return .printingReplyLater
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let request = ExternalWorkspaceOpenCoordinator.normalizedRequest(for: url) else {
                continue
            }
            ExternalWorkspaceOpenCoordinator.shared.enqueue(request)
        }
    }
}

@MainActor
final class MacSearchMenuController: NSObject, NSMenuItemValidation {
    static let shared = MacSearchMenuController()
    private var keyMonitor: Any?

    private override init() {}

    func install() {
        installKeyMonitorIfNeeded()
        configureEditMenu()
        DispatchQueue.main.async { [weak self] in
            self?.configureEditMenu()
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(findInDocument(_:)),
             #selector(findInAllDocuments(_:)),
             #selector(findNext(_:)):
            return true
        default:
            return true
        }
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if let command = Self.command(for: event) {
                MacSearchCommandDispatcher.send(command)
                return nil
            }
            return event
        }
    }

    static func command(for event: NSEvent) -> MacSearchCommand? {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        guard modifiers.contains(.command),
              modifiers.isDisjoint(with: [.option, .control]),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return nil
        }

        if key == "f" {
            return modifiers.contains(.shift) ? .allDocuments : .currentDocument
        }

        guard key == "g", modifiers.contains(.shift) == false else { return nil }
        return .nextResult
    }

    @objc private func findInDocument(_ sender: NSMenuItem) {
        MacSearchCommandDispatcher.send(.currentDocument)
    }

    @objc private func findInAllDocuments(_ sender: NSMenuItem) {
        MacSearchCommandDispatcher.send(.allDocuments)
    }

    @objc private func findNext(_ sender: NSMenuItem) {
        MacSearchCommandDispatcher.send(.nextResult)
    }

    private func configureEditMenu() {
        guard let editMenu = NSApp.mainMenu?.item(withTitle: "Edit")?.submenu else { return }
        configureItem(
            in: editMenu,
            title: "Find in Document",
            keyEquivalent: "f",
            modifiers: [.command],
            action: #selector(findInDocument(_:))
        )
        configureItem(
            in: editMenu,
            title: "Find in All Documents",
            keyEquivalent: "f",
            modifiers: [.command, .shift],
            action: #selector(findInAllDocuments(_:))
        )
        configureItem(
            in: editMenu,
            title: "Find Next",
            keyEquivalent: "g",
            modifiers: [.command],
            action: #selector(findNext(_:))
        )
    }

    private func configureItem(
        in menu: NSMenu,
        title: String,
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags,
        action: Selector
    ) {
        let item = menu.items.first { $0.title == title } ?? insertedSearchItem(in: menu, title: title)
        item.target = self
        item.action = action
        item.keyEquivalent = keyEquivalent
        item.keyEquivalentModifierMask = modifiers
        item.isEnabled = true
    }

    private func insertedSearchItem(in menu: NSMenu, title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let insertionIndex = menu.items.firstIndex { $0.title == "Select All" }.map { $0 + 1 } ?? menu.items.count
        menu.insertItem(item, at: min(insertionIndex, menu.items.count))
        return item
    }
}

enum MacCommandLineToolInstallState: Equatable {
    case notInstalled(lastKnownURL: URL?)
    case installed(URL)
    case stale(URL)

    var installedURL: URL? {
        switch self {
        case let .installed(url), let .stale(url):
            return url
        case let .notInstalled(url):
            return url
        }
    }

    var isInstalled: Bool {
        if case .installed = self {
            return true
        }
        return false
    }

    var needsInstallPrompt: Bool {
        !isInstalled
    }

    var menuTitle: String {
        switch self {
        case .installed, .stale:
            return "Remove Command Line Tool…"
        case .notInstalled:
            return "Install Command Line Tool…"
        }
    }
}

@MainActor
final class MacCommandLineToolManager: ObservableObject {
    static let shared = MacCommandLineToolManager()

    nonisolated static let executableName = "qmv"
    nonisolated static let bundleIdentifier = "com.souschefstudio.Free-Markdown-Viewer"
    nonisolated static let installPathDefaultsKey = "macCommandLineToolInstallPath"
    nonisolated static let installDirectoryBookmarkDefaultsKey = "macCommandLineToolInstallDirectoryBookmark"
    nonisolated static let installExplanation = "Install `qmv` in ~/.local/bin to open folders from Terminal."

    @Published private(set) var installState: MacCommandLineToolInstallState
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastInstallFailureRequiresAccessGrant = false

    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private var uiTestInstallURL: URL?
    private var installCommandLineToolPresenter: (() -> Void)?

    init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        installState = Self.detectInstallState(
            storedURL: userDefaults.string(forKey: Self.installPathDefaultsKey).map(URL.init(fileURLWithPath:)),
            fileManager: fileManager
        )
    }

    func configure(using launchOptions: HarnessLaunchOptions) {
        if launchOptions.uiTestResetCommandLineToolInstallState {
            userDefaults.removeObject(forKey: Self.installPathDefaultsKey)
            userDefaults.removeObject(forKey: Self.installDirectoryBookmarkDefaultsKey)
            lastErrorMessage = nil
            lastInstallFailureRequiresAccessGrant = false
        }

        migrateInstallStateAwayFromSandboxHomeIfNeeded()

        if launchOptions.uiTestMode, let requestedURL = launchOptions.uiTestInstallCommandLineToolURL {
            uiTestInstallURL = fileManager.temporaryDirectory.appendingPathComponent(
                requestedURL.lastPathComponent,
                isDirectory: false
            )
        } else {
            uiTestInstallURL = launchOptions.uiTestInstallCommandLineToolURL
        }

        refreshInstallState()
    }

    var shouldOfferInstallPrompt: Bool {
        installState.needsInstallPrompt
    }

    func refreshInstallState() {
        installState = Self.detectInstallState(
            storedURL: storedInstallURL,
            fileManager: fileManager
        )
    }

    func clearLastError() {
        lastErrorMessage = nil
        lastInstallFailureRequiresAccessGrant = false
    }

    var pendingUITestInstallURL: URL? {
        uiTestInstallURL?.deletingPathExtensionIfNeeded
    }

    var canRequestInstallCommandLineTool: Bool {
        pendingUITestInstallURL != nil || installCommandLineToolPresenter != nil
    }

    var commandLineToolMenuTitle: String {
        installState.menuTitle
    }

    var canPerformCommandLineToolMenuAction: Bool {
        switch installState {
        case .installed, .stale:
            return true
        case .notInstalled:
            return canRequestInstallCommandLineTool
        }
    }

    var preferredInstallDirectoryURL: URL? {
        preferredInstallURL.deletingLastPathComponent()
    }

    var preferredInstallURL: URL {
        if let uiTestInstallURL {
            return uiTestInstallURL.deletingPathExtensionIfNeeded
        }
        return Self.defaultInstallURL(homeDirectory: resolvedUserHomeDirectoryURL)
    }

    var homeDirectoryURL: URL {
        resolvedUserHomeDirectoryURL
    }

    func setInstallCommandLineToolPresenter(_ presenter: (() -> Void)?) {
        installCommandLineToolPresenter = presenter
    }

    func requestInstallCommandLineTool() {
        installCommandLineToolPresenter?()
    }

    func performPrimaryCommandLineToolMenuAction() {
        switch installState {
        case .installed, .stale:
            removeCommandLineTool()
        case .notInstalled:
            requestInstallCommandLineTool()
        }
    }

    @discardableResult
    func installCommandLineTool(at installURL: URL, presentErrors: Bool = true) -> Bool {
        do {
            try withPreferredInstallDirectoryAccessIfAvailable(for: installURL) {
                try Self.writeCommandLineTool(to: installURL, fileManager: fileManager)
            }
            userDefaults.set(installURL.path, forKey: Self.installPathDefaultsKey)
        } catch {
            lastErrorMessage = Self.installFailureMessage(for: installURL, error: error)
            lastInstallFailureRequiresAccessGrant = Self.installFailureRequiresAccessGrant(error)
            if presentErrors {
                Self.presentInstallError(message: lastErrorMessage ?? "Couldn't install `qmv`.")
            }
            refreshInstallState()
            return false
        }
        lastInstallFailureRequiresAccessGrant = false
        refreshInstallState()
        return true
    }

    func presentLastInstallErrorIfNeeded() {
        guard let lastErrorMessage else { return }
        Self.presentInstallError(message: lastErrorMessage)
    }

    func rememberHomeDirectoryAccess(from selectedURL: URL) -> Bool {
        let standardizedSelection = selectedURL.resolvingSymlinksInPath().standardizedFileURL
        let standardizedHomeDirectory = homeDirectoryURL.resolvingSymlinksInPath().standardizedFileURL
        guard standardizedSelection == standardizedHomeDirectory else {
            lastErrorMessage = "Choose your home folder (\(standardizedHomeDirectory.path)) so Quick Markdown Viewer can create ~/.local/bin/qmv."
            lastInstallFailureRequiresAccessGrant = true
            Self.presentInstallError(message: lastErrorMessage ?? "Couldn't install `qmv`.")
            refreshInstallState()
            return false
        }

        guard let bookmarkData = Self.bookmarkData(for: standardizedSelection) else {
            lastErrorMessage = "Couldn't remember access to \(standardizedHomeDirectory.path)."
            lastInstallFailureRequiresAccessGrant = true
            Self.presentInstallError(message: lastErrorMessage ?? "Couldn't install `qmv`.")
            return false
        }

        userDefaults.set(bookmarkData, forKey: Self.installDirectoryBookmarkDefaultsKey)
        lastErrorMessage = nil
        lastInstallFailureRequiresAccessGrant = false
        return true
    }

    @discardableResult
    func removeCommandLineTool() -> Bool {
        guard let installURL = installState.installedURL else {
            refreshInstallState()
            return true
        }

        do {
            try withPreferredInstallDirectoryAccessIfAvailable(for: installURL) {
                try Self.removeCommandLineTool(at: installURL, fileManager: fileManager)
            }
        } catch {
            lastErrorMessage = Self.removeFailureMessage(for: installURL, error: error)
            Self.presentRemoveError(message: lastErrorMessage ?? "Couldn't remove `qmv`.")
            refreshInstallState()
            return false
        }

        refreshInstallState()
        return true
    }

    nonisolated static func installFailureMessage(for installURL: URL, error: Error) -> String {
        let nsError = error as NSError
        return "Couldn't install `qmv` at \(installURL.path): \(nsError.localizedDescription)"
    }

    nonisolated static func installFailureRequiresAccessGrant(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            return nsError.code == NSFileWriteNoPermissionError || nsError.code == NSFileReadNoPermissionError
        }
        if nsError.domain == NSPOSIXErrorDomain {
            return nsError.code == EACCES || nsError.code == EPERM
        }
        return false
    }

    nonisolated static func removeFailureMessage(for installURL: URL, error: Error) -> String {
        let nsError = error as NSError
        return "Couldn't remove `qmv` at \(installURL.path): \(nsError.localizedDescription)"
    }

    static func presentInstallError(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't install `qmv`"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    static func presentRemoveError(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't remove `qmv`"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    nonisolated static func launcherScript(bundleIdentifier: String = bundleIdentifier) -> String {
        """
        #!/bin/sh
        set -eu

        if [ "$#" -gt 1 ]; then
          echo "usage: qmv [directory-or-supported-file]" >&2
          exit 64
        fi

        target="${1:-.}"

        if [ -d "$target" ]; then
          resolved_target=$(cd "$target" && pwd -P)
        elif [ -f "$target" ]; then
          resolved_target="$(cd "$(dirname "$target")" && pwd -P)/$(basename "$target")"
        else
          echo "qmv: path not found: $target" >&2
          exit 66
        fi

        exec /usr/bin/open -b "\(bundleIdentifier)" "$resolved_target"
        """
    }

    nonisolated static func postInstallShellCommand(bundle: Bundle = commandLineToolResourceBundle) -> String? {
        guard let scriptURL = bundle.url(forResource: "qmv-finish-terminal-setup", withExtension: "sh") else {
            return nil
        }
        return postInstallShellCommand(scriptURL: scriptURL)
    }

    nonisolated static func postInstallShellCommand(scriptURL: URL) -> String {
        "/bin/sh \(shellSingleQuoted(scriptURL.path))"
    }

    nonisolated static func detectInstallState(
        storedURL: URL?,
        fileManager: FileManager = .default
    ) -> MacCommandLineToolInstallState {
        guard let storedURL else { return .notInstalled(lastKnownURL: nil) }
        guard fileManager.fileExists(atPath: storedURL.path) else {
            return .notInstalled(lastKnownURL: storedURL)
        }

        guard
            let contents = try? String(contentsOf: storedURL, encoding: .utf8),
            let attributes = try? fileManager.attributesOfItem(atPath: storedURL.path),
            let permissions = attributes[.posixPermissions] as? NSNumber
        else {
            return .stale(storedURL)
        }

        let isExecutable = permissions.intValue & 0o111 != 0
        let expectedContents = launcherScript()
        if contents == expectedContents, isExecutable {
            return .installed(storedURL)
        }
        return .stale(storedURL)
    }

    nonisolated static func writeCommandLineTool(
        to url: URL,
        fileManager: FileManager = .default
    ) throws {
        let scriptData = Data(launcherScript().utf8)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try scriptData.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    nonisolated static func removeCommandLineTool(
        at url: URL,
        fileManager: FileManager = .default
    ) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    nonisolated static func defaultInstallURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appendingPathComponent(".local", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent(executableName, isDirectory: false)
    }

    private var storedInstallURL: URL? {
        if let storedPath = userDefaults.string(forKey: Self.installPathDefaultsKey) {
            return URL(fileURLWithPath: storedPath)
        }
        return Self.defaultInstallURL(homeDirectory: resolvedUserHomeDirectoryURL)
    }

    private func withPreferredInstallDirectoryAccessIfAvailable<T>(
        for installURL: URL,
        operation: () throws -> T
    ) throws -> T {
        guard let accessURL = resolvedInstallDirectoryAccessURL(for: installURL) else {
            return try operation()
        }
        defer { accessURL.stopAccessingSecurityScopedResource() }
        return try operation()
    }

    private func resolvedInstallDirectoryAccessURL(for installURL: URL) -> URL? {
        guard installURL.path.hasPrefix(homeDirectoryURL.path + "/") else {
            return nil
        }
        guard let bookmarkData = userDefaults.data(forKey: Self.installDirectoryBookmarkDefaultsKey) else {
            return nil
        }
        return Self.resolvedSecurityScopedURL(from: bookmarkData)
    }

    private nonisolated static func bookmarkData(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private nonisolated static func shellSingleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private nonisolated static var commandLineToolResourceBundle: Bundle {
        Bundle(for: QuickMarkdownViewerAppDelegate.self)
    }

    private var resolvedUserHomeDirectoryURL: URL {
        Self.userHomeDirectoryURL(fileManager: fileManager)
    }

    private func migrateInstallStateAwayFromSandboxHomeIfNeeded() {
        let sandboxHomePath = fileManager.homeDirectoryForCurrentUser.path
        let actualHomePath = resolvedUserHomeDirectoryURL.path
        guard sandboxHomePath != actualHomePath else { return }

        if let storedPath = userDefaults.string(forKey: Self.installPathDefaultsKey),
           storedPath.hasPrefix(sandboxHomePath + "/") {
            let migratedPath = actualHomePath + String(storedPath.dropFirst(sandboxHomePath.count))
            userDefaults.set(migratedPath, forKey: Self.installPathDefaultsKey)
        }

        if let bookmarkData = userDefaults.data(forKey: Self.installDirectoryBookmarkDefaultsKey),
           let bookmarkURL = Self.resolvedSecurityScopedURL(from: bookmarkData) {
            defer { bookmarkURL.stopAccessingSecurityScopedResource() }
            if bookmarkURL.path == sandboxHomePath || bookmarkURL.path.hasPrefix(sandboxHomePath + "/") {
                userDefaults.removeObject(forKey: Self.installDirectoryBookmarkDefaultsKey)
            }
        }
    }

    private nonisolated static func userHomeDirectoryURL(fileManager: FileManager) -> URL {
        if let passwordEntry = getpwuid(getuid()), let homeDirectoryCString = passwordEntry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: homeDirectoryCString), isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser
    }

    private nonisolated static func resolvedSecurityScopedURL(from bookmarkData: Data) -> URL? {
        var isStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        guard resolvedURL.startAccessingSecurityScopedResource() else {
            return nil
        }
        return resolvedURL
    }
}

private extension URL {
    var deletingPathExtensionIfNeeded: URL {
        pathExtension.isEmpty ? self : deletingPathExtension()
    }
}
#endif
