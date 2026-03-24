import Combine
import Foundation
import ImageIO
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var files: [MarkdownFileNode] = []
    @Published private(set) var documentText = "Loading…"
    @Published private(set) var documentBlocks: [MarkdownBlock] = []
    @Published private(set) var isLoadingDocument = false
    @Published private(set) var selectedPath: WorkspacePath?
    @Published private(set) var backStack: [NavigationEntry] = []
    @Published private(set) var forwardStack: [NavigationEntry] = []
    @Published private(set) var workspaceRootDisplay = "Fixtures/docs"
    @Published private(set) var isReady = false
    private(set) var viewportSize: CGSize = CGSize(width: 1100, height: 900)

    let launchOptions: HarnessLaunchOptions

    private let initialSession: WorkspaceWindowSession?
    private let startReference = Date()
    private var readyReference = Date()
    private var bootstrapTask: Task<Void, Never>?
    private var documentLoadTask: Task<Void, Never>?
    private var commandServer: HarnessCommandServer?
    private var didWriteLaunchArtifacts = false
    private var workspaceProvider: LocalWorkspaceProvider?
    private var workspaceRootURL: URL?
    private var screenshotWriter: ((URL) throws -> Void)?
    private var activeDocumentRequestID: UUID?
    private var hasResolvedWorkspaceSelection = false

    init(launchOptions: HarnessLaunchOptions, initialSession: WorkspaceWindowSession? = nil) {
        self.launchOptions = launchOptions
        self.initialSession = initialSession
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
        "\(workspaceRootDisplay) > \(selectedFileDisplayName)"
    }

    var shouldRenderBlockContent: Bool {
        containsRenderableMedia(in: documentBlocks)
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

    static var preview: AppModel {
        let model = AppModel(launchOptions: HarnessLaunchOptions.fromProcess(arguments: ["Preview"]))
        model.files = EmbeddedFixtures.docs.keys.sorted().map { MarkdownFileNode(path: WorkspacePath(rawValue: $0), name: $0) }
        model.selectedPath = WorkspacePath(rawValue: "basic_typography.md")
        model.documentText = EmbeddedFixtures.docs["basic_typography.md"] ?? ""
        model.documentBlocks = MarkdownRenderer.blocks(from: model.documentText)
        model.workspaceRootDisplay = "Fixtures/docs"
        model.workspaceRootURL = nil
        model.isReady = true
        return model
    }

    var restorationSession: WorkspaceWindowSession? {
        guard let workspaceRootURL else { return nil }
        return WorkspaceWindowSession(
            rootPath: workspaceRootURL.path,
            selectedFile: selectedPath?.rawValue
        )
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

    func updateViewport(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard viewportSize != size else { return }
        viewportSize = size
    }

    func openFile(_ path: WorkspacePath, recordHistory: Bool = true) {
        guard let workspaceProvider else { return }
        cancelActiveDocumentLoad()
        if recordHistory, let selectedPath, selectedPath != path {
            backStack.append(NavigationEntry(filePath: selectedPath, scrollPosition: nil))
            forwardStack.removeAll()
        }
        selectedPath = path
        isLoadingDocument = true

        let requestID = UUID()
        activeDocumentRequestID = requestID
        documentLoadTask = Task { [weak self] in
            guard let self else { return }
            let outcome = await Self.loadDocument(provider: workspaceProvider, path: path)
            guard !Task.isCancelled else { return }
            guard self.activeDocumentRequestID == requestID else { return }

            self.documentText = outcome.text
            self.documentBlocks = outcome.blocks
            self.isLoadingDocument = false
            self.isReady = true
            self.readyReference = Date()
            self.documentLoadTask = nil
        }
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

    func openFolder(at rootURL: URL) {
        cancelActiveDocumentLoad()
        loadWorkspace(from: rootURL)
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
            try? screenshotWriter?(url)
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
            let restoredRootURL = initialSession?.rootURL
            let restoredSelectedPath = initialSession?.selectedFile.map(WorkspacePath.init(rawValue:))
            loadWorkspace(
                from: restoredRootURL ?? launchOptions.fixtureRoot,
                selectedPathOverride: restoredSelectedPath
            )
        }

        if commandServer == nil, let commandDirectoryURL = launchOptions.commandDirectoryURL {
            let server = HarnessCommandServer(directoryURL: commandDirectoryURL)
            commandServer = server
            server.start(model: self)
        }
    }

    private func loadWorkspace(from rootURL: URL?, selectedPathOverride: WorkspacePath? = nil) {
        cancelActiveDocumentLoad()
        hasResolvedWorkspaceSelection = true
        let provider = LocalWorkspaceProvider(rootURL: rootURL, embeddedDocs: EmbeddedFixtures.docs)
        workspaceProvider = provider
        workspaceRootURL = rootURL
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
                documentText = "No markdown files found."
                documentBlocks = MarkdownRenderer.blocks(from: documentText)
                isLoadingDocument = false
                isReady = true
            }
        } catch {
            files = []
            selectedPath = nil
            workspaceRootURL = nil
            documentText = "Unable to load workspace: \(error.localizedDescription)"
            documentBlocks = MarkdownRenderer.blocks(from: documentText)
            isLoadingDocument = false
            isReady = true
        }
    }

    private func cancelActiveDocumentLoad() {
        activeDocumentRequestID = nil
        documentLoadTask?.cancel()
        documentLoadTask = nil
        isLoadingDocument = false
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

    private func containsRenderableMedia(in blocks: [MarkdownBlock]) -> Bool {
        blocks.contains { block in
            switch block.kind {
            case .image, .animatedImage, .video:
                return true
            default:
                return containsRenderableMedia(in: block.children)
            }
        }
    }
}

extension AppModel {
    private struct DocumentLoadResult: Sendable {
        let text: String
        let blocks: [MarkdownBlock]
    }

    private static func loadDocument(
        provider: LocalWorkspaceProvider,
        path: WorkspacePath
    ) async -> DocumentLoadResult {
        let detachedTask = Task.detached(priority: .userInitiated) {
            let text = (try? provider.readFile(at: path)) ?? "Unable to read \(path.rawValue)"
            let parsedBlocks = MarkdownRenderer.blocks(from: text)
            let blocks = hydrateMedia(in: parsedBlocks, provider: provider)
            return DocumentLoadResult(text: text, blocks: blocks)
        }

        return await withTaskCancellationHandler {
            await detachedTask.value
        } onCancel: {
            detachedTask.cancel()
        }
    }

    private nonisolated static func hydrateMedia(
        in blocks: [MarkdownBlock],
        provider: LocalWorkspaceProvider
    ) -> [MarkdownBlock] {
        blocks.map { hydrateMedia(in: $0, provider: provider) }
    }

    private nonisolated static func hydrateMedia(
        in block: MarkdownBlock,
        provider: LocalWorkspaceProvider
    ) -> MarkdownBlock {
        let hydratedChildren = hydrateMedia(in: block.children, provider: provider)

        switch block.kind {
        case .image:
            guard let image = block.image else {
                return block.replacing(children: hydratedChildren)
            }

            let resolvedURL = try? provider.resolveMediaURL(for: WorkspacePath(rawValue: image.sourceURL))
            let hydratedImage = MarkdownImage(
                altText: image.altText,
                sourceURL: image.sourceURL,
                title: image.title,
                resolvedURL: resolvedURL
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

            let resolvedURL = try? provider.resolveMediaURL(for: WorkspacePath(rawValue: video.sourceURL))
            let hydratedVideo = MarkdownVideo(
                altText: video.altText,
                sourceURL: video.sourceURL,
                title: video.title,
                resolvedURL: resolvedURL
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
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
