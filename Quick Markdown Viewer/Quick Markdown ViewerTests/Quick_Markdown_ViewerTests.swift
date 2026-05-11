//
//  Quick_Markdown_ViewerTests.swift
//  Quick Markdown ViewerTests
//
//  Created by Matthew Moore on 3/19/26.
//

import PDFKit
import XCTest
@testable import Quick_Markdown_Viewer

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

final class Quick_Markdown_ViewerTests: XCTestCase {
    private final class HTMLTextCollector: NSObject, XMLParserDelegate {
        var parts: [String] = []

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            parts.append(string)
        }
    }

    private struct FailingGitHubRemoteClient: GitHubRemoteClientProtocol {
        let error: Error

        func repositoryMetadata(owner: String, repository: String) async throws -> GitHubRepositoryMetadata {
            throw error
        }

        func commitSHA(owner: String, repository: String, ref: String) async throws -> String {
            throw error
        }

        func treeEntries(owner: String, repository: String, commitSHA: String) async throws -> [GitHubTreeEntry] {
            throw error
        }

        func fileData(owner: String, repository: String, commitSHA: String, path: String) async throws -> Data {
            throw error
        }
    }

    private static var retainedModels: [AppModel] = []

    private func extractedPDFText(from url: URL) throws -> String {
        #if os(macOS)
        if let shellText = try shellExtractedPDFText(from: url) {
            return shellText
        }
        #endif
        return PDFDocument(url: url)?.string ?? ""
    }

    private func firstPDFPageCGImage(from url: URL, size: CGSize) throws -> CGImage {
        let document = try XCTUnwrap(PDFDocument(url: url))
        let page = try XCTUnwrap(document.page(at: 0))
        #if os(macOS)
        let thumbnail = page.thumbnail(of: size, for: .mediaBox)
        var proposedRect = CGRect(origin: .zero, size: thumbnail.size)
        return try XCTUnwrap(thumbnail.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil))
        #elseif os(iOS)
        return try XCTUnwrap(page.thumbnail(of: size, for: .mediaBox).cgImage)
        #endif
    }

    private func quantizedColorStats(
        for image: CGImage,
        cropRect: CGRect,
        quantizationStep: UInt8 = 32
    ) throws -> (uniqueCount: Int, dominantShare: Double) {
        let resolvedCropRect = CGRect(
            x: max(0, min(cropRect.origin.x, CGFloat(image.width))),
            y: max(0, min(cropRect.origin.y, CGFloat(image.height))),
            width: max(1, min(cropRect.width, CGFloat(image.width) - cropRect.origin.x)),
            height: max(1, min(cropRect.height, CGFloat(image.height) - cropRect.origin.y))
        ).integral

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = Int(resolvedCropRect.width) * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: Int(resolvedCropRect.height) * bytesPerRow)
        guard let context = CGContext(
            data: &buffer,
            width: Int(resolvedCropRect.width),
            height: Int(resolvedCropRect.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Expected bitmap context")
            return (0, 1)
        }

        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(
                x: -resolvedCropRect.origin.x,
                y: resolvedCropRect.origin.y - CGFloat(image.height),
                width: CGFloat(image.width),
                height: CGFloat(image.height)
            )
        )

        var counts: [UInt32: Int] = [:]
        counts.reserveCapacity(256)
        let pixelCount = Int(resolvedCropRect.width) * Int(resolvedCropRect.height)
        for pixelIndex in 0..<pixelCount {
            let offset = pixelIndex * bytesPerPixel
            let alpha = buffer[offset + 3]
            guard alpha > 0 else { continue }
            let red = UInt32(buffer[offset] / quantizationStep)
            let green = UInt32(buffer[offset + 1] / quantizationStep)
            let blue = UInt32(buffer[offset + 2] / quantizationStep)
            let key = (red << 16) | (green << 8) | blue
            counts[key, default: 0] += 1
        }

        let dominantCount = counts.values.max() ?? 0
        let sampledPixelCount = max(counts.values.reduce(0, +), 1)
        return (counts.count, Double(dominantCount) / Double(sampledPixelCount))
    }

    #if os(iOS)
    private func writeSyntheticPrintImage(to url: URL) throws {
        let size = CGSize(width: 480, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            let colors: [UIColor] = [
                .systemRed,
                .systemOrange,
                .systemYellow,
                .systemGreen,
                .systemTeal,
                .systemBlue,
                .systemIndigo,
                .systemPink
            ]
            let columnWidth = size.width / CGFloat(colors.count)
            for (index, color) in colors.enumerated() {
                color.setFill()
                context.fill(CGRect(x: CGFloat(index) * columnWidth, y: 0, width: columnWidth, height: size.height))
            }

            UIColor.black.setStroke()
            context.cgContext.setLineWidth(8)
            context.cgContext.strokeEllipse(in: CGRect(x: 140, y: 40, width: 200, height: 160))
            UIColor.white.setFill()
            context.fill(CGRect(x: 200, y: 85, width: 80, height: 70))
        }

        guard let data = image.pngData() else {
            XCTFail("Expected PNG data")
            return
        }
        try data.write(to: url)
    }
    #endif

    #if os(macOS)
    private func shellExtractedPDFText(from url: URL) throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["pdftotext", url.path, "-"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
    #endif

    private var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @MainActor
    private func retainForTestLifetime(_ model: AppModel) {
        Self.retainedModels.append(model)
    }

    func testLaunchOptionsParsePlatformAndPaths() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let stateURL = tempRoot.appendingPathComponent("state.json")
        let perfURL = tempRoot.appendingPathComponent("perf.json")

        let options = HarnessLaunchOptions.fromProcess(arguments: [
            "App",
            "--fixture-root", "/tmp/fixtures",
            "--open-file", "basic_typography.md",
            "--ui-test-open-folder", "/tmp/selected-folder",
            "--ui-test-install-command-line-tool", "/tmp/qmv",
            "--ui-test-github-fixture", "/tmp/github-fixture.json",
            "--ui-test-open-linked-media", "https://example.com/rickrolled.gif",
            "--ui-test-reset-command-line-tool-install-state",
            "--platform-target", "ios",
            "--device-class", "ipad",
            "--dump-visible-state", stateURL.path,
            "--dump-perf-state", perfURL.path,
            "--ui-test-mode", "1",
        ])

        XCTAssertEqual(options.fixtureRoot?.path, "/tmp/fixtures")
        XCTAssertEqual(options.openFile, "basic_typography.md")
        XCTAssertEqual(options.uiTestOpenFolderURL?.path, "/tmp/selected-folder")
        XCTAssertEqual(options.uiTestInstallCommandLineToolURL?.path, "/tmp/qmv")
        XCTAssertEqual(options.uiTestGitHubFixtureURL?.path, "/tmp/github-fixture.json")
        XCTAssertEqual(options.uiTestOpenLinkedMediaURL?.absoluteString, "https://example.com/rickrolled.gif")
        XCTAssertTrue(options.uiTestResetCommandLineToolInstallState)
        XCTAssertEqual(options.platformTarget, .ios)
        XCTAssertEqual(options.deviceClass, .ipad)
        XCTAssertEqual(options.dumpVisibleStateURL?.path, stateURL.path)
        XCTAssertEqual(options.dumpPerfStateURL?.path, perfURL.path)
        XCTAssertTrue(options.uiTestMode)
    }

    func testLaunchOptionsParseMultipleUITestOpenFolders() {
        let options = HarnessLaunchOptions.fromProcess(arguments: [
            "App",
            "--ui-test-open-folder", "/tmp/first-folder",
            "--ui-test-open-folder", "/tmp/second-folder",
            "--ui-test-mode", "1",
        ])

        XCTAssertEqual(
            options.uiTestOpenFolderURLs.map(\.path),
            ["/tmp/first-folder", "/tmp/second-folder"]
        )
        XCTAssertEqual(options.uiTestOpenFolderURL?.path, "/tmp/first-folder")
    }

    @MainActor
    func testResolvedDocumentLinkActionRecognizesRelativeMediaLinks() async throws {
        let workspace = try makeTemporaryWorkspace(named: "Link Workspace", files: [
            "docs/index.md": "# Links\n\n[Open image](../media/rickrolled.gif)\n\n[Open video](../media/rickrolled.mp4)",
            "media/rickrolled.gif": "not used",
            "media/rickrolled.mp4": "not used"
        ])

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "docs/index.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        retainForTestLifetime(model)
        model.bootstrap()
        try await Task.sleep(nanoseconds: 500_000_000)

        guard case let .media(imageTarget) = model.resolvedDocumentLinkAction(for: URL(string: "../media/rickrolled.gif")!) else {
            return XCTFail("Expected image media target")
        }
        XCTAssertEqual(imageTarget.kind, .image)
        XCTAssertTrue(imageTarget.resolvedURL.isFileURL)
        XCTAssertTrue(imageTarget.resolvedURL.path.hasSuffix("/media/rickrolled.gif"))

        guard case let .media(videoTarget) = model.resolvedDocumentLinkAction(for: URL(string: "../media/rickrolled.mp4")!) else {
            return XCTFail("Expected video media target")
        }
        XCTAssertEqual(videoTarget.kind, .video)
        XCTAssertTrue(videoTarget.resolvedURL.path.hasSuffix("/media/rickrolled.mp4"))
    }

    @MainActor
    func testNestedFixtureDocumentResolvesInlineImageRelativeToDocumentDirectory() async throws {
        let docsRoot = repoRootURL.appendingPathComponent("Fixtures/docs", isDirectory: true)
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: docsRoot,
                openFile: "animated_gif.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        retainForTestLifetime(model)
        model.bootstrap()
        try await Task.sleep(nanoseconds: 1_500_000_000)

        guard let imageBlock = model.documentBlocks.first(where: { $0.image != nil }),
              let image = imageBlock.image else {
            return XCTFail("Expected an inline image block")
        }

        XCTAssertEqual(model.selectedPath?.rawValue, "animated_gif.md")
        XCTAssertEqual(image.sourceURL, "../media/rickrolled.gif")
        XCTAssertEqual(
            image.resolvedURL?.path,
            repoRootURL.appendingPathComponent("Fixtures/media/rickrolled.gif").path
        )
        XCTAssertNil(image.loadError)
    }

    #if os(macOS)
    func testCommandLineToolLauncherScriptUsesBundleIdentifierAndDefaultTarget() {
        let script = MacCommandLineToolManager.launcherScript()

        XCTAssertTrue(script.contains("target=\"${1:-.}\""))
        XCTAssertTrue(script.contains("/usr/bin/open -b \"com.souschefstudio.Free-Markdown-Viewer\""))
        XCTAssertTrue(script.contains("$(basename \"$target\")"))
        XCTAssertTrue(script.contains("usage: qmv [directory-or-markdown-file]"))
    }

    func testCommandLineToolDefaultInstallURLUsesLocalBinInHomeDirectory() {
        let homeDirectory = URL(fileURLWithPath: "/Users/tester", isDirectory: true)

        let installURL = MacCommandLineToolManager.defaultInstallURL(homeDirectory: homeDirectory)

        XCTAssertEqual(installURL.path, "/Users/tester/.local/bin/qmv")
    }

    func testCommandLineToolInstallStateDetectsMatchingExecutableScript() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let installURL = tempRoot.appendingPathComponent("qmv")

        try MacCommandLineToolManager.writeCommandLineTool(to: installURL)

        let installState = MacCommandLineToolManager.detectInstallState(storedURL: installURL)
        guard case let .installed(resolvedURL) = installState else {
            return XCTFail("Expected installed state, got \(installState)")
        }
        XCTAssertEqual(resolvedURL, installURL)
    }

    func testCommandLineToolInstallStateDetectsStaleScript() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let installURL = tempRoot.appendingPathComponent("qmv")

        try "echo stale\n".write(to: installURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installURL.path)

        let installState = MacCommandLineToolManager.detectInstallState(storedURL: installURL)
        guard case let .stale(resolvedURL) = installState else {
            return XCTFail("Expected stale state, got \(installState)")
        }
        XCTAssertEqual(resolvedURL, installURL)
    }

    func testCommandLineToolInstallStateFallsBackToNotInstalledWhenLauncherMissing() {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("qmv")

        let installState = MacCommandLineToolManager.detectInstallState(storedURL: missingURL)
        guard case let .notInstalled(lastKnownURL) = installState else {
            return XCTFail("Expected not-installed state, got \(installState)")
        }
        XCTAssertEqual(lastKnownURL, missingURL)
    }

    func testCommandLineToolInstallStateUsesInstallMenuTitleWhenMissing() {
        let installState = MacCommandLineToolInstallState.notInstalled(lastKnownURL: nil)

        XCTAssertEqual(installState.menuTitle, "Install Command Line Tool…")
    }

    func testCommandLineToolInstallExplanationMentionsLocalBin() {
        XCTAssertEqual(
            MacCommandLineToolManager.installExplanation,
            "Install `qmv` in ~/.local/bin to open folders from Terminal."
        )
    }

    func testCommandLineToolInstallStateUsesRemoveMenuTitleWhenInstalled() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let installURL = tempRoot.appendingPathComponent("qmv")
        try MacCommandLineToolManager.writeCommandLineTool(to: installURL)

        let installState = MacCommandLineToolInstallState.installed(installURL)

        XCTAssertEqual(installState.menuTitle, "Remove Command Line Tool…")
    }

    func testCommandLineToolRemoveDeletesLauncherAndDetectsNotInstalledState() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let installURL = tempRoot.appendingPathComponent("qmv")
        try MacCommandLineToolManager.writeCommandLineTool(to: installURL)
        try MacCommandLineToolManager.removeCommandLineTool(at: installURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: installURL.path))

        let installState = MacCommandLineToolManager.detectInstallState(storedURL: installURL)
        guard case let .notInstalled(lastKnownURL) = installState else {
            return XCTFail("Expected not-installed state after removal, got \(installState)")
        }
        XCTAssertEqual(lastKnownURL, installURL)
    }

    func testPostInstallShellCommandUsesBundledScriptPath() {
        let scriptURL = URL(fileURLWithPath: "/Applications/Quick Markdown Viewer.app/Contents/Resources/qmv-finish-terminal-setup.sh")

        let command = MacCommandLineToolManager.postInstallShellCommand(scriptURL: scriptURL)

        XCTAssertEqual(
            command,
            "/bin/sh '/Applications/Quick Markdown Viewer.app/Contents/Resources/qmv-finish-terminal-setup.sh'"
        )
    }

    func testPostInstallShellCommandEscapesSingleQuotesInScriptPath() {
        let scriptURL = URL(fileURLWithPath: "/Applications/Matthew's Apps/Quick Markdown Viewer.app/Contents/Resources/qmv-finish-terminal-setup.sh")

        let command = MacCommandLineToolManager.postInstallShellCommand(scriptURL: scriptURL)

        XCTAssertEqual(
            command,
            "/bin/sh '/Applications/Matthew'\\''s Apps/Quick Markdown Viewer.app/Contents/Resources/qmv-finish-terminal-setup.sh'"
        )
    }

    func testPostInstallShellCommandFindsBundledScriptInAppBundle() {
        let command = MacCommandLineToolManager.postInstallShellCommand()

        XCTAssertNotNil(command)
        XCTAssertTrue(command?.contains("qmv-finish-terminal-setup.sh") == true)
    }

    func testBundledPostInstallScriptExplainsMissingLauncherClearly() throws {
        let scriptURL = repoRootURL
            .appendingPathComponent("Quick Markdown Viewer/Quick Markdown Viewer/Resources/qmv-finish-terminal-setup.sh")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        XCTAssertTrue(script.contains("install_tool=\"$install_dir/qmv\""))
        XCTAssertTrue(script.contains("qmv is not installed at $install_tool"))
        XCTAssertTrue(script.contains("run Install Command Line Tool"))
    }

    func testExternalWorkspaceOpenCoordinatorNormalizesMarkdownFileToWorkspaceAndSelection() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let markdownURL = tempRoot.appendingPathComponent("notes.md")
        try "# Notes".write(to: markdownURL, atomically: true, encoding: .utf8)

        let request = try XCTUnwrap(ExternalWorkspaceOpenCoordinator.normalizedRequest(for: markdownURL))
        XCTAssertEqual(request.rootURL.path, tempRoot.path)
        XCTAssertEqual(request.selectedPath?.rawValue, "notes.md")
    }

    func testExternalWorkspaceOpenCoordinatorNormalizesCSVFileToWorkspaceAndSelection() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let csvURL = tempRoot.appendingPathComponent("table.csv")
        try "Name,Count\nAlpha,1".write(to: csvURL, atomically: true, encoding: .utf8)

        let request = try XCTUnwrap(ExternalWorkspaceOpenCoordinator.normalizedRequest(for: csvURL))
        XCTAssertEqual(request.rootURL.path, tempRoot.path)
        XCTAssertEqual(request.selectedPath?.rawValue, "table.csv")
    }

    func testExternalWorkspaceOpenCoordinatorRejectsUnsupportedFiles() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let textURL = tempRoot.appendingPathComponent("notes.txt")
        try "not markdown".write(to: textURL, atomically: true, encoding: .utf8)

        XCTAssertNil(ExternalWorkspaceOpenCoordinator.normalizedRequest(for: textURL))
    }

    @MainActor
    func testAppDelegateOpenFilesEnqueuesMarkdownWorkspace() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let markdownURL = tempRoot.appendingPathComponent("notes.md")
        try "# Notes".write(to: markdownURL, atomically: true, encoding: .utf8)

        let coordinator = ExternalWorkspaceOpenCoordinator.shared
        let appDelegate = QuickMarkdownViewerAppDelegate()
        appDelegate.application(NSApplication.shared, openFiles: [markdownURL.path])

        guard let requestID = coordinator.latestRequestID else {
            return XCTFail("Expected external workspace request")
        }
        let request = try XCTUnwrap(coordinator.claimRequest(id: requestID))
        XCTAssertEqual(request.rootURL.path, tempRoot.path)
        XCTAssertEqual(request.selectedPath?.rawValue, "notes.md")
    }

    @MainActor
    func testAppDelegateOpenURLsEnqueuesDirectoryWorkspace() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let coordinator = ExternalWorkspaceOpenCoordinator.shared
        let appDelegate = QuickMarkdownViewerAppDelegate()
        appDelegate.application(NSApplication.shared, open: [tempRoot])

        guard let requestID = coordinator.latestRequestID else {
            return XCTFail("Expected external workspace request")
        }
        let request = try XCTUnwrap(coordinator.claimRequest(id: requestID))
        XCTAssertEqual(request.rootURL.path, tempRoot.path)
        XCTAssertNil(request.selectedPath)
    }
    #endif

    func testWorkspaceProviderFallsBackToEmbeddedDocs() throws {
        let provider = LocalWorkspaceProvider(rootURL: nil, embeddedDocs: EmbeddedFixtures.docs)
        let workspace = try provider.loadRoot()

        XCTAssertEqual(workspace.rootIdentifier, "Fixtures/docs")
        XCTAssertTrue(workspace.files.contains(where: { $0.path.rawValue == "basic_typography.md" }))
        XCTAssertEqual(try provider.readFile(at: WorkspacePath(rawValue: "basic_typography.md")).contains("Basic typography"), true)
    }

    func testWorkspaceProviderUsesChosenFolderWithoutFixtureFallback() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let provider = LocalWorkspaceProvider(rootURL: tempRoot, embeddedDocs: EmbeddedFixtures.docs)
        let workspace = try provider.loadRoot()

        XCTAssertEqual(workspace.rootIdentifier, tempRoot.lastPathComponent)
        XCTAssertTrue(workspace.files.isEmpty)
    }

    @MainActor
    func testAppModelAutoPromptsForFolderOnNormalMacLaunch() {
        let options = HarnessLaunchOptions(
            fixtureRoot: nil,
            openFile: nil,
            uiTestOpenFolderURL: nil,
            theme: nil,
            windowSize: nil,
            disableFileWatch: true,
            dumpVisibleStateURL: nil,
            dumpPerfStateURL: nil,
            screenshotPathURL: nil,
            commandDirectoryURL: nil,
            uiTestMode: false,
            platformTarget: .macos,
            deviceClass: .mac
        )

        let model = AppModel(launchOptions: options)
        retainForTestLifetime(model)

        XCTAssertTrue(model.shouldAutoPromptForFolderOnLaunch)
    }

    @MainActor
    func testAppModelWithoutInitialWorkspaceShowsOpenFolderPromptState() async throws {
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: nil,
                openFile: nil,
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )
        retainForTestLifetime(model)

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(model.files.isEmpty)
        XCTAssertNil(model.currentWorkspaceRootURL)
        XCTAssertNil(model.selectedPath)
        XCTAssertTrue(model.shouldShowOpenFolderPromptState)
        XCTAssertFalse(model.shouldShowEmptyWorkspaceState)
        XCTAssertEqual(model.documentText, AppModel.noWorkspacePromptMessage)
        XCTAssertEqual(model.windowTitle, "No Folder Open")
    }

    @MainActor
    func testAppModelSkipsAutoPromptDuringUITestLaunch() {
        let options = HarnessLaunchOptions(
            fixtureRoot: nil,
            openFile: nil,
            uiTestOpenFolderURL: URL(fileURLWithPath: "/tmp/ui-test-folder"),
            theme: nil,
            windowSize: nil,
            disableFileWatch: true,
            dumpVisibleStateURL: nil,
            dumpPerfStateURL: nil,
            screenshotPathURL: nil,
            commandDirectoryURL: nil,
            uiTestMode: true,
            platformTarget: .macos,
            deviceClass: .mac
        )

        let model = AppModel(launchOptions: options)
        retainForTestLifetime(model)

        XCTAssertFalse(model.shouldAutoPromptForFolderOnLaunch)
    }

    @MainActor
    func testAppModelIncreasesFontSizeUntilMaximum() {
        let model = AppModel(
            launchOptions: HarnessLaunchOptions.fromProcess(arguments: ["App", "--ui-test-mode", "1"])
        )
        retainForTestLifetime(model)

        for _ in 0..<20 {
            model.increaseFontSize()
        }

        XCTAssertEqual(model.fontScale, AppModel.maximumFontScale)
        XCTAssertFalse(model.canIncreaseFontSize)
        XCTAssertTrue(model.canDecreaseFontSize)
    }

    @MainActor
    func testAppModelDecreasesFontSizeUntilMinimum() {
        let model = AppModel(
            launchOptions: HarnessLaunchOptions.fromProcess(arguments: ["App", "--ui-test-mode", "1"])
        )
        retainForTestLifetime(model)

        model.increaseFontSize()
        model.decreaseFontSize()
        XCTAssertEqual(model.fontScale, 1)

        for _ in 0..<20 {
            model.decreaseFontSize()
        }

        XCTAssertEqual(model.fontScale, AppModel.minimumFontScale)
        XCTAssertFalse(model.canDecreaseFontSize)
        XCTAssertTrue(model.canIncreaseFontSize)
    }

    @MainActor
    func testAppModelPrefersDetailInCompactNavigationOnIPhoneWhenFileSelected() {
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: repoRootURL.appendingPathComponent("Fixtures/app-store", isDirectory: true),
                openFile: "Open Markdown Folders.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .ios,
                deviceClass: .iphone
            )
        )
        retainForTestLifetime(model)

        model.bootstrap()

        let expectation = expectation(description: "fixture loads")
        Task { @MainActor in
            for _ in 0..<20 {
                if model.selectedPath?.rawValue == "Open Markdown Folders.md" {
                    expectation.fulfill()
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        wait(for: [expectation], timeout: 2)

        XCTAssertTrue(model.shouldPreferDetailInCompactNavigation)
    }

    @MainActor
    func testAppModelDoesNotPreferDetailInCompactNavigationWithoutSelectedFile() {
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: nil,
                openFile: nil,
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .ios,
                deviceClass: .iphone
            )
        )
        retainForTestLifetime(model)

        XCTAssertFalse(model.shouldPreferDetailInCompactNavigation)
    }

    @MainActor
    func testAppModelUsesStructuredRendererForCodeBlockOnlyDocument() async throws {
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: repoRootURL.appendingPathComponent("Fixtures/app-store", isDirectory: true),
                openFile: "Code Sample.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .ios,
                deviceClass: .iphone
            )
        )
        retainForTestLifetime(model)
        model.bootstrap()

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(model.shouldRenderBlockContent)
    }

    func testAppModelUsesStructuredRendererForTaskListDocument() {
        let blocks = MarkdownRenderer.blocks(from: """
        - [ ] pending item
        - [x] completed item
        """)

        XCTAssertEqual(blocks.map(\.isTaskItem), [true, true])
        XCTAssertEqual(blocks.map(\.isTaskCompleted), [false, true])
        XCTAssertTrue(AppModel.shouldRenderStructuredContent(for: blocks))
    }

    @MainActor
    func testAutomaticFolderPromptPolicySuppressesLaunchSceneOnly() {
        var policy = AutomaticFolderPromptPolicy()

        XCTAssertTrue(policy.shouldSuppressAutomaticFolderPrompt(for: "launch-scene", hasRestoredSession: false))
        XCTAssertFalse(policy.shouldSuppressAutomaticFolderPrompt(for: "new-window-scene", hasRestoredSession: false))
    }

    func testAutomaticFolderPromptPolicySuppressesRestoredScenes() {
        var policy = AutomaticFolderPromptPolicy()

        XCTAssertTrue(policy.shouldSuppressAutomaticFolderPrompt(for: "restored-scene", hasRestoredSession: true))
        XCTAssertFalse(policy.shouldSuppressAutomaticFolderPrompt(for: "explicit-new-window", hasRestoredSession: false))
    }

    @MainActor
    func testIntegrationWorkspaceLoadsFixtureAndSnapshot() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let fileURL = tempRoot.appendingPathComponent("fixture.md")
        try "# Fixture\n\nBody".write(to: fileURL, atomically: true, encoding: .utf8)

        let options = HarnessLaunchOptions(
            fixtureRoot: tempRoot,
            openFile: "fixture.md",
            uiTestOpenFolderURL: nil,
            theme: nil,
            windowSize: CGSize(width: 800, height: 600),
            disableFileWatch: true,
            dumpVisibleStateURL: nil,
            dumpPerfStateURL: nil,
            screenshotPathURL: nil,
            commandDirectoryURL: nil,
            uiTestMode: true,
            platformTarget: .macos,
            deviceClass: .mac
        )

        let model = AppModel(launchOptions: options)
        model.bootstrap()

        try await Task.sleep(nanoseconds: 300_000_000)

        let snapshot = model.stateSnapshot()
        XCTAssertEqual(snapshot.selectedFile, "fixture.md")
        XCTAssertEqual(snapshot.sidebar.selectedNode, "fixture.md")
        XCTAssertEqual(snapshot.visibleBlocks.first?.text, "Fixture")
        XCTAssertEqual(snapshot.visibleBlocks.first?.kind, "heading")
        XCTAssertEqual(model.restorationSession?.rootPath, tempRoot.path)
        XCTAssertEqual(model.restorationSession?.selectedFile, "fixture.md")
    }

    @MainActor
    func testOpenFolderSelectionWinsOverPendingBootstrapLoad() async throws {
        let alphaWorkspace = repoRootURL
            .appendingPathComponent("Fixtures/window-workspaces/window-alpha", isDirectory: true)
        let launchFixtureRoot = repoRootURL
            .appendingPathComponent("Fixtures/docs", isDirectory: true)

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: launchFixtureRoot,
                openFile: "basic_typography.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        model.openFolder(at: alphaWorkspace)
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(model.restorationSession?.rootPath, alphaWorkspace.path)
        XCTAssertEqual(model.selectedPath?.rawValue, "alpha.md")
        XCTAssertEqual(model.windowTitle, "window-alpha > alpha.md")
    }

    @MainActor
    func testEmptyWorkspaceShowsNoMarkdownFilesMessage() async throws {
        let emptyWorkspace = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: emptyWorkspace, withIntermediateDirectories: true)

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: emptyWorkspace,
                openFile: nil,
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(model.files.isEmpty)
        XCTAssertNil(model.selectedPath)
        XCTAssertTrue(model.shouldShowEmptyWorkspaceState)
        XCTAssertFalse(model.shouldShowOpenFolderPromptState)
        XCTAssertEqual(model.documentText, AppModel.emptyWorkspaceMessage)
    }

    @MainActor
    func testAppModelUsesStructuredRendererForTableOnlyDocument() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let fileURL = tempRoot.appendingPathComponent("table.md")
        try """
        | Root | Region | Purpose |
        | --- | --- | --- |
        | `infra/bootstrap/state` | `ca-central-1` | Terraform remote state bucket, lock table, and KMS key |
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: tempRoot,
                openFile: "table.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(model.documentBlocks.map(\.kind), [.table])
        XCTAssertTrue(model.shouldRenderBlockContent)
    }

    @MainActor
    func testAppModelUsesStructuredRendererForCSVDocument() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try """
        Name,Count,Notes
        Alpha,1,"First row"
        Beta,2,"Second row"
        """.write(to: tempRoot.appendingPathComponent("table.csv"), atomically: true, encoding: .utf8)

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: tempRoot,
                openFile: "table.csv",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(model.selectedDocumentKind, .csv)
        XCTAssertEqual(model.documentBlocks.map(\.kind), [.table])
        XCTAssertTrue(model.shouldRenderBlockContent)
        XCTAssertTrue(model.shouldShowTabularControls)
        XCTAssertEqual(model.documentBlocks.first?.table?.header.map(\.plainText), ["Name", "Count", "Notes"])
    }

    @MainActor
    func testWindowScopedModelsKeepDifferentFoldersAfterOpeningNewWorkspace() async throws {
        let alphaWorkspace = repoRootURL
            .appendingPathComponent("Fixtures/window-workspaces/window-alpha", isDirectory: true)
        let betaWorkspace = repoRootURL
            .appendingPathComponent("Fixtures/window-workspaces/window-beta", isDirectory: true)

        let launchOptions = HarnessLaunchOptions(
            fixtureRoot: alphaWorkspace,
            openFile: "alpha.md",
            uiTestOpenFolderURL: nil,
            theme: nil,
            windowSize: nil,
            disableFileWatch: true,
            dumpVisibleStateURL: nil,
            dumpPerfStateURL: nil,
            screenshotPathURL: nil,
            commandDirectoryURL: nil,
            uiTestMode: true,
            platformTarget: .macos,
            deviceClass: .mac
        )

        let firstWindowModel = AppModel(launchOptions: launchOptions)
        let secondWindowModel = AppModel(launchOptions: launchOptions)

        firstWindowModel.bootstrap()
        secondWindowModel.bootstrap()
        secondWindowModel.openFolder(at: betaWorkspace)
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(firstWindowModel.restorationSession?.rootPath, alphaWorkspace.path)
        XCTAssertEqual(firstWindowModel.selectedPath?.rawValue, "alpha.md")
        XCTAssertEqual(firstWindowModel.windowTitle, "window-alpha > alpha.md")

        XCTAssertEqual(secondWindowModel.restorationSession?.rootPath, betaWorkspace.path)
        XCTAssertEqual(secondWindowModel.selectedPath?.rawValue, "beta.md")
        XCTAssertEqual(secondWindowModel.windowTitle, "window-beta > beta.md")
    }

    @MainActor
    func testWindowTitleUsesWorkspaceFolderAndFilename() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let fileURL = tempRoot.appendingPathComponent("notes.md")
        try "# Notes".write(to: fileURL, atomically: true, encoding: .utf8)

        let options = HarnessLaunchOptions(
            fixtureRoot: tempRoot,
            openFile: "notes.md",
            uiTestOpenFolderURL: nil,
            theme: nil,
            windowSize: nil,
            disableFileWatch: true,
            dumpVisibleStateURL: nil,
            dumpPerfStateURL: nil,
            screenshotPathURL: nil,
            commandDirectoryURL: nil,
            uiTestMode: true,
            platformTarget: .macos,
            deviceClass: .mac
        )

        let model = AppModel(launchOptions: options)
        model.bootstrap()

        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(model.windowTitle, "\(tempRoot.lastPathComponent) > notes.md")
    }

    @MainActor
    func testAppModelRestoresInitialWorkspaceSession() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "# Alpha".write(to: tempRoot.appendingPathComponent("alpha.md"), atomically: true, encoding: .utf8)
        try "# Beta".write(to: tempRoot.appendingPathComponent("beta.md"), atomically: true, encoding: .utf8)

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: nil,
                openFile: nil,
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: false,
                platformTarget: .macos,
                deviceClass: .mac
            ),
            initialSession: WorkspaceWindowSession(
                rootPath: tempRoot.path,
                selectedFile: "beta.md",
                securityScopedBookmarkData: nil
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 1_000_000_000)

        XCTAssertFalse(model.shouldAutoPromptForFolderOnLaunch)
        XCTAssertEqual(model.selectedPath?.rawValue, "beta.md")
        XCTAssertEqual(model.windowTitle, "\(tempRoot.lastPathComponent) > beta.md")
        XCTAssertEqual(model.restorationSession?.rootPath, tempRoot.path)
        XCTAssertEqual(model.restorationSession?.selectedFile, "beta.md")
    }

    @MainActor
    func testAppModelOpenFolderSelectsRequestedFileOverride() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "# Alpha".write(to: tempRoot.appendingPathComponent("alpha.md"), atomically: true, encoding: .utf8)
        try "# Beta".write(to: tempRoot.appendingPathComponent("beta.md"), atomically: true, encoding: .utf8)

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: nil,
                openFile: nil,
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )
        retainForTestLifetime(model)

        model.openFolder(at: tempRoot, selectedPathOverride: WorkspacePath(rawValue: "beta.md"))
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(model.currentWorkspaceRootURL?.path, tempRoot.path)
        XCTAssertEqual(model.selectedPath?.rawValue, "beta.md")
        XCTAssertEqual(model.windowTitle, "\(tempRoot.lastPathComponent) > beta.md")
    }

    func testWorkspaceProviderReturnsRelativePathsForTemporaryRoots() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "# Alpha".write(to: tempRoot.appendingPathComponent("alpha.md"), atomically: true, encoding: .utf8)
        try "# Beta".write(to: tempRoot.appendingPathComponent("beta.md"), atomically: true, encoding: .utf8)

        let provider = LocalWorkspaceProvider(rootURL: tempRoot, embeddedDocs: EmbeddedFixtures.docs)
        let workspace = try provider.loadRoot()

        XCTAssertEqual(workspace.files.map(\.path.rawValue), ["alpha.md", "beta.md"])
    }

    func testWorkspaceProviderIncludesCommonMarkdownExtensions() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "# Notes".write(to: tempRoot.appendingPathComponent("notes.markdown"), atomically: true, encoding: .utf8)
        try "# Draft".write(to: tempRoot.appendingPathComponent("draft.mkd"), atomically: true, encoding: .utf8)
        try "# Ignore".write(to: tempRoot.appendingPathComponent("ignore.txt"), atomically: true, encoding: .utf8)

        let provider = LocalWorkspaceProvider(rootURL: tempRoot, embeddedDocs: EmbeddedFixtures.docs)
        let workspace = try provider.loadRoot()

        XCTAssertEqual(workspace.files.map(\.path.rawValue), ["draft.mkd", "notes.markdown"])
    }

    func testWorkspaceProviderIncludesDelimitedTextExtensions() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "Name,Count\nAlpha,1".write(to: tempRoot.appendingPathComponent("table.csv"), atomically: true, encoding: .utf8)
        try "Name\tCount\nBeta\t2".write(to: tempRoot.appendingPathComponent("table.tsv"), atomically: true, encoding: .utf8)

        let provider = LocalWorkspaceProvider(rootURL: tempRoot, embeddedDocs: EmbeddedFixtures.docs)
        let workspace = try provider.loadRoot()

        XCTAssertEqual(workspace.files.map(\.path.rawValue), ["table.csv", "table.tsv"])
        XCTAssertEqual(workspace.files.map(\.kind), [.csv, .tsv])
    }

    func testWorkspaceProviderIgnoresDefaultDependencyDirectories() throws {
        let workspace = try makeTemporaryWorkspace(named: "Ignored Defaults", files: [
            "README.md": "# Visible",
            "node_modules/package/README.md": "# Hidden",
            "venv/docs/env.md": "# Hidden",
            ".venv/docs/env.md": "# Hidden",
            "vendor/docs/vendor.md": "# Hidden"
        ])

        let provider = LocalWorkspaceProvider(rootURL: workspace, embeddedDocs: EmbeddedFixtures.docs)
        let root = try provider.loadRoot()

        XCTAssertEqual(root.files.map(\.path.rawValue), ["README.md"])
    }

    func testWorkspaceProviderUsesCustomIgnorePatterns() throws {
        let workspace = try makeTemporaryWorkspace(named: "Custom Ignores", files: [
            "README.md": "# Visible",
            "drafts/notes.md": "# Hidden",
            "generated/one.md": "# Hidden",
            "node_modules/package/README.md": "# Visible when defaults are replaced"
        ])

        let provider = LocalWorkspaceProvider(
            rootURL: workspace,
            embeddedDocs: EmbeddedFixtures.docs,
            ignorePatterns: WorkspaceIgnorePatterns(commaSeparated: "drafts, generated/*.md")
        )
        let root = try provider.loadRoot()

        XCTAssertEqual(Set(root.files.map(\.path.rawValue)), Set(["node_modules/package/README.md", "README.md"]))
        XCTAssertEqual(root.files.count, 2)
    }

    @MainActor
    func testAppModelReloadsCurrentWindowWhenIgnorePatternsChange() async throws {
        let workspace = try makeTemporaryWorkspace(named: "Ignore Reload", files: [
            "README.md": "# Visible",
            "vendor/docs/vendor.md": "# Hidden by default"
        ])
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: nil,
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(model.files.map(\.path.rawValue), ["README.md"])

        model.updateWorkspaceIgnorePatterns(from: "")
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(Set(model.files.map(\.path.rawValue)), Set(["README.md", "vendor/docs/vendor.md"]))
        XCTAssertEqual(model.files.count, 2)
        XCTAssertEqual(model.restorationSession?.ignorePatterns, WorkspaceIgnorePatterns(patterns: []))
    }

    func testGitHubWorkspaceURLResolvesDefaultBranchForRepoRoot() async throws {
        let fixtureURL = try makeGitHubFixtureFile()
        let (service, _) = try makeGitHubWorkspaceService(fixtureURL: fixtureURL)

        let workspace = try await service.loadWorkspace(from: "https://github.com/moorage/free-markdown-viewer/")

        XCTAssertEqual(workspace.descriptor.requestedRef, "main")
        XCTAssertEqual(workspace.descriptor.resolvedCommitSHA, "sha-main")
        let provider = GitHubWorkspaceProvider(cachedRootURL: workspace.cacheRootURL, descriptor: workspace.descriptor)
        let root = try provider.loadRoot()
        XCTAssertEqual(root.files.map(\.path.rawValue), ["docs/guide.md", "README.md"])
    }

    func testGitHubWorkspaceProviderIncludesDelimitedDocuments() async throws {
        let fixtureURL = try makeGitHubFixtureFile(includeDelimitedDocuments: true)
        let (service, _) = try makeGitHubWorkspaceService(fixtureURL: fixtureURL)

        let workspace = try await service.loadWorkspace(from: "https://github.com/moorage/free-markdown-viewer/tree/main/docs")
        let provider = GitHubWorkspaceProvider(cachedRootURL: workspace.cacheRootURL, descriptor: workspace.descriptor)
        let root = try provider.loadRoot()

        XCTAssertEqual(root.files.map(\.path.rawValue), ["guide.md", "metrics.csv"])
        XCTAssertEqual(root.files.map(\.kind), [.markdown, .csv])
    }

    func testGitHubWorkspaceURLResolvesBranchAndTagTreeRefs() async throws {
        let fixtureURL = try makeGitHubFixtureFile()
        let (service, _) = try makeGitHubWorkspaceService(fixtureURL: fixtureURL)

        let branchWorkspace = try await service.loadWorkspace(
            from: "https://github.com/moorage/free-markdown-viewer/tree/main/docs"
        )
        XCTAssertEqual(branchWorkspace.descriptor.requestedRef, "main")
        XCTAssertEqual(branchWorkspace.descriptor.subdirectory, "docs")
        XCTAssertEqual(
            try String(contentsOf: branchWorkspace.cacheRootURL.appendingPathComponent("guide.md"), encoding: .utf8),
            "# Guide\n\nLoaded from docs."
        )

        let tagWorkspace = try await service.loadWorkspace(
            from: "https://github.com/moorage/cxhere/tree/0.1.1"
        )
        XCTAssertEqual(tagWorkspace.descriptor.requestedRef, "0.1.1")
        XCTAssertEqual(tagWorkspace.descriptor.resolvedCommitSHA, "sha-tag")
        XCTAssertEqual(
            try String(contentsOf: tagWorkspace.cacheRootURL.appendingPathComponent("CHANGELOG.md"), encoding: .utf8),
            "# Changelog\n\nTag release."
        )
    }

    func testGitHubWorkspaceCacheReopensWhenOffline() async throws {
        let fixtureURL = try makeGitHubFixtureFile()
        let (onlineService, cacheDirectoryURL) = try makeGitHubWorkspaceService(fixtureURL: fixtureURL)
        let cachedWorkspace = try await onlineService.loadWorkspace(from: "https://github.com/moorage/free-markdown-viewer")
        let offlineService = GitHubWorkspaceService(
            remoteClient: FailingGitHubRemoteClient(error: GitHubWorkspaceError.httpStatus(503)),
            cacheDirectoryURL: cacheDirectoryURL
        )
        let reopenedWorkspace = try await offlineService.loadWorkspace(from: "https://github.com/moorage/free-markdown-viewer")

        XCTAssertEqual(reopenedWorkspace.cacheRootURL.path, cachedWorkspace.cacheRootURL.path)
        XCTAssertEqual(reopenedWorkspace.descriptor.resolvedCommitSHA, "sha-main")
    }

    @MainActor
    func testRestoredGitHubWorkspaceSessionUsesCachedSnapshot() async throws {
        let fixtureURL = try makeGitHubFixtureFile()
        let options = HarnessLaunchOptions(
            fixtureRoot: nil,
            openFile: nil,
            uiTestOpenFolderURLs: [],
            uiTestInstallCommandLineToolURL: nil,
            uiTestGitHubFixtureURL: fixtureURL,
            uiTestOpenLinkedMediaURL: nil,
            uiTestResetCommandLineToolInstallState: false,
            theme: nil,
            windowSize: nil,
            disableFileWatch: true,
            dumpVisibleStateURL: nil,
            dumpPerfStateURL: nil,
            screenshotPathURL: nil,
            commandDirectoryURL: nil,
            uiTestMode: true,
            platformTarget: .macos,
            deviceClass: .mac
        )
        let (service, _) = try makeGitHubWorkspaceService(fixtureURL: fixtureURL)
        let cachedWorkspace = try await service.loadWorkspace(from: "https://github.com/moorage/free-markdown-viewer/tree/main/docs")

        let session = WorkspaceWindowSession(
            source: .github(
                GitHubWorkspaceSessionSource(
                    originalURLString: cachedWorkspace.descriptor.originalURLString,
                    cachedRootPath: cachedWorkspace.cacheRootURL.path,
                    descriptor: cachedWorkspace.descriptor
                )
            ),
            selectedFile: "guide.md"
        )

        let model = AppModel(
            launchOptions: options,
            initialSession: session,
            githubWorkspaceLoader: service
        )
        retainForTestLifetime(model)
        model.bootstrap()
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(model.selectedPath?.rawValue, "guide.md")
        XCTAssertEqual(model.windowTitle, "\(cachedWorkspace.descriptor.displayRoot) > guide.md")
        XCTAssertEqual(model.restorationSession?.selectedFile, "guide.md")
        XCTAssertFalse(model.canRevealSelectedFileInFinder)
    }

    @MainActor
    func testPrintSelectedDocumentUsesCurrentSelection() async throws {
        let workspace = try makeTemporaryWorkspace(named: "Print Workspace", files: [
            "alpha.md": "# Alpha\n\nFirst file.",
            "table.csv": "Name,Count\nAlpha,1\nBeta,2"
        ])

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "table.csv",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)
        let composition = try await model.makePrintComposition(scope: .selectedFile)

        XCTAssertEqual(composition.sections.map(\.title), ["table.csv"])
        XCTAssertTrue(composition.plainText.contains("Name | Count"))
        XCTAssertTrue(composition.plainText.contains("Alpha | 1"))
    }

    @MainActor
    func testPrintAllDocumentsUsesWorkspaceOrder() async throws {
        let workspace = try makeTemporaryWorkspace(named: "Print All Workspace", files: [
            "beta.tsv": "Name\tCount\nBeta\t2",
            "alpha.md": "# Alpha\n\nFirst file.",
            "table.csv": "Name,Count\nAlpha,1"
        ])

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "alpha.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)
        let composition = try await model.makePrintComposition(scope: .allFiles)

        XCTAssertEqual(composition.sections.map(\.title), ["alpha.md", "beta.tsv", "table.csv"])
        XCTAssertTrue(composition.plainText.contains("=== alpha.md ==="))
        XCTAssertTrue(composition.plainText.contains("=== beta.tsv ==="))
        XCTAssertTrue(composition.plainText.contains("=== table.csv ==="))
    }

    @MainActor
    func testExportPrintedDocumentHarnessCommandWritesPDF() async throws {
        let workspace = try makeTemporaryWorkspace(named: "Print PDF Workspace", files: [
            "table.csv": "Team,Project,Status,Quarter,Notes\nReader,Table Controls,Shipped,Q2,Wrap keeps long notes readable.\nPlatform,GitHub Workspaces,Planned,Q3,Cached mirrors reopen offline."
        ])
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("printed.pdf")

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "table.csv",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        let response = await model.handleCommand(
            HarnessCommandRequest(
                id: UUID().uuidString,
                command: "exportPrintedDocument",
                arguments: ["path": outputURL.path]
            )
        )

        XCTAssertEqual(response.status, "ok")
        let data = try Data(contentsOf: outputURL)
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 500)
        let document = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)
    }

    @MainActor
    func testExportPrintedMarkdownDocumentWithRichFeaturesWritesExpectedPDFContent() async throws {
        let workspace = try makeTemporaryWorkspace(named: "Rich Print PDF Workspace", files: [
            "guide.md": """
            # Print Test

            ## Nested Features

            This paragraph includes `inline code` and **strong text**.

            - First bullet
            - Second bullet with `token`

            | Area | Status | Notes |
            | --- | --- | --- |
            | Reader | Ready | Prints tables |
            | Platform | Active | Includes images |

            ```swift
            struct Greeter {
                let name: String

                func message() -> String {
                    "Hello, \\(name)"
                }
            }
            ```

            ![Rickrolled PNG](media/rickrolled.png)
            """
        ])
        let sourceImageURL = repoRootURL.appendingPathComponent("Fixtures/media/rickrolled.png")
        let destinationImageURL = workspace.appendingPathComponent("media/rickrolled.png")
        try FileManager.default.createDirectory(at: destinationImageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceImageURL, to: destinationImageURL)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("rich-printed.pdf")

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "guide.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        let response = await model.handleCommand(
            HarnessCommandRequest(
                id: UUID().uuidString,
                command: "exportPrintedDocument",
                arguments: ["path": outputURL.path]
            )
        )

        XCTAssertEqual(response.status, "ok")
        let data = try Data(contentsOf: outputURL)
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 8_000)
        let document = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)
    }

    #if os(iOS)
    @MainActor
    func testExportPrintedMarkdownImageDocumentRendersImagePixelsOnIOS() async throws {
        let workspace = try makeTemporaryWorkspace(named: "Image Print PDF Workspace", files: [
            "image_only.md": "![Synthetic Print Image](media/print_colors.png)"
        ])
        let destinationImageURL = workspace.appendingPathComponent("media/print_colors.png")
        try FileManager.default.createDirectory(at: destinationImageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeSyntheticPrintImage(to: destinationImageURL)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("image-only-printed.pdf")

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "image_only.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .ios,
                deviceClass: .iphone
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        let response = await model.handleCommand(
            HarnessCommandRequest(
                id: UUID().uuidString,
                command: "exportPrintedDocument",
                arguments: ["path": outputURL.path]
            )
        )

        XCTAssertEqual(response.status, "ok")
        let pageImage = try firstPDFPageCGImage(from: outputURL, size: DocumentPrintPageLayout.letter.paperSize)
        let stats = try quantizedColorStats(
            for: pageImage,
            cropRect: CGRect(x: 56, y: 84, width: 500, height: 210),
            quantizationStep: 24
        )

        XCTAssertGreaterThan(stats.uniqueCount, 12)
        XCTAssertLessThan(stats.dominantShare, 0.35)
    }
    #endif

    @MainActor
    func testExportPrintedAllDocumentsWritesMixedMarkdownAndCSVContentToSinglePDF() async throws {
        let workspace = try makeTemporaryWorkspace(named: "Print All PDF Workspace", files: [
            "guide.md": """
            # Release Guide

            ## Highlights

            This guide includes `inline code`, a nested list, and a table.

            - Checklist
            - Notes

            | Area | Status |
            | --- | --- |
            | Printing | Stable |
            | Tables | Included |

            ```swift
            enum ExportMode {
                case printable
            }
            ```

            ![Rickrolled PNG](media/rickrolled.png)
            """,
            "metrics.csv": """
            Team,Project,Quarter,Notes
            Reader,Print All,Q2,Exports markdown and CSV together.
            Platform,GitHub,Q3,Cached repositories stay available offline.
            """
        ])
        let sourceImageURL = repoRootURL.appendingPathComponent("Fixtures/media/rickrolled.png")
        let destinationImageURL = workspace.appendingPathComponent("media/rickrolled.png")
        try FileManager.default.createDirectory(at: destinationImageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceImageURL, to: destinationImageURL)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("print-all-mixed.pdf")

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "guide.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        let response = await model.handleCommand(
            HarnessCommandRequest(
                id: UUID().uuidString,
                command: "exportPrintedAllDocuments",
                arguments: ["path": outputURL.path]
            )
        )

        XCTAssertEqual(response.status, "ok")
        let data = try Data(contentsOf: outputURL)
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 10_000)
        let document = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)
    }

    @MainActor
    func testExportPrintedAllDocumentsPaginatesLongWorkspaceIntoMultiplePages() async throws {
        let repeatedBody = (1...220).map { "Paragraph \($0)" }.joined(separator: "\n\n")
        let workspace = try makeTemporaryWorkspace(named: "Long Print All Workspace", files: [
            "alpha.md": "# Alpha\n\n\(repeatedBody)",
            "beta.md": "# Beta\n\n\(repeatedBody)",
            "gamma.md": "# Gamma\n\n\(repeatedBody)"
        ])

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("print-all-long.pdf")

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "alpha.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        let response = await model.handleCommand(
            HarnessCommandRequest(
                id: UUID().uuidString,
                command: "exportPrintedAllDocuments",
                arguments: ["path": outputURL.path]
            )
        )

        XCTAssertEqual(response.status, "ok")
        let data = try Data(contentsOf: outputURL)
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 50_000)
        let document = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertGreaterThan(document.pageCount, 1)
    }

    @MainActor
    func testAppModelExposesCurrentDocumentURLForWorkspaceBackedFile() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "# Notes".write(to: tempRoot.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: tempRoot,
                openFile: "notes.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )

        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(model.canRevealSelectedFileInFinder)
        XCTAssertEqual(model.selectedFileURL?.path, tempRoot.appendingPathComponent("notes.md").path)
    }

    @MainActor
    func testAdjacentFilePathMovesSidebarSelection() {
        let files = [
            MarkdownFileNode(path: WorkspacePath(rawValue: "alpha.md"), name: "alpha.md", kind: .markdown),
            MarkdownFileNode(path: WorkspacePath(rawValue: "beta.md"), name: "beta.md", kind: .markdown),
            MarkdownFileNode(path: WorkspacePath(rawValue: "gamma.md"), name: "gamma.md", kind: .markdown),
        ]

        XCTAssertEqual(
            AppModel.adjacentFilePath(from: WorkspacePath(rawValue: "alpha.md"), within: files, offset: 1)?.rawValue,
            "beta.md"
        )
        XCTAssertEqual(
            AppModel.adjacentFilePath(from: WorkspacePath(rawValue: "beta.md"), within: files, offset: 1)?.rawValue,
            "gamma.md"
        )
        XCTAssertNil(
            AppModel.adjacentFilePath(from: WorkspacePath(rawValue: "gamma.md"), within: files, offset: 1)
        )
        XCTAssertEqual(
            AppModel.adjacentFilePath(from: WorkspacePath(rawValue: "gamma.md"), within: files, offset: -1)?.rawValue,
            "beta.md"
        )
        XCTAssertEqual(
            AppModel.adjacentFilePath(from: nil, within: files, offset: 1)?.rawValue,
            "alpha.md"
        )
        XCTAssertEqual(
            AppModel.adjacentFilePath(from: nil, within: files, offset: -1)?.rawValue,
            "gamma.md"
        )
    }

    func testMarkdownRendererParsesMultipleBlockKinds() {
        let markdown = """
        # Heading

        Intro with **bold** text.

        - Item one
        1. Item two

        > Quote line

        ```
        let x = 1
        ```
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)

        XCTAssertEqual(blocks.map(\.kind), [.heading, .paragraph, .unorderedListItem, .orderedListItem, .blockquote, .codeBlock])
        XCTAssertEqual(blocks[0].plainText, "Heading")
        XCTAssertEqual(blocks[1].plainText, "Intro with bold text.")
        XCTAssertEqual(blocks[5].plainText, "let x = 1")
    }

    func testSelectableDocumentFormatterUsesRenderedDocumentText() {
        let markdown = """
        # Heading

        Intro with **bold** text.

        - Item one
        1. Item two

        ```
        let x = 1
        ```
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)
        let rendered = SelectableDocumentFormatter.attributedText(from: blocks, fontScale: 1).string

        XCTAssertTrue(rendered.contains("Heading"))
        XCTAssertTrue(rendered.contains("Intro with bold text."))
        XCTAssertTrue(rendered.contains("- Item one"))
        XCTAssertTrue(rendered.contains("1. Item two"))
        XCTAssertTrue(rendered.contains("let x = 1"))
        XCTAssertFalse(rendered.contains("# Heading"))
        XCTAssertFalse(rendered.contains("**bold**"))
        XCTAssertFalse(rendered.contains("```"))
    }

    func testSelectableDocumentFormatterPreservesRelativeMarkdownLinks() {
        let blocks = MarkdownRenderer.blocks(from: "[Release notes](./release-notes.md)")
        let rendered = SelectableDocumentFormatter.attributedText(from: blocks, fontScale: 1)
        let nsRange = NSRange(location: 0, length: rendered.length)
        var linkedURLs: [URL] = []

        rendered.enumerateAttribute(.link, in: nsRange) { value, _, _ in
            guard let url = value as? URL else { return }
            linkedURLs.append(url)
        }

        XCTAssertEqual(linkedURLs, [URL(string: "./release-notes.md")!])
    }

    func testMarkdownRendererParsesIndentedCodeBlockFromSpecExample() {
        let markdown = """
            a simple
              indented code block
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)

        XCTAssertEqual(blocks.map(\.kind), [.codeBlock])
        XCTAssertEqual(blocks[0].plainText, "a simple\n  indented code block")
    }

    func testMarkdownRendererMarksIndentedCodeBlocksAsPlainFallback() throws {
        let markdown = """
            a simple
              indented code block
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)
        let codeBlock = try XCTUnwrap(blocks.first?.codeBlock)

        XCTAssertFalse(codeBlock.isFenced)
        XCTAssertNil(codeBlock.language)
        XCTAssertNil(CodeBlockSyntaxHighlighter.highlightedAttributedText(
            for: codeBlock,
            theme: SyntaxHighlightTheme(identifier: "system-light", style: .light),
            fontScale: 1
        ))
    }

    func testMarkdownRendererAnnotatesFencedCodeBlocksWithNormalizedLanguage() throws {
        let markdown = """
        ```sh
        echo hello
        ```
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)
        let codeBlock = try XCTUnwrap(blocks.first?.codeBlock)

        XCTAssertTrue(codeBlock.isFenced)
        XCTAssertEqual(codeBlock.infoString, "sh")
        XCTAssertEqual(codeBlock.rawLanguage, "sh")
        XCTAssertEqual(codeBlock.language, .bash)
        XCTAssertNotNil(CodeBlockSyntaxHighlighter.highlightedAttributedText(
            for: codeBlock,
            theme: SyntaxHighlightTheme(identifier: "system-light", style: .light),
            fontScale: 1
        ))
    }

    func testMarkdownRendererFallsBackForUnknownFenceLanguage() throws {
        let markdown = """
        ```brainheck
        ++--
        ```
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)
        let codeBlock = try XCTUnwrap(blocks.first?.codeBlock)

        XCTAssertTrue(codeBlock.isFenced)
        XCTAssertEqual(codeBlock.infoString, "brainheck")
        XCTAssertNil(codeBlock.language)
        XCTAssertNil(CodeBlockSyntaxHighlighter.highlightedAttributedText(
            for: codeBlock,
            theme: SyntaxHighlightTheme(identifier: "system-light", style: .light),
            fontScale: 1
        ))
    }

    func testCodeBlockSyntaxHighlighterCachesByLanguageContentHashAndTheme() {
        CodeBlockSyntaxHighlighter.resetCacheForTests()

        let lightTheme = SyntaxHighlightTheme(identifier: "system-light", style: .light)
        let darkTheme = SyntaxHighlightTheme(identifier: "system-dark", style: .dark)
        let bashBlock = MarkdownCodeBlock(
            code: "echo hello",
            infoString: "bash",
            rawLanguage: "bash",
            language: .bash,
            isFenced: true
        )
        let bashVariant = MarkdownCodeBlock(
            code: "echo goodbye",
            infoString: "bash",
            rawLanguage: "bash",
            language: .bash,
            isFenced: true
        )
        let jsonBlock = MarkdownCodeBlock(
            code: "{\"message\": \"hello\"}",
            infoString: "json",
            rawLanguage: "json",
            language: .json,
            isFenced: true
        )

        _ = CodeBlockSyntaxHighlighter.highlightedAttributedText(for: bashBlock, theme: lightTheme, fontScale: 1)
        XCTAssertEqual(CodeBlockSyntaxHighlighter.cachedEntryCountForTests(), 1)

        _ = CodeBlockSyntaxHighlighter.highlightedAttributedText(for: bashBlock, theme: lightTheme, fontScale: 1)
        XCTAssertEqual(CodeBlockSyntaxHighlighter.cachedEntryCountForTests(), 1)

        _ = CodeBlockSyntaxHighlighter.highlightedAttributedText(for: bashBlock, theme: darkTheme, fontScale: 1)
        XCTAssertEqual(CodeBlockSyntaxHighlighter.cachedEntryCountForTests(), 2)

        _ = CodeBlockSyntaxHighlighter.highlightedAttributedText(for: bashVariant, theme: lightTheme, fontScale: 1)
        XCTAssertEqual(CodeBlockSyntaxHighlighter.cachedEntryCountForTests(), 3)

        _ = CodeBlockSyntaxHighlighter.highlightedAttributedText(for: jsonBlock, theme: lightTheme, fontScale: 1)
        XCTAssertEqual(CodeBlockSyntaxHighlighter.cachedEntryCountForTests(), 4)
    }

    func testMarkdownRendererParsesTableFromSpecExample() {
        let markdown = """
        | abc | defghi |
        :-: | -----------:
        bar | baz
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)

        XCTAssertEqual(blocks.map(\.kind), [.table])
        XCTAssertEqual(blocks[0].plainText, "abc defghi bar baz")
        XCTAssertEqual(blocks[0].table?.header.map(\.plainText), ["abc", "defghi"])
        XCTAssertEqual(blocks[0].table?.rows.map { $0.map(\.plainText) }, [["bar", "baz"]])
        XCTAssertEqual(blocks[0].table?.alignments, [.center, .trailing])
    }

    func testMarkdownRendererParsesTerraformStylePipeTable() {
        let markdown = """
        | Root | Region | Purpose |
        | --- | --- | --- |
        | `infra/bootstrap/state` | `ca-central-1` | Terraform remote state bucket, lock table, and KMS key |
        | `infra/live/prod/mx-central-1` | `mx-central-1` | Primary production stack in Mexico |
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)

        XCTAssertEqual(blocks.map(\.kind), [.table])
        XCTAssertEqual(blocks[0].table?.header.map(\.plainText), ["Root", "Region", "Purpose"])
        XCTAssertEqual(
            blocks[0].table?.rows.map { $0.map(\.plainText) },
            [
                ["infra/bootstrap/state", "ca-central-1", "Terraform remote state bucket, lock table, and KMS key"],
                ["infra/live/prod/mx-central-1", "mx-central-1", "Primary production stack in Mexico"],
            ]
        )
        XCTAssertEqual(blocks[0].table?.alignments, [.leading, .leading, .leading])
    }

    func testMarkdownRendererPreservesRelativeLinksInsideTables() throws {
        let markdown = """
        | Document |
        | --- |
        | [Submission](./app-store-submission.md) |
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)
        let cell = try XCTUnwrap(blocks.first?.table?.rows.first?.first)

        XCTAssertEqual(cell.plainText, "Submission")
        XCTAssertEqual(cell.attributedText?.runs.first?.link, URL(string: "./app-store-submission.md"))
    }

    func testMarkdownRendererPreservesBlockSemanticsAroundTable() {
        let markdown = """
        # Heading

        Intro paragraph.

        | abc | defghi |
        :-: | -----------:
        bar | baz

        ## Follow-up

        Tail paragraph.
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)

        XCTAssertEqual(blocks.map(\.kind), [.heading, .paragraph, .table, .heading, .paragraph])
        XCTAssertEqual(blocks[0].plainText, "Heading")
        XCTAssertEqual(blocks[1].plainText, "Intro paragraph.")
        XCTAssertEqual(blocks[2].table?.header.map(\.plainText), ["abc", "defghi"])
        XCTAssertEqual(blocks[3].plainText, "Follow-up")
        XCTAssertEqual(blocks[4].plainText, "Tail paragraph.")
    }

    func testMarkdownRendererParsesImportedSafariBackedFixtures() throws {
        let tabsFixture = repoRootURL
            .appendingPathComponent("Fixtures/expected/spec-safari/commonmark/0001-tabs-example-1/input.md")
        let tableFixture = repoRootURL
            .appendingPathComponent("Fixtures/expected/spec-safari/gfm/0198-tables-extension-example-198/input.md")

        let tabsBlocks = MarkdownRenderer.blocks(from: try String(contentsOf: tabsFixture, encoding: .utf8))
        let tableBlocks = MarkdownRenderer.blocks(from: try String(contentsOf: tableFixture, encoding: .utf8))

        XCTAssertEqual(tabsBlocks.map(\.kind), [.codeBlock])
        XCTAssertEqual(tabsBlocks.first?.sourceText, "foo\tbaz\t\tbim")
        XCTAssertEqual(tableBlocks.map(\.kind), [.table])
        XCTAssertEqual(tableBlocks.first?.table?.header.map(\.plainText), ["foo", "bar"])
        XCTAssertEqual(tableBlocks.first?.table?.rows.map { $0.map(\.plainText) }, [["baz", "bim"]])
    }

    @MainActor
    func testAppModelOpensRelativeMarkdownLinkWithinWorkspace() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let docsRoot = tempRoot.appendingPathComponent("docs", isDirectory: true)
        try FileManager.default.createDirectory(at: docsRoot, withIntermediateDirectories: true)
        try "# Index\n\n[Submission](./app-store-submission.md)\n".write(
            to: docsRoot.appendingPathComponent("index.md"),
            atomically: true,
            encoding: .utf8
        )
        try "# Submission\n".write(
            to: docsRoot.appendingPathComponent("app-store-submission.md"),
            atomically: true,
            encoding: .utf8
        )

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: tempRoot,
                openFile: "docs/index.md",
                uiTestOpenFolderURL: nil,
                theme: nil,
                windowSize: nil,
                disableFileWatch: true,
                dumpVisibleStateURL: nil,
                dumpPerfStateURL: nil,
                screenshotPathURL: nil,
                commandDirectoryURL: nil,
                uiTestMode: true,
                platformTarget: .macos,
                deviceClass: .mac
            )
        )
        retainForTestLifetime(model)
        model.bootstrap()

        let loaded = expectation(description: "index file loads")
        Task { @MainActor in
            for _ in 0..<20 {
                if model.selectedPath?.rawValue == "docs/index.md" {
                    loaded.fulfill()
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        wait(for: [loaded], timeout: 2)

        XCTAssertTrue(model.openMarkdownLink(URL(string: "./app-store-submission.md")!))
        XCTAssertEqual(model.selectedPath?.rawValue, "docs/app-store-submission.md")
    }

    func testMarkdownRendererParsesNestedAndTaskListItems() {
        let markdown = "- [ ] top level\n  - child\n    1. nested ordered\n- [x] done"

        let blocks = MarkdownRenderer.blocks(from: markdown)

        XCTAssertEqual(blocks.map(\.kind), [.unorderedListItem, .unorderedListItem])
        XCTAssertEqual(blocks.map(\.indentLevel), [0, 0])
        XCTAssertEqual(blocks.map(\.plainText), ["top level", "done"])
        XCTAssertEqual(blocks.map(\.isTaskItem), [true, true])
        XCTAssertEqual(blocks.map(\.isTaskCompleted), [false, true])
        XCTAssertEqual(blocks.first?.children.map(\.kind), [.unorderedListItem])
        XCTAssertEqual(blocks.first?.children.first?.plainText, "child")
        XCTAssertEqual(blocks.first?.children.first?.children.map(\.kind), [.orderedListItem])
        XCTAssertEqual(blocks.first?.children.first?.children.first?.plainText, "nested ordered")
    }

    func testAppModelFiltersFilesByQuickFilterQuery() {
        let files = [
            MarkdownFileNode(path: WorkspacePath(rawValue: "docs/release/index.md"), name: "index.md", kind: .markdown),
            MarkdownFileNode(path: WorkspacePath(rawValue: "docs/release/app-store-submission.md"), name: "app-store-submission.md", kind: .markdown),
            MarkdownFileNode(path: WorkspacePath(rawValue: "notes/todo.md"), name: "todo.md", kind: .markdown),
        ]

        XCTAssertEqual(
            AppModel.filteredFiles(from: files, matching: "app store").map(\.path.rawValue),
            ["docs/release/app-store-submission.md"]
        )
        XCTAssertEqual(
            AppModel.filteredFiles(from: files, matching: "release").map(\.path.rawValue),
            ["docs/release/index.md", "docs/release/app-store-submission.md"]
        )
        XCTAssertEqual(AppModel.filteredFiles(from: files, matching: "   ").count, files.count)
    }

    func testMarkdownRendererParsesDirectImageFixture() {
        let markdown = #"![foo](/url "title")"#

        let blocks = MarkdownRenderer.blocks(from: markdown)

        XCTAssertEqual(blocks.map(\.kind), [.image])
        XCTAssertEqual(blocks.first?.plainText, "")
        XCTAssertEqual(blocks.first?.image?.altText, "foo")
        XCTAssertEqual(blocks.first?.image?.sourceURL, "/url")
        XCTAssertEqual(blocks.first?.image?.title, "title")
    }

    func testMarkdownRendererParsesReferenceImageFixture() {
        let markdown = """
        ![foo *bar*]

        [foo *bar*]: train.jpg "train & tracks"
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)

        XCTAssertEqual(blocks.map(\.kind), [.image])
        XCTAssertEqual(blocks.first?.image?.altText, "foo bar")
        XCTAssertEqual(blocks.first?.image?.sourceURL, "train.jpg")
        XCTAssertEqual(blocks.first?.image?.title, "train & tracks")
    }

    func testMarkdownRendererParsesRawHTMLFixture() {
        let markdown = "<a><bab><c2c>"

        let blocks = MarkdownRenderer.blocks(from: markdown)

        XCTAssertEqual(blocks.map(\.kind), [.rawHTML])
        XCTAssertEqual(blocks.first?.plainText, "")
        XCTAssertEqual(blocks.first?.sourceText, "<a><bab><c2c>")
    }

    func testMarkdownRendererGroupsListChildrenFromCommonMarkFixture256() throws {
        let fixture = repoRootURL
            .appendingPathComponent("Fixtures/expected/spec-safari/commonmark/0256-list-items-example-256/input.md")

        let blocks = MarkdownRenderer.blocks(from: try String(contentsOf: fixture, encoding: .utf8))

        XCTAssertEqual(blocks.map(\.kind), [.orderedListItem])
        XCTAssertEqual(blocks.first?.plainText, "A paragraph with two lines.")
        XCTAssertEqual(blocks.first?.children.map(\.kind), [.codeBlock, .blockquote])
        XCTAssertEqual(blocks.first?.children.first?.plainText, "indented code")
        XCTAssertEqual(blocks.first?.children.last?.plainText, "A block quote.")
    }

    @MainActor
    func testStateSnapshotFlattensNestedListChildren() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let fileURL = tempRoot.appendingPathComponent("fixture.md")
        try """
        1.  A paragraph
            with two lines.

                indented code

            > A block quote.
        """.write(to: fileURL, atomically: true, encoding: .utf8)

        let options = HarnessLaunchOptions(
            fixtureRoot: tempRoot,
            openFile: "fixture.md",
            uiTestOpenFolderURL: nil,
            theme: nil,
            windowSize: CGSize(width: 800, height: 600),
            disableFileWatch: true,
            dumpVisibleStateURL: nil,
            dumpPerfStateURL: nil,
            screenshotPathURL: nil,
            commandDirectoryURL: nil,
            uiTestMode: true,
            platformTarget: .macos,
            deviceClass: .mac
        )

        let model = AppModel(launchOptions: options)
        model.bootstrap()

        try await Task.sleep(nanoseconds: 300_000_000)

        let snapshot = model.stateSnapshot()
        XCTAssertEqual(snapshot.visibleBlocks.map(\.kind), ["orderedListItem", "codeBlock", "blockquote"])
        XCTAssertEqual(snapshot.visibleBlocks.map(\.text), ["A paragraph with two lines.", "indented code", "A block quote."])
    }

    func testMarkdownRendererMatchesCommonMarkFixtureCorpusSemantics() throws {
        let fixturesRoot = repoRootURL.appendingPathComponent("Fixtures/expected/spec-safari/commonmark", isDirectory: true)
        let artifactsRoot = repoRootURL.appendingPathComponent("artifacts", isDirectory: true)
        try FileManager.default.createDirectory(at: artifactsRoot, withIntermediateDirectories: true)
        let reportURL = artifactsRoot.appendingPathComponent("commonmark-semantic-report.json")
        let fixtureURLs = try FileManager.default.contentsOfDirectory(
            at: fixturesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }

        var failures: [[String: String]] = []

        for fixtureURL in fixtureURLs {
            let inputURL = fixtureURL.appendingPathComponent("input.md")
            let expectedURL = fixtureURL.appendingPathComponent("expected.html")
            guard FileManager.default.fileExists(atPath: inputURL.path),
                  FileManager.default.fileExists(atPath: expectedURL.path) else {
                continue
            }

            let markdown = try String(contentsOf: inputURL, encoding: .utf8)
            let expectedHTML = try String(contentsOf: expectedURL, encoding: .utf8)
            let blocks = MarkdownRenderer.blocks(from: markdown)
            let actualText = normalizeSemanticText(flattenedVisibleText(from: blocks))
            let expectedText = normalizeSemanticText(extractedHTMLText(from: expectedHTML))

            if actualText != expectedText {
                failures.append([
                    "fixture": fixtureURL.lastPathComponent,
                    "expected": expectedText,
                    "actual": actualText,
                ])
            }
        }

        let report: [String: Any] = [
            "fixtureCount": fixtureURLs.count,
            "failureCount": failures.count,
            "failures": failures,
        ]
        let reportData = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try reportData.write(to: reportURL)

        if !failures.isEmpty {
            let preview = failures.prefix(30).map { failure in
                let fixture = failure["fixture"] ?? "unknown"
                let expected = failure["expected"] ?? ""
                let actual = failure["actual"] ?? ""
                return "\(fixture): expected [\(expected)] actual [\(actual)]"
            }
            XCTFail("CommonMark semantic mismatches (\(failures.count)). Full report: \(reportURL.path)\n" + preview.joined(separator: "\n"))
        }
    }

    private func makeTemporaryWorkspace(named folderName: String, files: [String: String]) throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let folder = root.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (path, contents) in files {
            let fileURL = folder.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return folder
    }

    private func makeGitHubFixtureFile(includeDelimitedDocuments: Bool = false) throws -> URL {
        let freeMarkdownViewerTree: [GitHubTreeEntry] = [
            GitHubTreeEntry(path: "README.md", type: "blob"),
            GitHubTreeEntry(path: "docs/guide.md", type: "blob"),
            GitHubTreeEntry(path: "media/diagram.png", type: "blob"),
        ] + (includeDelimitedDocuments ? [GitHubTreeEntry(path: "docs/metrics.csv", type: "blob")] : [])

        let freeMarkdownViewerFiles: [String: String] = [
            "README.md": "# Repo Root\n\nWelcome.",
            "docs/guide.md": "# Guide\n\nLoaded from docs.",
        ].merging(
            includeDelimitedDocuments ? ["docs/metrics.csv": "Name,Count\nAlpha,1\nBeta,2"] : [:],
            uniquingKeysWith: { current, _ in current }
        )

        let payload = GitHubFixtureDocument(
            repositories: [
                "moorage/free-markdown-viewer": GitHubRepositoryMetadata(defaultBranch: "main"),
                "moorage/cxhere": GitHubRepositoryMetadata(defaultBranch: "main"),
            ],
            commits: [
                "moorage/free-markdown-viewer": [
                    "main": "sha-main",
                ],
                "moorage/cxhere": [
                    "0.1.1": "sha-tag",
                ],
            ],
            trees: [
                "moorage/free-markdown-viewer": [
                    "sha-main": freeMarkdownViewerTree,
                ],
                "moorage/cxhere": [
                    "sha-tag": [
                        GitHubTreeEntry(path: "CHANGELOG.md", type: "blob"),
                    ],
                ],
            ],
            files: [
                "moorage/free-markdown-viewer": [
                    "sha-main": freeMarkdownViewerFiles,
                ],
                "moorage/cxhere": [
                    "sha-tag": [
                        "CHANGELOG.md": "# Changelog\n\nTag release.",
                    ],
                ],
            ]
        )

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-github-fixture.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        try data.write(to: url, options: Data.WritingOptions.atomic)
        return url
    }

    private func makeGitHubWorkspaceService(
        fixtureURL: URL,
        cacheDirectoryURL: URL? = nil
    ) throws -> (service: GitHubWorkspaceService, cacheDirectoryURL: URL) {
        let resolvedCacheDirectoryURL = cacheDirectoryURL ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let remoteClient = try FixtureGitHubRemoteClient(fixtureURL: fixtureURL)
        return (
            GitHubWorkspaceService(
                remoteClient: remoteClient,
                cacheDirectoryURL: resolvedCacheDirectoryURL
            ),
            resolvedCacheDirectoryURL
        )
    }

    private func flattenedVisibleText(from blocks: [MarkdownBlock]) -> String {
        blocks
            .flatMap { block -> [String] in
                [block.plainText] + flattenChildTexts(from: block.children)
            }
            .joined(separator: " ")
    }

    private func flattenChildTexts(from blocks: [MarkdownBlock]) -> [String] {
        blocks.flatMap { block in
            [block.plainText] + flattenChildTexts(from: block.children)
        }
    }

    private func extractedHTMLText(from html: String) -> String {
        return html
            .replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<\?[\s\S]*?\?>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<!\[CDATA\[[\s\S]*?\]\]>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<!DOCTYPE[^>]*>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
    }

    private func normalizeSemanticText(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<\?[\s\S]*?\?>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<!\[CDATA\[[\s\S]*?\]\]>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<!DOCTYPE[^>]*>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"</?[A-Za-z][A-Za-z0-9-]*(?=[\s>/])[^>]*>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"&[A-Za-z0-9#]+;?"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\u{FFFD}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=\p{Punct})\s+(?=\S)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=\S)\s+(?=\p{Punct})"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: #"[^0-9A-Za-z]+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
