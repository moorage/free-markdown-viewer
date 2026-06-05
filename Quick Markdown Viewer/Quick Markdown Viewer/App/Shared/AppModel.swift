import Combine
import Foundation
import ImageIO
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let minimumFontScale: CGFloat = 0.8
    static let maximumFontScale: CGFloat = 1.8
    private static let fontScaleStep: CGFloat = 0.1
    static let noWorkspacePromptMessage = "Open a folder of Markdown, CSV, or TSV files to get started."
    static let emptyWorkspaceMessage = "No Markdown, CSV, or TSV files found."

    @Published var githubURLInput = ""
    @Published private(set) var files: [MarkdownFileNode] = []
    @Published private(set) var documentText = "Loading…"
    @Published private(set) var documentBlocks: [MarkdownBlock] = []
    @Published private(set) var outlineItems: [MarkdownOutlineItem] = []
    @Published private(set) var selectedDocumentKind: WorkspaceDocumentKind = .markdown
    @Published private(set) var isLoadingDocument = false
    @Published private(set) var isLoadingWorkspace = false
    @Published private(set) var isPreparingPrint = false
    @Published private(set) var githubURLLoadErrorMessage: String?
    @Published private(set) var printErrorMessage: String?
    @Published private(set) var printPreparationMessage: String?
    @Published private(set) var lastPrintRequestScope: String?
    @Published private(set) var lastPrintRequestStatus: String?
    @Published var searchQuery = ""
    @Published private(set) var searchScope: DocumentSearchScope = .currentDocument
    @Published private(set) var searchResults: [DocumentSearchResult] = []
    @Published private(set) var selectedSearchResultID: String?
    @Published private(set) var isSearching = false
    @Published private(set) var searchActivationCounter = 0
    @Published private(set) var searchScrollTargetID: String?
    @Published private(set) var selectedPath: WorkspacePath?
    @Published private(set) var backStack: [NavigationEntry] = []
    @Published private(set) var forwardStack: [NavigationEntry] = []
    @Published private(set) var workspaceRootDisplay = "No Folder Open"
    @Published private(set) var workspaceIgnorePatterns: WorkspaceIgnorePatterns
    @Published private(set) var isReady = false
    @Published private(set) var fontScale: CGFloat = 1
    @Published private(set) var tabularPresentation = TabularDocumentPresentation()
    private(set) var viewportSize: CGSize = CGSize(width: 1100, height: 900)

    let launchOptions: HarnessLaunchOptions

    private let githubWorkspaceLoader: any GitHubWorkspaceLoading
    private let initialSession: WorkspaceWindowSession?
    private let startReference = Date()
    private var readyReference = Date()
    private var bootstrapTask: Task<Void, Never>?
    private var workspaceLoadTask: Task<Void, Never>?
    private var documentLoadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var commandServer: HarnessCommandServer?
    private var didWriteLaunchArtifacts = false
    private var workspaceProvider: (any WorkspaceProvider)?
    private var workspaceRootURL: URL?
    private var screenshotWriter: ((URL) throws -> Void)?
    private var activeDocumentRequestID: UUID?
    private var hasResolvedWorkspaceSelection = false
    private var workspaceRootBookmarkData: Data?
    private var activeSecurityScopedWorkspaceURL: URL?
    private var currentRestorationSession: WorkspaceWindowSession?
    private var shouldAllowRevealInFinder = false
    private var pendingSearchScrollTargetID: String?

    init(
        launchOptions: HarnessLaunchOptions,
        initialSession: WorkspaceWindowSession? = nil,
        githubWorkspaceLoader: any GitHubWorkspaceLoading = GitHubWorkspaceService.live()
    ) {
        self.launchOptions = launchOptions
        self.initialSession = initialSession
        self.githubWorkspaceLoader = githubWorkspaceLoader
        self.workspaceIgnorePatterns = initialSession?.ignorePatterns ?? .default
    }

    deinit {
        activeSecurityScopedWorkspaceURL?.stopAccessingSecurityScopedResource()
    }

    var canNavigateBack: Bool {
        !backStack.isEmpty
    }

    var canNavigateForward: Bool {
        !forwardStack.isEmpty
    }

    var selectedFileDisplayName: String {
        selectedPath?.rawValue.split(separator: "/").last.map(String.init) ?? "No file selected"
    }

    var windowTitle: String {
        guard selectedPath != nil else { return workspaceRootDisplay }
        return "\(workspaceRootDisplay) > \(selectedFileDisplayName)"
    }

    var selectedFileURL: URL? {
        guard let workspaceRootURL, let selectedPath else { return nil }
        return workspaceRootURL.appendingPathComponent(selectedPath.rawValue).standardizedFileURL
    }

    var canRevealSelectedFileInFinder: Bool {
        shouldAllowRevealInFinder && selectedFileURL != nil
    }

    var currentWorkspaceRootURL: URL? {
        workspaceRootURL
    }

    var shouldRenderBlockContent: Bool {
        Self.shouldRenderStructuredContent(for: documentBlocks)
    }

    var shouldShowTabularControls: Bool {
        selectedDocumentKind.isDelimitedText
    }

    var shouldShowOpenFolderPromptState: Bool {
        workspaceRootURL == nil &&
        files.isEmpty &&
        documentText == Self.noWorkspacePromptMessage
    }

    var shouldShowEmptyWorkspaceState: Bool {
        workspaceRootURL != nil &&
        files.isEmpty &&
        documentText == Self.emptyWorkspaceMessage
    }

    var shouldAutoPromptForFolderOnLaunch: Bool {
        guard initialSession == nil else { return false }
        guard !launchOptions.uiTestMode else { return false }
        guard launchOptions.fixtureRoot == nil else { return false }
        guard launchOptions.openFile == nil else { return false }
        guard launchOptions.commandDirectoryURL == nil else { return false }
        guard launchOptions.dumpVisibleStateURL == nil else { return false }
        guard launchOptions.dumpPerfStateURL == nil else { return false }
        guard launchOptions.screenshotPathURL == nil else { return false }
        return true
    }

    var canIncreaseFontSize: Bool {
        fontScale < Self.maximumFontScale
    }

    var canDecreaseFontSize: Bool {
        fontScale > Self.minimumFontScale
    }

    var canIncreaseColumnWidth: Bool {
        tabularPresentation.columnWidth < TabularDocumentPresentation.maximumColumnWidth
    }

    var canDecreaseColumnWidth: Bool {
        tabularPresentation.columnWidth > TabularDocumentPresentation.minimumColumnWidth
    }

    var canIncreaseRowHeight: Bool {
        tabularPresentation.rowHeight < TabularDocumentPresentation.maximumRowHeight
    }

    var canDecreaseRowHeight: Bool {
        tabularPresentation.rowHeight > TabularDocumentPresentation.minimumRowHeight
    }

    var canPrintSelectedDocument: Bool {
        selectedPath != nil && isPreparingPrint == false
    }

    var canPrintAllDocuments: Bool {
        files.isEmpty == false && isPreparingPrint == false
    }

    var shouldPreferDetailInCompactNavigation: Bool {
        launchOptions.platformTarget == .ios &&
        launchOptions.deviceClass == .iphone &&
        selectedPath != nil
    }

    static var preview: AppModel {
        let model = AppModel(launchOptions: HarnessLaunchOptions.fromProcess(arguments: ["Preview"]))
        model.files = EmbeddedFixtures.docs.keys.sorted().map {
            MarkdownFileNode(path: WorkspacePath(rawValue: $0), name: $0, kind: WorkspaceDocumentKind.forPath($0) ?? .markdown)
        }
        model.selectedPath = WorkspacePath(rawValue: "basic_typography.md")
        model.selectedDocumentKind = .markdown
        model.documentText = EmbeddedFixtures.docs["basic_typography.md"] ?? ""
        model.documentBlocks = MarkdownRenderer.blocks(from: model.documentText)
        model.outlineItems = outlineItems(from: model.documentBlocks)
        model.workspaceRootDisplay = "Fixtures/docs"
        model.workspaceRootURL = nil
        model.currentRestorationSession = nil
        model.shouldAllowRevealInFinder = false
        model.isReady = true
        return model
    }

    var restorationSession: WorkspaceWindowSession? {
        guard let currentRestorationSession else { return nil }
        return WorkspaceWindowSession(
            source: currentRestorationSession.source,
            selectedFile: selectedPath?.rawValue,
            ignorePatterns: workspaceIgnorePatterns
        )
    }

    var workspaceIgnorePatternText: String {
        workspaceIgnorePatterns.commaSeparated
    }

    func bootstrap() {
        guard bootstrapTask == nil else { return }
        bootstrapTask = Task { [weak self] in
            await self?.loadWorkspace()
        }
    }

    func installScreenshotWriter(_ writer: @escaping (URL) throws -> Void) {
        screenshotWriter = writer
    }

    func resolvedDocumentLinkAction(for url: URL) -> DocumentLinkAction {
        if let targetPath = resolveMarkdownLinkTarget(url),
           files.contains(where: { $0.path == targetPath }) {
            return .markdown(targetPath)
        }

        if let mediaTarget = resolveMediaLinkTarget(url) {
            return .media(mediaTarget)
        }

        return .external(resolvedExternalURL(for: url) ?? url)
    }

    func openMarkdownLink(_ url: URL) -> Bool {
        guard case let .markdown(targetPath) = resolvedDocumentLinkAction(for: url) else { return false }
        openFile(targetPath)
        return true
    }

    func updateViewport(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard viewportSize != size else { return }
        viewportSize = size
    }

    func increaseFontSize() {
        setFontScale(fontScale + Self.fontScaleStep)
    }

    func decreaseFontSize() {
        setFontScale(fontScale - Self.fontScaleStep)
    }

    func toggleTabularWrapMode() {
        tabularPresentation.toggleWrapMode()
    }

    func increaseColumnWidth() {
        tabularPresentation.increaseColumnWidth()
    }

    func decreaseColumnWidth() {
        tabularPresentation.decreaseColumnWidth()
    }

    func increaseRowHeight() {
        tabularPresentation.increaseRowHeight()
    }

    func decreaseRowHeight() {
        tabularPresentation.decreaseRowHeight()
    }

    func openFile(_ path: WorkspacePath, recordHistory: Bool = true) {
        guard let workspaceProvider else { return }
        cancelActiveDocumentLoad()
        if recordHistory, let selectedPath, selectedPath != path {
            backStack.append(NavigationEntry(filePath: selectedPath, scrollPosition: nil))
            forwardStack.removeAll()
        }
        selectedPath = path
        selectedDocumentKind = files.first(where: { $0.path == path })?.kind ?? WorkspaceDocumentKind.forPath(path.rawValue) ?? .markdown
        isLoadingDocument = true
        printErrorMessage = nil

        let requestID = UUID()
        activeDocumentRequestID = requestID
        documentLoadTask = Task { [weak self] in
            guard let self else { return }
            let outcome = await Self.loadDocument(provider: workspaceProvider, path: path)
            guard !Task.isCancelled else { return }
            guard self.activeDocumentRequestID == requestID else { return }

            self.documentText = outcome.text
            self.documentBlocks = outcome.blocks
            self.outlineItems = outcome.outlineItems
            self.selectedDocumentKind = outcome.kind
            self.isLoadingDocument = false
            self.isReady = true
            self.readyReference = Date()
            if let pendingSearchScrollTargetID = self.pendingSearchScrollTargetID {
                self.searchScrollTargetID = pendingSearchScrollTargetID
                self.pendingSearchScrollTargetID = nil
            }
            if self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                self.runSearch()
            }
            self.documentLoadTask = nil
        }
    }

    private func setFontScale(_ proposedScale: CGFloat) {
        let clampedScale = min(max(proposedScale, Self.minimumFontScale), Self.maximumFontScale)
        let roundedScale = (clampedScale * 10).rounded() / 10
        guard roundedScale != fontScale else { return }
        fontScale = roundedScale
    }

    func navigateBack() {
        guard let entry = backStack.popLast() else { return }
        if let selectedPath {
            forwardStack.append(NavigationEntry(filePath: selectedPath, scrollPosition: nil))
        }
        openFile(entry.filePath, recordHistory: false)
    }

    func navigateForward() {
        guard let entry = forwardStack.popLast() else { return }
        if let selectedPath {
            backStack.append(NavigationEntry(filePath: selectedPath, scrollPosition: nil))
        }
        openFile(entry.filePath, recordHistory: false)
    }

    func selectAdjacentFile(offset: Int) {
        guard let targetPath = Self.adjacentFilePath(
            from: selectedPath,
            within: files,
            offset: offset
        ) else {
            return
        }

        openFile(targetPath, recordHistory: selectedPath != nil)
    }

    func openFolder(
        at rootURL: URL,
        selectedPathOverride: WorkspacePath? = nil,
        explicitSelectedFileURL: URL? = nil
    ) {
        cancelActiveDocumentLoad()
        cancelActiveWorkspaceLoad()
        loadWorkspace(
            selection: WorkspaceSecurityScope.selection(for: rootURL),
            selectedPathOverride: selectedPathOverride,
            explicitSelectedFileURL: explicitSelectedFileURL
        )
    }

    func updateWorkspaceIgnorePatterns(from commaSeparatedPatterns: String) {
        let updatedPatterns = WorkspaceIgnorePatterns(commaSeparated: commaSeparatedPatterns)
        guard updatedPatterns != workspaceIgnorePatterns else { return }
        workspaceIgnorePatterns = updatedPatterns
        reloadCurrentWorkspaceAfterIgnoreChange()
    }

    func resetWorkspaceIgnorePatterns() {
        updateWorkspaceIgnorePatterns(from: WorkspaceIgnorePatterns.default.commaSeparated)
    }

    func submitGitHubURLFromInput() {
        openGitHubWorkspace(from: githubURLInput)
    }

    func openGitHubWorkspace(from rawURLString: String) {
        openGitHubWorkspace(from: rawURLString, selectedPathOverride: nil)
    }

    private func openGitHubWorkspace(
        from rawURLString: String,
        selectedPathOverride: WorkspacePath?
    ) {
        let trimmedURL = rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            githubURLLoadErrorMessage = "Enter a GitHub repository URL."
            return
        }

        cancelActiveWorkspaceLoad()
        githubURLInput = trimmedURL
        githubURLLoadErrorMessage = nil
        isLoadingWorkspace = true

        workspaceLoadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let cachedWorkspace = try await githubWorkspaceLoader.loadWorkspace(from: trimmedURL)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.loadGitHubWorkspace(cachedWorkspace, selectedPathOverride: selectedPathOverride)
                    self.isLoadingWorkspace = false
                    self.workspaceLoadTask = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.githubURLLoadErrorMessage = error.localizedDescription
                    self.isLoadingWorkspace = false
                    self.workspaceLoadTask = nil
                }
            }
        }
    }

    func fulfillLaunchArtifactRequestsIfNeeded() {
        guard isReady, !didWriteLaunchArtifacts else { return }
        didWriteLaunchArtifacts = true
        if let url = launchOptions.dumpVisibleStateURL {
            try? writeStateSnapshot(to: url)
        }
        if let url = launchOptions.dumpPerfStateURL {
            try? writePerformanceSnapshot(to: url)
        }
        if let url = launchOptions.screenshotPathURL {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let delayNanoseconds: UInt64 = launchOptions.platformTarget == .macos ? 350_000_000 : 150_000_000
                try? await Task.sleep(nanoseconds: delayNanoseconds)
                try? screenshotWriter?(url)
            }
        }
    }

    func handleCommand(_ request: HarnessCommandRequest) async -> HarnessCommandResponse {
        switch request.command {
        case "openFile":
            if let path = request.arguments?["path"] {
                openFile(WorkspacePath(rawValue: path))
                return HarnessCommandResponse(id: request.id, status: "ok", result: ["selectedFile": path], error: nil)
            }
            return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: "missing path")
        case "dumpState":
            if let path = request.arguments?["path"] {
                do {
                    try writeStateSnapshot(to: URL(fileURLWithPath: path))
                    return HarnessCommandResponse(id: request.id, status: "ok", result: ["path": path], error: nil)
                } catch {
                    return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: error.localizedDescription)
                }
            }
            return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: "missing path")
        case "dumpPerf":
            if let path = request.arguments?["path"] {
                do {
                    try writePerformanceSnapshot(to: URL(fileURLWithPath: path))
                    return HarnessCommandResponse(id: request.id, status: "ok", result: ["path": path], error: nil)
                } catch {
                    return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: error.localizedDescription)
                }
            }
            return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: "missing path")
        case "captureWindow":
            if let path = request.arguments?["path"] {
                do {
                    try screenshotWriter?(URL(fileURLWithPath: path))
                    return HarnessCommandResponse(id: request.id, status: "ok", result: ["path": path], error: nil)
                } catch {
                    return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: error.localizedDescription)
                }
            }
            return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: "missing path")
        case "printSelectedDocument":
            guard let path = request.arguments?["path"] else {
                return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: "missing path")
            }
            do {
                let composition = try await makePrintComposition(scope: .selectedFile)
                let destinationURL = URL(fileURLWithPath: path)
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try composition.plainText.write(to: destinationURL, atomically: true, encoding: .utf8)
                return HarnessCommandResponse(id: request.id, status: "ok", result: ["path": path], error: nil)
            } catch {
                return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: error.localizedDescription)
            }
        case "printAllDocuments":
            guard let path = request.arguments?["path"] else {
                return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: "missing path")
            }
            do {
                let composition = try await makePrintComposition(scope: .allFiles)
                let destinationURL = URL(fileURLWithPath: path)
                try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try composition.plainText.write(to: destinationURL, atomically: true, encoding: .utf8)
                return HarnessCommandResponse(id: request.id, status: "ok", result: ["path": path], error: nil)
            } catch {
                return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: error.localizedDescription)
            }
        case "exportPrintedDocument":
            guard let path = request.arguments?["path"] else {
                return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: "missing path")
            }
            do {
                let composition = try await makePrintComposition(scope: .selectedFile)
                let destinationURL = URL(fileURLWithPath: path)
                try await exportPrintPDF(composition, to: destinationURL)
                return HarnessCommandResponse(id: request.id, status: "ok", result: ["path": path], error: nil)
            } catch {
                return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: error.localizedDescription)
            }
        case "exportPrintedAllDocuments":
            guard let path = request.arguments?["path"] else {
                return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: "missing path")
            }
            do {
                let composition = try await makePrintComposition(scope: .allFiles)
                let destinationURL = URL(fileURLWithPath: path)
                try await exportPrintPDF(composition, to: destinationURL)
                return HarnessCommandResponse(id: request.id, status: "ok", result: ["path": path], error: nil)
            } catch {
                return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: error.localizedDescription)
            }
        case "readLastPrintRequest":
            return HarnessCommandResponse(
                id: request.id,
                status: "ok",
                result: [
                    "scope": lastPrintRequestScope ?? "",
                    "status": lastPrintRequestStatus ?? ""
                ],
                error: nil
            )
        case "openWorkspace", "setWindowSize", "scrollToY", "scrollToBlock", "playMedia", "pauseMedia":
            return HarnessCommandResponse(id: request.id, status: "ok", result: request.arguments, error: nil)
        default:
            return HarnessCommandResponse(id: request.id, status: "error", result: nil, error: "unsupported command")
        }
    }

    func stateSnapshot() -> HarnessStateSnapshot {
        let flattenedBlocks = flattenVisibleBlocks(from: documentBlocks)
        return HarnessStateSnapshot(
            platform: launchOptions.platformTarget.rawValue,
            deviceClass: launchOptions.deviceClass.rawValue,
            workspaceRoot: workspaceRootDisplay,
            selectedFile: selectedPath?.rawValue,
            history: NavigationHistorySnapshot(backCount: backStack.count, forwardCount: forwardStack.count),
            viewport: ViewportSnapshot(x: 0, y: 0, width: viewportSize.width, height: viewportSize.height),
            visibleBlocks: flattenedBlocks.map { block in
                VisibleBlockSnapshot(
                    id: block.id,
                    kind: block.kind.rawValue,
                    text: block.plainText
                )
            },
            sidebar: SidebarSnapshot(selectedNode: selectedPath?.rawValue)
        )
    }

    func performanceSnapshot() -> HarnessPerformanceSnapshot {
        let flattenedBlocks = flattenVisibleBlocks(from: documentBlocks)
        return HarnessPerformanceSnapshot(
            platform: launchOptions.platformTarget.rawValue,
            deviceClass: launchOptions.deviceClass.rawValue,
            launchTime: 0,
            readyTime: readyReference.timeIntervalSince(startReference),
            visibleBlockCount: flattenedBlocks.count,
            activeAnimatedMediaCount: flattenedBlocks.filter { $0.kind == .animatedImage }.count,
            activeVideoPlayerCount: flattenedBlocks.filter { $0.kind == .video }.count
        )
    }

    private func loadWorkspace() async {
        if !hasResolvedWorkspaceSelection {
            let restoredSelectedPath = initialSession?.selectedFile.map(WorkspacePath.init(rawValue:))
            if let initialSession {
                switch initialSession.source {
                case .local:
                    loadWorkspace(
                        selection: WorkspaceSecurityScope.selection(for: initialSession),
                        selectedPathOverride: restoredSelectedPath
                    )
                case let .github(remoteSource):
                    loadGitHubWorkspaceFromSession(
                        remoteSource,
                        selectedPathOverride: restoredSelectedPath
                    )
                }
            } else if launchOptions.fixtureRoot != nil {
                loadWorkspace(
                    selection: WorkspaceAccessSelection(
                        rootURL: launchOptions.fixtureRoot,
                        bookmarkData: nil,
                        activeSecurityScopedURL: nil
                    ),
                    selectedPathOverride: restoredSelectedPath
                )
            } else {
                showNoWorkspaceSelectedState()
            }
        }

        if commandServer == nil, let commandDirectoryURL = launchOptions.commandDirectoryURL {
            let server = HarnessCommandServer(directoryURL: commandDirectoryURL)
            commandServer = server
            server.start(model: self)
        }
    }

    private func loadWorkspace(
        selection: WorkspaceAccessSelection,
        selectedPathOverride: WorkspacePath? = nil,
        explicitSelectedFileURL: URL? = nil
    ) {
        replaceActiveSecurityScopedWorkspace(with: selection.activeSecurityScopedURL)
        cancelActiveWorkspaceLoad()
        loadWorkspace(
            from: selection.rootURL,
            selectedPathOverride: selectedPathOverride,
            rootBookmarkData: selection.bookmarkData,
            explicitSelectedFileURL: explicitSelectedFileURL
        )
    }

    private func loadWorkspace(
        from rootURL: URL?,
        selectedPathOverride: WorkspacePath? = nil,
        rootBookmarkData: Data? = nil,
        explicitSelectedFileURL: URL? = nil
    ) {
        cancelActiveDocumentLoad()
        githubURLLoadErrorMessage = nil
        hasResolvedWorkspaceSelection = true
        let provider = LocalWorkspaceProvider(
            rootURL: rootURL,
            explicitFileURL: explicitSelectedFileURL,
            embeddedDocs: EmbeddedFixtures.docs,
            ignorePatterns: workspaceIgnorePatterns
        )
        workspaceProvider = provider
        workspaceRootURL = rootURL
        workspaceRootBookmarkData = rootBookmarkData
        shouldAllowRevealInFinder = rootURL != nil
        currentRestorationSession = rootURL.map {
            WorkspaceWindowSession(
                rootPath: $0.path,
                selectedFile: selectedPathOverride?.rawValue,
                securityScopedBookmarkData: rootBookmarkData,
                ignorePatterns: workspaceIgnorePatterns
            )
        }
        do {
            let workspace = try provider.loadRoot()
            files = workspace.files
            workspaceRootDisplay = workspace.rootIdentifier
            let initialPath: WorkspacePath?
            if let selectedPathOverride,
               workspace.files.contains(where: { $0.path == selectedPathOverride }) {
                initialPath = selectedPathOverride
            } else if rootURL == launchOptions.fixtureRoot {
                initialPath = launchOptions.openFile.flatMap { WorkspacePath(rawValue: $0) } ?? workspace.files.first?.path
            } else {
                initialPath = workspace.files.first?.path
            }
            backStack.removeAll()
            forwardStack.removeAll()
            if let initialPath {
                openFile(initialPath, recordHistory: false)
            } else {
                selectedPath = nil
                selectedDocumentKind = .markdown
                documentText = Self.emptyWorkspaceMessage
                documentBlocks = MarkdownRenderer.blocks(from: documentText)
                outlineItems = []
                isLoadingDocument = false
                isReady = true
                readyReference = Date()
            }
        } catch {
            files = []
            selectedPath = nil
            selectedDocumentKind = .markdown
            workspaceRootURL = nil
            workspaceRootBookmarkData = nil
            shouldAllowRevealInFinder = false
            currentRestorationSession = nil
            documentText = "Unable to load workspace: \(error.localizedDescription)"
            documentBlocks = MarkdownRenderer.blocks(from: documentText)
            outlineItems = []
            isLoadingDocument = false
            isReady = true
            readyReference = Date()
        }
    }

    private func loadGitHubWorkspaceFromSession(
        _ sessionSource: GitHubWorkspaceSessionSource,
        selectedPathOverride: WorkspacePath?
    ) {
        let cacheRootURL = URL(fileURLWithPath: sessionSource.cachedRootPath, isDirectory: true)
        if FileManager.default.fileExists(atPath: cacheRootURL.path) {
            loadGitHubWorkspace(
                CachedGitHubWorkspace(
                    descriptor: sessionSource.descriptor,
                    cacheRootURL: cacheRootURL
                ),
                selectedPathOverride: selectedPathOverride
            )
            return
        }

        openGitHubWorkspace(from: sessionSource.originalURLString, selectedPathOverride: selectedPathOverride)
    }

    private func loadGitHubWorkspace(
        _ cachedWorkspace: CachedGitHubWorkspace,
        selectedPathOverride: WorkspacePath?
    ) {
        cancelActiveDocumentLoad()
        hasResolvedWorkspaceSelection = true
        replaceActiveSecurityScopedWorkspace(with: nil)
        workspaceRootBookmarkData = nil
        workspaceRootURL = cachedWorkspace.cacheRootURL
        workspaceProvider = GitHubWorkspaceProvider(
            cachedRootURL: cachedWorkspace.cacheRootURL,
            descriptor: cachedWorkspace.descriptor,
            ignorePatterns: workspaceIgnorePatterns
        )
        workspaceRootDisplay = cachedWorkspace.descriptor.displayRoot
        shouldAllowRevealInFinder = false
        currentRestorationSession = WorkspaceWindowSession(
            source: .github(
                GitHubWorkspaceSessionSource(
                    originalURLString: cachedWorkspace.descriptor.originalURLString,
                    cachedRootPath: cachedWorkspace.cacheRootURL.path,
                    descriptor: cachedWorkspace.descriptor
                )
            ),
            selectedFile: selectedPathOverride?.rawValue,
            ignorePatterns: workspaceIgnorePatterns
        )
        githubURLLoadErrorMessage = nil

        do {
            let workspace = try workspaceProvider?.loadRoot()
            files = workspace?.files ?? []
            let initialPath: WorkspacePath?
            if let selectedPathOverride,
               files.contains(where: { $0.path == selectedPathOverride }) {
                initialPath = selectedPathOverride
            } else {
                initialPath = files.first?.path
            }
            backStack.removeAll()
            forwardStack.removeAll()
            if let initialPath {
                openFile(initialPath, recordHistory: false)
            } else {
                selectedPath = nil
                selectedDocumentKind = .markdown
                documentText = Self.emptyWorkspaceMessage
                documentBlocks = MarkdownRenderer.blocks(from: documentText)
                outlineItems = []
                isLoadingDocument = false
                isReady = true
                readyReference = Date()
            }
        } catch {
            files = []
            selectedPath = nil
            selectedDocumentKind = .markdown
            workspaceRootURL = nil
            shouldAllowRevealInFinder = false
            currentRestorationSession = nil
            documentText = "Unable to load workspace: \(error.localizedDescription)"
            documentBlocks = MarkdownRenderer.blocks(from: documentText)
            outlineItems = []
            isLoadingDocument = false
            isReady = true
            readyReference = Date()
        }
    }

    private func showNoWorkspaceSelectedState() {
        cancelActiveDocumentLoad()
        cancelActiveWorkspaceLoad()
        replaceActiveSecurityScopedWorkspace(with: nil)
        hasResolvedWorkspaceSelection = true
        workspaceProvider = nil
        workspaceRootURL = nil
        workspaceRootBookmarkData = nil
        currentRestorationSession = nil
        shouldAllowRevealInFinder = false
        files = []
        selectedPath = nil
        selectedDocumentKind = .markdown
        backStack.removeAll()
        forwardStack.removeAll()
        githubURLLoadErrorMessage = nil
        documentText = Self.noWorkspacePromptMessage
        documentBlocks = []
        outlineItems = []
        isLoadingDocument = false
        isReady = true
        readyReference = Date()
    }

    private func reloadCurrentWorkspaceAfterIgnoreChange() {
        let selectedPathOverride = selectedPath
        if let currentRestorationSession {
            switch currentRestorationSession.source {
            case let .local(rootPath, bookmarkData):
                loadWorkspace(
                    from: URL(fileURLWithPath: rootPath, isDirectory: true),
                    selectedPathOverride: selectedPathOverride,
                    rootBookmarkData: bookmarkData
                )
            case let .github(remoteSource):
                loadGitHubWorkspace(
                    CachedGitHubWorkspace(
                        descriptor: remoteSource.descriptor,
                        cacheRootURL: URL(fileURLWithPath: remoteSource.cachedRootPath, isDirectory: true)
                    ),
                    selectedPathOverride: selectedPathOverride
                )
            }
        } else if workspaceProvider != nil {
            loadWorkspace(
                from: workspaceRootURL,
                selectedPathOverride: selectedPathOverride,
                rootBookmarkData: workspaceRootBookmarkData
            )
        }
    }

    private func cancelActiveDocumentLoad() {
        activeDocumentRequestID = nil
        documentLoadTask?.cancel()
        documentLoadTask = nil
        isLoadingDocument = false
    }

    private func cancelActiveWorkspaceLoad() {
        workspaceLoadTask?.cancel()
        workspaceLoadTask = nil
        isLoadingWorkspace = false
    }

    private func replaceActiveSecurityScopedWorkspace(with newURL: URL?) {
        guard activeSecurityScopedWorkspaceURL != newURL else { return }
        activeSecurityScopedWorkspaceURL?.stopAccessingSecurityScopedResource()
        activeSecurityScopedWorkspaceURL = newURL
    }

    private func writeStateSnapshot(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.pretty.encode(stateSnapshot()).write(to: url)
    }

    private func writePerformanceSnapshot(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.pretty.encode(performanceSnapshot()).write(to: url)
    }

    private func flattenVisibleBlocks(from blocks: [MarkdownBlock]) -> [MarkdownBlock] {
        var flattened: [MarkdownBlock] = []
        for block in blocks {
            flattened.append(block)
            flattened.append(contentsOf: flattenVisibleBlocks(from: block.children))
        }
        return flattened
    }

    nonisolated static func shouldRenderStructuredContent(for blocks: [MarkdownBlock]) -> Bool {
        blocks.contains { block in
            switch block.kind {
            case .codeBlock, .table, .image, .animatedImage, .video, .mermaidDiagram:
                return true
            case .unorderedListItem, .orderedListItem:
                return block.isTaskItem || shouldRenderStructuredContent(for: block.children)
            default:
                return shouldRenderStructuredContent(for: block.children)
            }
        }
    }

    private func resolveMarkdownLinkTarget(_ url: URL) -> WorkspacePath? {
        if let scheme = url.scheme, !scheme.isEmpty, !url.isFileURL {
            return nil
        }

        let rawPath = url.path(percentEncoded: false)
        if rawPath.isEmpty {
            return nil
        }

        if url.isFileURL {
            return workspacePath(forResolvedFileURL: url)
        }

        guard isMarkdownPath(rawPath) else {
            return nil
        }

        let sourceDirectory = selectedPath.map { ($0.rawValue as NSString).deletingLastPathComponent } ?? ""
        let resolvedPath = ((sourceDirectory as NSString).appendingPathComponent(rawPath) as NSString)
            .standardizingPath
        return WorkspacePath(rawValue: resolvedPath)
    }

    private func workspacePath(forResolvedFileURL url: URL) -> WorkspacePath? {
        guard let workspaceRootURL else { return nil }

        let canonicalRootPath = workspaceRootURL.resolvingSymlinksInPath().standardizedFileURL.path
        let canonicalResolvedPath = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard canonicalResolvedPath == canonicalRootPath || canonicalResolvedPath.hasPrefix(canonicalRootPath + "/") else {
            return nil
        }

        let relativePath = String(canonicalResolvedPath.dropFirst(canonicalRootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relativePath.isEmpty, isMarkdownPath(relativePath) else {
            return nil
        }
        return WorkspacePath(rawValue: relativePath)
    }

    private func resolveMediaLinkTarget(_ url: URL) -> MediaLinkTarget? {
        guard let resolvedURL = resolvedExternalURL(for: url) else { return nil }
        guard let kind = Self.mediaLinkKind(for: resolvedURL) else { return nil }
        return MediaLinkTarget(resolvedURL: resolvedURL, originalURL: url.scheme == nil ? resolvedURL : url, kind: kind)
    }

    private func resolvedExternalURL(for url: URL) -> URL? {
        if let scheme = url.scheme, !scheme.isEmpty {
            return url
        }

        guard let workspaceProvider else { return nil }
        return try? workspaceProvider.resolveMediaURL(
            for: url.path(percentEncoded: false),
            relativeTo: selectedPath
        )
    }

    private func isMarkdownPath(_ path: String) -> Bool {
        let kind = WorkspaceDocumentKind.forPath(path)
        return kind == .markdown || kind == .mermaid
    }
}

extension AppModel {
    enum DocumentLinkAction: Equatable {
        case markdown(WorkspacePath)
        case media(MediaLinkTarget)
        case external(URL)
    }

    struct MediaLinkTarget: Identifiable, Equatable {
        enum Kind: String {
            case image
            case video
        }

        let resolvedURL: URL
        let originalURL: URL
        let kind: Kind

        var id: String { originalURL.absoluteString + "|" + kind.rawValue }
    }

    private struct DocumentLoadResult: Sendable {
        let kind: WorkspaceDocumentKind
        let text: String
        let blocks: [MarkdownBlock]
        let outlineItems: [MarkdownOutlineItem]
    }

    private struct PrintCompositionInput: Sendable {
        let scope: DocumentPrintScope
        let provider: any WorkspaceProvider
        let targetFiles: [MarkdownFileNode]
        let workspaceTitle: String
        let fontScale: Double
        let launchTheme: String?
        let tabularPresentation: TabularDocumentPresentation
    }

    enum PrintError: LocalizedError {
        case noSelectedDocument
        case noPrintableDocuments

        var errorDescription: String? {
            switch self {
            case .noSelectedDocument:
                return "Select a document to print."
            case .noPrintableDocuments:
                return "Open a workspace with printable documents first."
            }
        }
    }

    private static func loadDocument(
        provider: any WorkspaceProvider,
        path: WorkspacePath
    ) async -> DocumentLoadResult {
        let detachedTask = Task.detached(priority: .userInitiated) {
            let text = (try? provider.readFile(at: path)) ?? "Unable to read \(path.rawValue)"
            let kind = WorkspaceDocumentKind.forPath(path.rawValue) ?? .markdown
            let parsedBlocks = blocks(for: text, kind: kind, path: path)
            let blocks: [MarkdownBlock]
            if kind == .markdown {
                blocks = await hydrateMedia(in: parsedBlocks, provider: provider, documentPath: path)
            } else {
                blocks = parsedBlocks
            }
            return DocumentLoadResult(
                kind: kind,
                text: text,
                blocks: blocks,
                outlineItems: kind == .markdown ? outlineItems(from: blocks) : []
            )
        }

        return await withTaskCancellationHandler {
            await detachedTask.value
        } onCancel: {
            detachedTask.cancel()
        }
    }

    static func makePrintComposition(
        forExternalPrintFileURLs fileURLs: [URL],
        fontScale: Double = 1,
        launchTheme: String? = nil,
        tabularPresentation: TabularDocumentPresentation? = nil
    ) async throws -> DocumentPrintComposition {
        let printableFileURLs = fileURLs
            .map { $0.resolvingSymlinksInPath().standardizedFileURL }
            .filter { SupportedDocumentExtensions.contains($0.pathExtension) }
        guard printableFileURLs.isEmpty == false else {
            throw PrintError.noPrintableDocuments
        }
        let securityScopedURLs = printableFileURLs.filter { $0.startAccessingSecurityScopedResource() }
        defer {
            securityScopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        }

        var sections: [DocumentPrintSection] = []
        sections.reserveCapacity(printableFileURLs.count)
        for fileURL in printableFileURLs {
            let provider = LocalWorkspaceProvider(
                rootURL: fileURL.deletingLastPathComponent(),
                embeddedDocs: [:]
            )
            let path = WorkspacePath(rawValue: fileURL.lastPathComponent)
            let result = await loadDocument(provider: provider, path: path)
            sections.append(
                DocumentPrintSection(
                    path: path,
                    title: fileURL.lastPathComponent,
                    kind: result.kind,
                    blocks: result.blocks
                )
            )
        }

        let workspaceTitle: String
        if let firstURL = printableFileURLs.first, printableFileURLs.allSatisfy({ $0.deletingLastPathComponent() == firstURL.deletingLastPathComponent() }) {
            workspaceTitle = firstURL.deletingLastPathComponent().lastPathComponent
        } else {
            workspaceTitle = "Printed Documents"
        }

        return DocumentPrintComposition(
            scope: printableFileURLs.count == 1 ? .selectedFile : .allFiles,
            workspaceTitle: workspaceTitle,
            fontScale: fontScale,
            launchTheme: launchTheme,
            tabularPresentation: tabularPresentation ?? TabularDocumentPresentation(),
            sections: sections
        )
    }

    func makePrintComposition(scope: DocumentPrintScope) async throws -> DocumentPrintComposition {
        let input = try printCompositionInput(scope: scope)
        beginPreparingPrint(scope: scope, documentCount: input.targetFiles.count)

        defer {
            isPreparingPrint = false
            printPreparationMessage = nil
        }

        return try await Self.makePrintComposition(from: input)
    }

    private func printCompositionInput(scope: DocumentPrintScope) throws -> PrintCompositionInput {
        let targetFiles: [MarkdownFileNode]
        switch scope {
        case .selectedFile:
            guard let selectedPath, let selectedFile = files.first(where: { $0.path == selectedPath }) else {
                throw PrintError.noSelectedDocument
            }
            targetFiles = [selectedFile]
        case .allFiles:
            guard files.isEmpty == false else {
                throw PrintError.noPrintableDocuments
            }
            targetFiles = files
        }

        guard let provider = workspaceProvider else {
            throw PrintError.noPrintableDocuments
        }

        return PrintCompositionInput(
            scope: scope,
            provider: provider,
            targetFiles: targetFiles,
            workspaceTitle: workspaceRootDisplay,
            fontScale: Double(fontScale),
            launchTheme: launchOptions.theme,
            tabularPresentation: tabularPresentation
        )
    }

    private nonisolated static func makePrintComposition(from input: PrintCompositionInput) async throws -> DocumentPrintComposition {
        let sections = try await printSections(provider: input.provider, targetFiles: input.targetFiles)

        return DocumentPrintComposition(
            scope: input.scope,
            workspaceTitle: input.workspaceTitle,
            fontScale: input.fontScale,
            launchTheme: input.launchTheme,
            tabularPresentation: input.tabularPresentation,
            sections: sections
        )
    }

    private nonisolated static func printSections(
        provider: any WorkspaceProvider,
        targetFiles: [MarkdownFileNode]
    ) async throws -> [DocumentPrintSection] {
        var sections: [DocumentPrintSection] = []
        sections.reserveCapacity(targetFiles.count)
        for file in targetFiles {
            try Task.checkCancellation()
            let result = await Self.loadDocument(provider: provider, path: file.path)
            sections.append(
                DocumentPrintSection(
                    path: file.path,
                    title: file.name,
                    kind: result.kind,
                    blocks: result.blocks
                )
            )
        }
        return sections
    }

    private func beginPreparingPrint(scope: DocumentPrintScope, documentCount: Int) {
        isPreparingPrint = true
        printErrorMessage = nil
        printPreparationMessage = scope.preparationMessage(documentCount: documentCount)
        lastPrintRequestScope = scope.rawValue
        lastPrintRequestStatus = "preparing"
    }

    func recordPrintError(_ error: Error) {
        isPreparingPrint = false
        printErrorMessage = error.localizedDescription
        printPreparationMessage = nil
        lastPrintRequestStatus = "error"
    }

    func clearPrintError() {
        printErrorMessage = nil
    }

    func recordPrintPresentationStarted(scope: DocumentPrintScope) {
        lastPrintRequestScope = scope.rawValue
        lastPrintRequestStatus = "started"
    }

    func recordPrintPresentationSucceeded() {
        printPreparationMessage = nil
        lastPrintRequestStatus = "presented"
    }

    func recordPrintCancelled(scope: DocumentPrintScope? = nil) {
        isPreparingPrint = false
        printErrorMessage = nil
        printPreparationMessage = nil
        if let scope {
            lastPrintRequestScope = scope.rawValue
        }
        lastPrintRequestStatus = "cancelled"
    }

    var selectedSearchResult: DocumentSearchResult? {
        guard let selectedSearchResultID else { return nil }
        return searchResults.first { $0.id == selectedSearchResultID }
    }

    func activateSearch(scope: DocumentSearchScope) {
        searchScope = scope
        searchActivationCounter += 1
        runSearch()
    }

    func updateSearchQuery(_ query: String) {
        guard searchQuery != query else { return }
        searchQuery = query
        runSearch()
    }

    func selectSearchResult(_ result: DocumentSearchResult) {
        selectedSearchResultID = result.id
        if selectedPath == result.path {
            searchScrollTargetID = result.blockID
        } else {
            pendingSearchScrollTargetID = result.blockID
            openFile(result.path)
        }
    }

    func selectNextSearchResult() {
        guard searchResults.isEmpty == false else { return }
        let currentIndex = selectedSearchResultID.flatMap { selectedID in
            searchResults.firstIndex { $0.id == selectedID }
        }
        let nextIndex: Int
        if let currentIndex {
            nextIndex = searchResults.index(after: currentIndex) == searchResults.endIndex ? searchResults.startIndex : searchResults.index(after: currentIndex)
        } else {
            nextIndex = searchResults.startIndex
        }
        selectSearchResult(searchResults[nextIndex])
    }

    func clearSearchScrollTarget() {
        searchScrollTargetID = nil
    }

    private func runSearch() {
        searchTask?.cancel()
        selectedSearchResultID = nil
        searchResults = []

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else {
            isSearching = false
            return
        }

        isSearching = true
        switch searchScope {
        case .currentDocument:
            guard let selectedPath else {
                isSearching = false
                return
            }
            let fileName = selectedFileDisplayName
            let documentText = documentText
            let blocks = documentBlocks
            searchTask = Task { [weak self] in
                let results = await Task.detached(priority: .userInitiated) {
                    DocumentSearchEngine.results(
                        query: query,
                        path: selectedPath,
                        fileName: fileName,
                        documentText: documentText,
                        blocks: blocks
                    )
                }.value
                guard !Task.isCancelled else { return }
                self?.finishSearch(with: results)
            }
        case .allDocuments:
            guard let provider = workspaceProvider else {
                isSearching = false
                return
            }
            let files = files
            searchTask = Task { [weak self] in
                let results = await Self.searchAllDocuments(
                    query: query,
                    provider: provider,
                    files: files
                )
                guard !Task.isCancelled else { return }
                self?.finishSearch(with: results)
            }
        }
    }

    private func finishSearch(with results: [DocumentSearchResult]) {
        searchResults = results
        selectedSearchResultID = results.first?.id
        isSearching = false
    }

    private nonisolated static func searchAllDocuments(
        query: String,
        provider: any WorkspaceProvider,
        files: [MarkdownFileNode]
    ) async -> [DocumentSearchResult] {
        var allResults: [DocumentSearchResult] = []
        for file in files {
            if Task.isCancelled { return [] }
            let result = await loadDocument(provider: provider, path: file.path)
            allResults.append(
                contentsOf: DocumentSearchEngine.results(
                    query: query,
                    path: file.path,
                    fileName: file.name,
                    documentText: result.text,
                    blocks: result.blocks
                )
            )
        }
        return allResults
    }

    private func exportPrintPDF(_ composition: DocumentPrintComposition, to destinationURL: URL) async throws {
        try await MainActor.run {
            try PlatformPrintPresenter.exportPDF(composition, to: destinationURL)
        }
    }

    private nonisolated static func blocks(
        for text: String,
        kind: WorkspaceDocumentKind,
        path: WorkspacePath? = nil
    ) -> [MarkdownBlock] {
        switch kind {
        case .markdown:
            return MarkdownRenderer.blocks(from: text)
        case .mermaid:
            return [
                MermaidMarkdownBlockCatalog.standaloneBlock(
                    from: text,
                    path: path ?? WorkspacePath(rawValue: "Mermaid diagram")
                )
            ]
        case .csv, .tsv:
            guard let table = DelimitedTextDocumentParser.markdownTable(from: text, kind: kind) else {
                return []
            }
            return [
                MarkdownBlock(
                    id: "tabular.document",
                    kind: .table,
                    plainText: text,
                    sourceText: text,
                    level: nil,
                    listItemIndex: nil,
                    indentLevel: 0,
                    isTaskItem: false,
                    isTaskCompleted: nil,
                    table: table,
                    image: nil,
                    video: nil,
                    attributedText: nil,
                    children: []
                )
            ]
        }
    }

    nonisolated static func outlineItems(from blocks: [MarkdownBlock]) -> [MarkdownOutlineItem] {
        var items: [MarkdownOutlineItem] = []
        appendOutlineItems(from: blocks, to: &items)
        return items
    }

    nonisolated static func activeOutlineBlockID(
        from headingOffsets: [String: CGFloat],
        outlineItems: [MarkdownOutlineItem],
        currentBlockID: String?
    ) -> String? {
        let outlineBlockIDs = outlineItems.map(\.blockID)
        guard !outlineBlockIDs.isEmpty else { return nil }

        let visibleHeadings = outlineBlockIDs.compactMap { blockID -> (blockID: String, yOffset: CGFloat)? in
            guard let yOffset = headingOffsets[blockID] else { return nil }
            return (blockID, yOffset)
        }
        guard !visibleHeadings.isEmpty else {
            return currentBlockID.flatMap { outlineBlockIDs.contains($0) ? $0 : nil }
        }

        let activationOffset: CGFloat = 24
        if let activeHeading = visibleHeadings
            .filter({ $0.yOffset <= activationOffset })
            .max(by: { $0.yOffset < $1.yOffset }) {
            return activeHeading.blockID
        }

        if let currentBlockID, outlineBlockIDs.contains(currentBlockID) {
            return currentBlockID
        }

        return visibleHeadings.min(by: { $0.yOffset < $1.yOffset })?.blockID
    }

    private nonisolated static func appendOutlineItems(
        from blocks: [MarkdownBlock],
        to items: inout [MarkdownOutlineItem]
    ) {
        for block in blocks {
            if block.kind == .heading {
                let title = block.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty {
                    items.append(
                        MarkdownOutlineItem(
                            blockID: block.id,
                            title: title,
                            titleRuns: outlineTitleRuns(for: block, fallbackTitle: title),
                            level: max(1, min(block.level ?? 1, 6))
                        )
                    )
                }
            }
            appendOutlineItems(from: block.children, to: &items)
        }
    }

    private nonisolated static func outlineTitleRuns(
        for block: MarkdownBlock,
        fallbackTitle: String
    ) -> [MarkdownOutlineTitleRun] {
        guard let attributedText = block.attributedText else {
            return [MarkdownOutlineTitleRun(text: fallbackTitle, isCode: false)]
        }

        var runs: [MarkdownOutlineTitleRun] = []
        for run in attributedText.runs {
            let text = String(attributedText[run.range].characters)
            guard !text.isEmpty else { continue }
            let isCode = run.inlinePresentationIntent?.contains(.code) == true
            if let last = runs.last, last.isCode == isCode {
                runs[runs.count - 1] = MarkdownOutlineTitleRun(text: last.text + text, isCode: isCode)
            } else {
                runs.append(MarkdownOutlineTitleRun(text: text, isCode: isCode))
            }
        }

        let trimmedRuns = trimmedOutlineTitleRuns(runs)
        if trimmedRuns.isEmpty {
            return [MarkdownOutlineTitleRun(text: fallbackTitle, isCode: false)]
        }
        return trimmedRuns
    }

    private nonisolated static func trimmedOutlineTitleRuns(
        _ runs: [MarkdownOutlineTitleRun]
    ) -> [MarkdownOutlineTitleRun] {
        var trimmed = runs

        while let first = trimmed.first {
            let text = first.text.trimmingLeadingWhitespaceAndNewlines()
            if text.isEmpty {
                trimmed.removeFirst()
            } else {
                trimmed[0] = MarkdownOutlineTitleRun(text: text, isCode: first.isCode)
                break
            }
        }

        while let last = trimmed.last {
            let text = last.text.trimmingTrailingWhitespaceAndNewlines()
            if text.isEmpty {
                trimmed.removeLast()
            } else {
                trimmed[trimmed.count - 1] = MarkdownOutlineTitleRun(text: text, isCode: last.isCode)
                break
            }
        }

        return trimmed
    }

    private nonisolated static func hydrateMedia(
        in blocks: [MarkdownBlock],
        provider: any WorkspaceProvider,
        documentPath: WorkspacePath
    ) async -> [MarkdownBlock] {
        var hydratedBlocks: [MarkdownBlock] = []
        hydratedBlocks.reserveCapacity(blocks.count)
        for block in blocks {
            hydratedBlocks.append(await hydrateMedia(in: block, provider: provider, documentPath: documentPath))
        }
        return hydratedBlocks
    }

    private nonisolated static func hydrateMedia(
        in block: MarkdownBlock,
        provider: any WorkspaceProvider,
        documentPath: WorkspacePath
    ) async -> MarkdownBlock {
        let hydratedChildren = await hydrateMedia(in: block.children, provider: provider, documentPath: documentPath)

        switch block.kind {
        case .image:
            guard let image = block.image else {
                return block.replacing(children: hydratedChildren)
            }

            let (resolvedURL, loadError) = await hydrateImageURL(
                sourceURL: image.sourceURL,
                provider: provider,
                documentPath: documentPath
            )
            let hydratedImage = MarkdownImage(
                altText: image.altText,
                sourceURL: image.sourceURL,
                title: image.title,
                sourceKind: mediaSourceKind(for: image.sourceURL),
                resolvedURL: resolvedURL,
                loadError: loadError
            )
            let hydratedKind: MarkdownBlockKind = resolvedURL.map(isAnimatedImage(at:)) == true ? .animatedImage : .image
            return block.replacing(
                kind: hydratedKind,
                image: hydratedImage,
                children: hydratedChildren
            )

        case .video:
            guard let video = block.video else {
                return block.replacing(children: hydratedChildren)
            }

            let (resolvedURL, loadError) = hydrateVideoURL(
                sourceURL: video.sourceURL,
                provider: provider,
                documentPath: documentPath
            )
            let hydratedVideo = MarkdownVideo(
                altText: video.altText,
                sourceURL: video.sourceURL,
                title: video.title,
                sourceKind: mediaSourceKind(for: video.sourceURL),
                resolvedURL: resolvedURL,
                loadError: loadError
            )
            return block.replacing(video: hydratedVideo, children: hydratedChildren)

        default:
            return block.replacing(children: hydratedChildren)
        }
    }

    private nonisolated static func isAnimatedImage(at url: URL) -> Bool {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return false }
        return CGImageSourceGetCount(imageSource) > 1
    }

    private nonisolated static func hydrateImageURL(
        sourceURL: String,
        provider: any WorkspaceProvider,
        documentPath: WorkspacePath
    ) async -> (URL?, String?) {
        switch resolveMediaSourceURL(sourceURL, provider: provider, documentPath: documentPath, kindLabel: "Image") {
        case let .success(url):
            if url.isFileURL {
                return (url, nil)
            }

            do {
                let cachedURL = try await fetchRemoteImageToCache(remoteURL: url)
                return (cachedURL, nil)
            } catch {
                return (nil, remoteMediaFailureMessage(error: error, sourceURL: sourceURL, kindLabel: "Image"))
            }

        case let .failure(message):
            return (nil, message)
        }
    }

    private nonisolated static func hydrateVideoURL(
        sourceURL: String,
        provider: any WorkspaceProvider,
        documentPath: WorkspacePath
    ) -> (URL?, String?) {
        switch resolveMediaSourceURL(sourceURL, provider: provider, documentPath: documentPath, kindLabel: "Video") {
        case let .success(url):
            return (url, nil)
        case let .failure(message):
            return (nil, message)
        }
    }

    private enum MediaSourceResolutionResult {
        case success(URL)
        case failure(String)
    }

    private nonisolated static func resolveMediaSourceURL(
        _ sourceURL: String,
        provider: any WorkspaceProvider,
        documentPath: WorkspacePath,
        kindLabel: String
    ) -> MediaSourceResolutionResult {
        if let remoteURL = remoteMediaURL(from: sourceURL) {
            if remoteURL.scheme?.lowercased() == "https" || isLoopbackHTTPURL(remoteURL) {
                return .success(remoteURL)
            }
            return .failure(
                "\(kindLabel) failed to load.\nsource: \(sourceURL)\nOnly https URLs are supported, except localhost URLs used for tests."
            )
        }

        guard !sourceURL.lowercased().hasPrefix("data:") else {
            return .failure("\(kindLabel) data URLs are not supported.\nsource: \(sourceURL)")
        }

        guard let resolvedURL = try? provider.resolveMediaURL(for: sourceURL, relativeTo: documentPath) else {
            return .failure("\(kindLabel) path could not be resolved.\nsource: \(sourceURL)")
        }

        return .success(resolvedURL)
    }

    private nonisolated static func remoteMediaURL(from sourceURL: String) -> URL? {
        guard let url = URL(string: sourceURL), let scheme = url.scheme, !scheme.isEmpty, !url.isFileURL else {
            return nil
        }
        return url
    }

    private nonisolated static func isLoopbackHTTPURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "http" else { return false }
        guard let host = url.host?.lowercased() else { return false }
        return host == "127.0.0.1" || host == "localhost"
    }

    private nonisolated static func mediaSourceKind(for sourceURL: String) -> MarkdownMediaSourceKind {
        remoteMediaURL(from: sourceURL) == nil ? .local : .remote
    }

    private nonisolated static func fetchRemoteImageToCache(remoteURL: URL) async throws -> URL {
        let cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("qmv-remote-media-cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let baseName = Data(remoteURL.absoluteString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        let fileExtension = remoteURL.pathExtension.isEmpty ? "bin" : remoteURL.pathExtension
        let destinationURL = cacheDirectory.appendingPathComponent("\(baseName).\(fileExtension)")

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw RemoteMediaError.httpStatus(httpResponse.statusCode)
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    private enum RemoteMediaError: LocalizedError {
        case httpStatus(Int)

        var errorDescription: String? {
            switch self {
            case let .httpStatus(statusCode):
                return "HTTP \(statusCode)"
            }
        }
    }

    private nonisolated static func remoteMediaFailureMessage(error: Error, sourceURL: String, kindLabel: String) -> String {
        "\(kindLabel) failed to load: \(error.localizedDescription)\nsource: \(sourceURL)"
    }

    private nonisolated static func mediaLinkKind(for url: URL) -> MediaLinkTarget.Kind? {
        let fileExtension = url.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff", "tif", "heic", "heif"].contains(fileExtension) {
            return .image
        }
        if ["mp4", "mov", "m4v", "webm"].contains(fileExtension) {
            return .video
        }
        return nil
    }

    static func adjacentFilePath(
        from selectedPath: WorkspacePath?,
        within files: [MarkdownFileNode],
        offset: Int
    ) -> WorkspacePath? {
        guard !files.isEmpty, offset != 0 else { return nil }

        let selectedIndex = selectedPath.flatMap { path in
            files.firstIndex(where: { $0.path == path })
        }

        let targetIndex: Int
        if let selectedIndex {
            targetIndex = min(max(selectedIndex + offset, 0), files.count - 1)
            guard targetIndex != selectedIndex else { return nil }
        } else {
            targetIndex = offset > 0 ? 0 : files.count - 1
        }

        return files[targetIndex].path
    }

    nonisolated static func filteredFiles(
        from files: [MarkdownFileNode],
        matching query: String
    ) -> [MarkdownFileNode] {
        let trimmedQuery = normalizedQuickFilterText(query)
        guard !trimmedQuery.isEmpty else { return files }

        return files.filter { file in
            normalizedQuickFilterText(file.name).contains(trimmedQuery) ||
            normalizedQuickFilterText(file.path.rawValue).contains(trimmedQuery)
        }
    }

    private nonisolated static func normalizedQuickFilterText(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "[-_/\\.]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    nonisolated func trimmingLeadingWhitespaceAndNewlines() -> String {
        guard let firstContentIndex = firstIndex(where: { !$0.isWhitespace && !$0.isNewline }) else {
            return ""
        }
        return String(self[firstContentIndex...])
    }

    nonisolated func trimmingTrailingWhitespaceAndNewlines() -> String {
        guard let lastContentIndex = lastIndex(where: { !$0.isWhitespace && !$0.isNewline }) else {
            return ""
        }
        return String(self[...lastContentIndex])
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
