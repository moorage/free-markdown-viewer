import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var files: [MarkdownFileNode] = []
    @Published private(set) var documentText = "Loading…"
    @Published private(set) var selectedPath: WorkspacePath?
    @Published private(set) var backStack: [NavigationEntry] = []
    @Published private(set) var forwardStack: [NavigationEntry] = []
    @Published private(set) var workspaceRootDisplay = "Fixtures/docs"
    @Published private(set) var isReady = false
    @Published var viewportSize: CGSize = CGSize(width: 1100, height: 900)

    let launchOptions: HarnessLaunchOptions

    private let startReference = Date()
    private var readyReference = Date()
    private var bootstrapTask: Task<Void, Never>?
    private var commandServer: HarnessCommandServer?
    private var didWriteLaunchArtifacts = false
    private var workspaceProvider: WorkspaceProvider?
    private var screenshotWriter: ((URL) throws -> Void)?

    init(launchOptions: HarnessLaunchOptions) {
        self.launchOptions = launchOptions
    }

    static var preview: AppModel {
        let model = AppModel(launchOptions: HarnessLaunchOptions.fromProcess(arguments: ["Preview"]))
        model.files = EmbeddedFixtures.docs.keys.sorted().map { MarkdownFileNode(path: WorkspacePath(rawValue: $0), name: $0) }
        model.selectedPath = WorkspacePath(rawValue: "basic_typography.md")
        model.documentText = EmbeddedFixtures.docs["basic_typography.md"] ?? ""
        model.workspaceRootDisplay = "Fixtures/docs"
        model.isReady = true
        return model
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
        viewportSize = size
    }

    func openFile(_ path: WorkspacePath, recordHistory: Bool = true) {
        guard let workspaceProvider else { return }
        if recordHistory, let selectedPath {
            backStack.append(NavigationEntry(filePath: selectedPath, scrollPosition: nil))
            forwardStack.removeAll()
        }
        selectedPath = path
        documentText = (try? workspaceProvider.readFile(at: path)) ?? "Unable to read \(path.rawValue)"
        isReady = true
        readyReference = Date()
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
        let firstLine = documentText
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""

        return HarnessStateSnapshot(
            platform: launchOptions.platformTarget.rawValue,
            deviceClass: launchOptions.deviceClass.rawValue,
            workspaceRoot: workspaceRootDisplay,
            selectedFile: selectedPath?.rawValue,
            history: NavigationHistorySnapshot(backCount: backStack.count, forwardCount: forwardStack.count),
            viewport: ViewportSnapshot(x: 0, y: 0, width: viewportSize.width, height: viewportSize.height),
            visibleBlocks: [
                VisibleBlockSnapshot(
                    id: AccessibilityIDs.placeholderBlock,
                    kind: "paragraph",
                    text: firstLine
                )
            ],
            sidebar: SidebarSnapshot(selectedNode: selectedPath?.rawValue)
        )
    }

    func performanceSnapshot() -> HarnessPerformanceSnapshot {
        HarnessPerformanceSnapshot(
            platform: launchOptions.platformTarget.rawValue,
            deviceClass: launchOptions.deviceClass.rawValue,
            launchTime: 0,
            readyTime: readyReference.timeIntervalSince(startReference),
            visibleBlockCount: 1,
            activeAnimatedMediaCount: 0,
            activeVideoPlayerCount: 0
        )
    }

    private func loadWorkspace() async {
        let provider = LocalWorkspaceProvider(rootURL: launchOptions.fixtureRoot, embeddedDocs: EmbeddedFixtures.docs)
        workspaceProvider = provider
        do {
            let workspace = try provider.loadRoot()
            files = workspace.files
            workspaceRootDisplay = workspace.rootIdentifier
            let initialPath = launchOptions.openFile.flatMap { WorkspacePath(rawValue: $0) } ?? workspace.files.first?.path
            if let initialPath {
                openFile(initialPath, recordHistory: false)
            } else {
                documentText = "No markdown files found."
                isReady = true
            }
        } catch {
            documentText = "Unable to load workspace: \(error.localizedDescription)"
            isReady = true
        }

        if let commandDirectoryURL = launchOptions.commandDirectoryURL {
            let server = HarnessCommandServer(directoryURL: commandDirectoryURL)
            commandServer = server
            server.start(model: self)
        }
    }

    private func writeStateSnapshot(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.pretty.encode(stateSnapshot()).write(to: url)
    }

    private func writePerformanceSnapshot(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder.pretty.encode(performanceSnapshot()).write(to: url)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
