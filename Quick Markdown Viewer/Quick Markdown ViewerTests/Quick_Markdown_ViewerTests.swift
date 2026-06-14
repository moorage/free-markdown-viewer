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
import Darwin
import Quartz
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
        let width = max(Int(size.width.rounded()), 1)
        let height = max(Int(size.height.rounded()), 1)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: height * bytesPerRow)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = try XCTUnwrap(
            CGContext(
                data: &buffer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            )
        )
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(size.width / bounds.width, size.height / bounds.height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(origin: .zero, size: CGSize(width: width, height: height)))
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
        return try XCTUnwrap(context.makeImage())
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
        if let croppedImage = image.cropping(to: resolvedCropRect) {
            context.draw(croppedImage, in: CGRect(origin: .zero, size: resolvedCropRect.size))
        } else {
            context.draw(
                image,
                in: CGRect(
                    x: -resolvedCropRect.origin.x,
                    y: -resolvedCropRect.origin.y,
                    width: CGFloat(image.width),
                    height: CGFloat(image.height)
                )
            )
        }

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

    private func sidebarRowDescriptions(_ rows: [SidebarFileTree.Row]) -> [String] {
        rows.map { row in
            switch row {
            case let .folder(folder):
                let state = folder.isExpanded ? "expanded" : "collapsed"
                return "folder:\(folder.label):\(folder.depth):\(state)"
            case let .file(file):
                return "file:\(file.file.name):\(file.depth)"
            }
        }
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
            "--ui-test-show-sidebar",
            "--ui-test-show-outline",
            "--ui-test-search-query", "lifecycle",
            "--ui-test-search-scope", "allDocuments",
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
        XCTAssertTrue(options.uiTestShowSidebar)
        XCTAssertTrue(options.uiTestShowOutline)
        XCTAssertEqual(options.uiTestSearchQuery, "lifecycle")
        XCTAssertEqual(options.uiTestSearchScope, "allDocuments")
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
        XCTAssertTrue(script.contains("usage: qmv [directory-or-supported-file]"))
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
        XCTAssertEqual(request.explicitSelectedFileURL?.path, markdownURL.path)
        XCTAssertEqual(request.presentation, .reuseEmptyWindow)
    }

    func testExternalWorkspaceOpenCoordinatorCanForceNewWindowForDroppedMarkdownFile() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let markdownURL = tempRoot.appendingPathComponent("notes.md")
        try "# Notes".write(to: markdownURL, atomically: true, encoding: .utf8)

        let request = try XCTUnwrap(
            ExternalWorkspaceOpenCoordinator.normalizedRequest(for: markdownURL, presentation: .newWindow)
        )
        XCTAssertEqual(request.rootURL.path, tempRoot.path)
        XCTAssertEqual(request.selectedPath?.rawValue, "notes.md")
        XCTAssertEqual(request.explicitSelectedFileURL?.path, markdownURL.path)
        XCTAssertEqual(request.presentation, .newWindow)
    }

    func testExternalWorkspaceOpenCoordinatorReadsDroppedFileURLData() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let markdownURL = tempRoot.appendingPathComponent("notes.md")
        try "# Notes".write(to: markdownURL, atomically: true, encoding: .utf8)
        let droppedItem = try XCTUnwrap(markdownURL.absoluteString.data(using: .utf8)) as NSData

        let fileURL = try XCTUnwrap(ExternalWorkspaceOpenCoordinator.fileURL(fromDroppedItem: droppedItem))
        XCTAssertEqual(fileURL.path, markdownURL.path)
    }

    func testExternalWorkspaceOpenCoordinatorNormalizesCSVFileToWorkspaceAndSelection() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let csvURL = tempRoot.appendingPathComponent("table.csv")
        try "Name,Count\nAlpha,1".write(to: csvURL, atomically: true, encoding: .utf8)

        let request = try XCTUnwrap(ExternalWorkspaceOpenCoordinator.normalizedRequest(for: csvURL))
        XCTAssertEqual(request.rootURL.path, tempRoot.path)
        XCTAssertEqual(request.selectedPath?.rawValue, "table.csv")
        XCTAssertEqual(request.explicitSelectedFileURL?.path, csvURL.path)
        XCTAssertEqual(request.presentation, .reuseEmptyWindow)
    }

    func testExternalWorkspaceOpenCoordinatorNormalizesJSONFileToWorkspaceAndSelection() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let jsonURL = tempRoot.appendingPathComponent("events.jsonl")
        try #"{"event":"launch"}"#.write(to: jsonURL, atomically: true, encoding: .utf8)

        let request = try XCTUnwrap(ExternalWorkspaceOpenCoordinator.normalizedRequest(for: jsonURL))
        XCTAssertEqual(request.rootURL.path, tempRoot.path)
        XCTAssertEqual(request.selectedPath?.rawValue, "events.jsonl")
        XCTAssertEqual(request.explicitSelectedFileURL?.path, jsonURL.path)
        XCTAssertEqual(request.presentation, .reuseEmptyWindow)
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
        XCTAssertEqual(request.presentation, .reuseEmptyWindow)
    }

    @MainActor
    func testExternalWorkspaceOpenCoordinatorTracksPendingRequestsUntilClaimed() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let markdownURL = tempRoot.appendingPathComponent("notes.md")
        try "# Notes".write(to: markdownURL, atomically: true, encoding: .utf8)

        let coordinator = ExternalWorkspaceOpenCoordinator()
        let request = try XCTUnwrap(ExternalWorkspaceOpenCoordinator.normalizedRequest(for: markdownURL))
        coordinator.enqueue(request)

        XCTAssertTrue(coordinator.hasPendingRequests)
        let requestID = try XCTUnwrap(coordinator.latestRequestID)
        XCTAssertNotNil(coordinator.claimRequest(id: requestID))
        XCTAssertFalse(coordinator.hasPendingRequests)
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

    func testAppDelegateAdvertisesLaunchServicesPrintFileSupport() {
        let appDelegate = QuickMarkdownViewerAppDelegate()
        let selector = #selector(NSApplicationDelegate.application(_:printFiles:withSettings:showPrintPanels:))

        XCTAssertTrue(appDelegate.responds(to: selector))
    }

    @MainActor
    func testExternalPrintCompositionBuildsFromPrintFileURLs() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        let markdownURL = tempRoot.appendingPathComponent("notes.md")
        let csvURL = tempRoot.appendingPathComponent("table.csv")
        let mermaidURL = tempRoot.appendingPathComponent("diagram.mmd")
        try "# Notes\n\nExternal print path.".write(to: markdownURL, atomically: true, encoding: .utf8)
        try "Name,Count\nAlpha,1".write(to: csvURL, atomically: true, encoding: .utf8)
        try "flowchart TD\n    A[Start] --> B[Done]".write(to: mermaidURL, atomically: true, encoding: .utf8)

        let composition = try await AppModel.makePrintComposition(
            forExternalPrintFileURLs: [markdownURL, csvURL, mermaidURL]
        )

        XCTAssertEqual(composition.scope, .allFiles)
        XCTAssertEqual(composition.sections.map(\.title), ["notes.md", "table.csv", "diagram.mmd"])
        XCTAssertTrue(composition.plainText.contains("External print path."))
        XCTAssertTrue(composition.plainText.contains("Name | Count"))
        XCTAssertTrue(composition.plainText.contains("Mermaid Diagram"))
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

    func testWorkspaceProviderIncludesExplicitOpenedFileEvenWhenEnumerationSkipsIt() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let hiddenMarkdownURL = tempRoot.appendingPathComponent(".launch-services-note.md")
        try "# Dropped File\n\nOpened directly.".write(to: hiddenMarkdownURL, atomically: true, encoding: .utf8)

        let provider = LocalWorkspaceProvider(
            rootURL: tempRoot,
            explicitFileURL: hiddenMarkdownURL,
            embeddedDocs: [:]
        )
        let workspace = try provider.loadRoot()

        XCTAssertEqual(workspace.files.map(\.path.rawValue), [".launch-services-note.md"])
        XCTAssertEqual(
            try provider.readFile(at: WorkspacePath(rawValue: ".launch-services-note.md")),
            "# Dropped File\n\nOpened directly."
        )
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

    func testAutomaticFolderPromptPolicySuppressesProgrammaticOpenScene() {
        var policy = AutomaticFolderPromptPolicy()

        XCTAssertTrue(policy.shouldSuppressAutomaticFolderPrompt(for: "launch-scene", hasRestoredSession: false))

        policy.suppressAutomaticFolderPrompt(for: "drop-source-window")

        XCTAssertTrue(policy.shouldSuppressAutomaticFolderPrompt(for: "drop-source-window", hasRestoredSession: false))
        XCTAssertFalse(policy.shouldSuppressAutomaticFolderPrompt(for: "explicit-new-window", hasRestoredSession: false))
    }

    func testAutomaticFolderPromptPolicyCanCancelAlreadyAllowedPrompt() {
        var policy = AutomaticFolderPromptPolicy()

        XCTAssertTrue(policy.shouldSuppressAutomaticFolderPrompt(for: "launch-scene", hasRestoredSession: false))
        XCTAssertFalse(policy.shouldSuppressAutomaticFolderPrompt(for: "drop-source-window", hasRestoredSession: false))

        policy.suppressAutomaticFolderPrompt(for: "drop-source-window")

        XCTAssertTrue(policy.shouldSuppressAutomaticFolderPrompt(for: "drop-source-window", hasRestoredSession: false))
    }

    @MainActor
    func testSessionStoreAllowsLaunchExternalOpenToReplaceRestoredSessionUntilActive() throws {
        let suiteName = "qmv-session-store-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let session = WorkspaceWindowSession(
            rootPath: "/tmp/restored",
            selectedFile: "old.md",
            securityScopedBookmarkData: nil
        )
        let encodedSessions = try JSONEncoder().encode([session])
        defaults.set(encodedSessions, forKey: "workspaceWindowSessions")

        let store = WorkspaceWindowSessionStore(
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
            userDefaults: defaults,
            observeTermination: false
        )

        XCTAssertNotNil(store.claimLaunchSession(for: "launch-scene"))
        XCTAssertTrue(store.canReplaceClaimedLaunchSession(for: "launch-scene"))

        store.updateActiveSession(session, for: "launch-scene")

        XCTAssertFalse(store.canReplaceClaimedLaunchSession(for: "launch-scene"))
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
    func testAppModelLoadsSmallWideMarkdownTableThroughLazyPlainTextPath() async throws {
        let longDigest = String(repeating: "AI infrastructure and agent workflows need bounded table rendering. ", count: 8)
        let workspace = try makeTemporaryWorkspace(named: "AI News Workspace", files: [
            "ai-news.md": """
            | Rank | Topic | Digest |
            |---:|---|---|
            | 1 | AI economics | \(longDigest) |
            | 2 | Agent tooling | \(longDigest) |
            """
        ])
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "ai-news.md",
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
        for _ in 0..<100 where model.isLoadingDocument || !model.isReady {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        let table = try XCTUnwrap(model.documentBlocks.first(where: { $0.kind == .table })?.table)
        XCTAssertEqual(model.selectedPath?.rawValue, "ai-news.md")
        XCTAssertTrue(table.prefersLazyInteractiveViewport)
        XCTAssertEqual(table.contentKind, .plainText)
        XCTAssertNil(table.rows.first?.last?.attributedText)
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
    func testPrintSelectedNDJSONDocumentUsesStructuredRows() async throws {
        let workspace = try makeTemporaryWorkspace(named: "NDJSON Print Workspace", files: [
            "events.ndjson": """
            {"event":"one","ok":true}
            {bad}
            {"event":"two","ok":false}
            """,
            "events.jsonl": """
            {"line":1,"message":"jsonl alias"}
            {"line":2,"message":"same parser"}
            """
        ])
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "events.ndjson",
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
        let ndjsonComposition = try await model.makePrintComposition(scope: .selectedFile)

        XCTAssertEqual(ndjsonComposition.sections.map(\.title), ["events.ndjson"])
        XCTAssertEqual(ndjsonComposition.sections.map(\.kind), [.ndjson])
        XCTAssertTrue(ndjsonComposition.plainText.contains("L1 record { 2 }"))
        XCTAssertTrue(ndjsonComposition.plainText.contains("L2 Expected object key."))
        XCTAssertTrue(ndjsonComposition.plainText.contains("L3 record { 2 }"))

        model.openFile(WorkspacePath(rawValue: "events.jsonl"))
        let jsonlComposition = try await model.makePrintComposition(scope: .selectedFile)

        XCTAssertEqual(jsonlComposition.sections.map(\.title), ["events.jsonl"])
        XCTAssertEqual(jsonlComposition.sections.map(\.kind), [.ndjson])
        XCTAssertTrue(jsonlComposition.plainText.contains("L1 record { 2 }"))
        XCTAssertTrue(jsonlComposition.plainText.contains("message: \"jsonl alias\""))
        XCTAssertTrue(jsonlComposition.plainText.contains("L2 record { 2 }"))
    }

    func testMacPrintPresenterRetainsModalPrintOperationUntilCallback() throws {
        let sourceURL = repoRootURL.appendingPathComponent(
            "Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/PlatformPrintPresenter.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("ModalPrintOperationRetainer"))
        XCTAssertTrue(source.contains("activeRetainers[ObjectIdentifier(operation)] = retainer"))
        XCTAssertTrue(source.contains("delegate: retainer"))
        XCTAssertTrue(source.contains("printOperationDidRun"))
        XCTAssertFalse(source.contains("runModal(for: window, delegate: nil"))
    }

    func testMacPrintToolbarUsesIconOnlyControls() throws {
        let sourceURL = repoRootURL.appendingPathComponent(
            "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let controlStart = try XCTUnwrap(source.range(of: "private var macPrintControl: AnyView?"))
        let controlEnd = try XCTUnwrap(source.range(of: "private var showsFilesButton: Bool"))
        let controlSource = String(source[controlStart.lowerBound..<controlEnd.lowerBound])

        XCTAssertTrue(controlSource.contains("ControlGroup"))
        XCTAssertTrue(controlSource.contains("Image(systemName: \"printer\")"))
        XCTAssertTrue(controlSource.contains("Image(systemName: \"printer.fill\")"))
        XCTAssertTrue(controlSource.contains(".labelStyle(.iconOnly)"))
        XCTAssertFalse(controlSource.contains("Button(\"All\")"))
        XCTAssertFalse(controlSource.contains("Capsule(style: .continuous)"))
        XCTAssertTrue(source.contains(".accessibilityIdentifier(AccessibilityIDs.uiTestPrintSelectedAction)"))
        XCTAssertTrue(source.contains(".accessibilityIdentifier(AccessibilityIDs.uiTestPrintAllAction)"))
        XCTAssertTrue(source.contains(".opacity(0)"))
    }

    func testAppStoreScreenshotHarnessCanOpenOutlineAndSearchStates() throws {
        let harnessURL = repoRootURL.appendingPathComponent(
            "Quick Markdown Viewer/Quick Markdown Viewer/Harness/HarnessLaunchOptions.swift"
        )
        let shellURL = repoRootURL.appendingPathComponent(
            "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift"
        )
        let captureURL = repoRootURL.appendingPathComponent("scripts/capture-app-store-screenshots")
        let checkpointURL = repoRootURL.appendingPathComponent("scripts/capture-checkpoint")
        let harnessSource = try String(contentsOf: harnessURL, encoding: .utf8)
        let shellSource = try String(contentsOf: shellURL, encoding: .utf8)
        let captureSource = try String(contentsOf: captureURL, encoding: .utf8)
        let checkpointSource = try String(contentsOf: checkpointURL, encoding: .utf8)

        XCTAssertTrue(harnessSource.contains("let uiTestShowOutline: Bool"))
        XCTAssertTrue(harnessSource.contains("let uiTestShowSidebar: Bool"))
        XCTAssertTrue(harnessSource.contains("let uiTestSearchQuery: String?"))
        XCTAssertTrue(harnessSource.contains("--ui-test-show-sidebar"))
        XCTAssertTrue(harnessSource.contains("--ui-test-show-outline"))
        XCTAssertTrue(harnessSource.contains("--ui-test-search-query"))
        XCTAssertTrue(shellSource.contains("applyUITestPresentationOptionsIfNeeded"))
        XCTAssertTrue(shellSource.contains("showSidebarForUITestPresentation"))
        XCTAssertTrue(shellSource.contains("isOutlinePresented = true"))
        XCTAssertTrue(shellSource.contains("model.updateSearchQuery(searchQuery)"))
        XCTAssertTrue(captureSource.contains("Outline Navigation.md|outline-navigation|outline"))
        XCTAssertTrue(captureSource.contains("Full Text Search.md|full-text-search|search"))
        XCTAssertTrue(captureSource.contains("--ui-test-show-sidebar --ui-test-search-query \"lifecycle\" --ui-test-search-scope \"allDocuments\""))
        XCTAssertTrue(checkpointSource.contains("UI_TEST_PRESENTATION_ARGS+=(--ui-test-show-sidebar)"))
        XCTAssertTrue(checkpointSource.contains("UI_TEST_PRESENTATION_ARGS+=(--ui-test-show-outline)"))
        XCTAssertTrue(checkpointSource.contains("UI_TEST_PRESENTATION_ARGS+=(--ui-test-search-query"))
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
    func testPrintAllPublishesPreparingStateDuringLargeComposition() async throws {
        let repeatedBody = (1...160)
            .map { "Paragraph \($0) with enough text to exercise Markdown parsing for a larger print job." }
            .joined(separator: "\n\n")
        let files = Dictionary(
            uniqueKeysWithValues: (1...80).map { index in
                (String(format: "document-%03d.md", index), "# Document \(index)\n\n\(repeatedBody)")
            }
        )
        let workspace = try makeTemporaryWorkspace(named: "Large Print All Workspace", files: files)

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "document-001.md",
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

        let printTask = Task {
            try await model.makePrintComposition(scope: .allFiles)
        }

        var observedPreparing = false
        for _ in 0..<100 {
            if model.isPreparingPrint, model.lastPrintRequestStatus == "preparing" {
                observedPreparing = true
                XCTAssertEqual(model.printPreparationMessage, "Preparing 80 documents for print...")
                XCTAssertFalse(model.canPrintAllDocuments)
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertTrue(observedPreparing)
        let composition = try await printTask.value
        XCTAssertEqual(composition.sections.count, 80)
        XCTAssertFalse(model.isPreparingPrint)
        XCTAssertNil(model.printPreparationMessage)
        XCTAssertTrue(model.canPrintAllDocuments)
    }

    @MainActor
    func testPrintAllPreparationCanBeCancelled() async throws {
        let repeatedBody = (1...220)
            .map { "Paragraph \($0) with enough text to keep print assembly cancellable." }
            .joined(separator: "\n\n")
        let files = Dictionary(
            uniqueKeysWithValues: (1...160).map { index in
                (String(format: "cancel-%03d.md", index), "# Cancel \(index)\n\n\(repeatedBody)")
            }
        )
        let workspace = try makeTemporaryWorkspace(named: "Cancellable Print All Workspace", files: files)

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "cancel-001.md",
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

        let printTask = Task {
            try await model.makePrintComposition(scope: .allFiles)
        }

        for _ in 0..<100 where model.isPreparingPrint == false {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(model.isPreparingPrint)

        printTask.cancel()
        do {
            _ = try await printTask.value
            XCTFail("Expected print preparation cancellation to throw.")
        } catch is CancellationError {
            model.recordPrintCancelled(scope: .allFiles)
        }

        XCTAssertFalse(model.isPreparingPrint)
        XCTAssertNil(model.printPreparationMessage)
        XCTAssertEqual(model.lastPrintRequestScope, DocumentPrintScope.allFiles.rawValue)
        XCTAssertEqual(model.lastPrintRequestStatus, "cancelled")
        XCTAssertTrue(model.canPrintAllDocuments)
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
        let pageImage = try firstPDFPageCGImage(from: outputURL, size: DocumentPrintPageLayout.letter.paperSize)
        let stats = try quantizedColorStats(
            for: pageImage,
            cropRect: CGRect(origin: .zero, size: DocumentPrintPageLayout.letter.paperSize),
            quantizationStep: 24
        )
        XCTAssertGreaterThan(stats.uniqueCount, 1)
    }

    @MainActor
    func testExportPrintedNDJSONDocumentHarnessCommandWritesPDF() async throws {
        let workspace = try makeTemporaryWorkspace(named: "NDJSON Print PDF Workspace", files: [
            "events.ndjson": """
            {"event":"one","ok":true}
            {bad}
            {"event":"two","ok":false}
            """
        ])
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("ndjson-printed.pdf")

        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: workspace,
                openFile: "events.ndjson",
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
        let pageImage = try firstPDFPageCGImage(from: outputURL, size: DocumentPrintPageLayout.letter.paperSize)
        let stats = try quantizedColorStats(
            for: pageImage,
            cropRect: CGRect(origin: .zero, size: DocumentPrintPageLayout.letter.paperSize),
            quantizationStep: 24
        )
        XCTAssertGreaterThan(stats.uniqueCount, 1)
    }

    #if os(macOS)
    @MainActor
    func testMacPrintOperationPDFOutputRendersNDJSONDocument() throws {
        let source = """
        {"event":"one","ok":true}
        {bad}
        {"event":"two","ok":false}
        """
        let jsonDocument = JSONDocumentModel.parse(source: source, kind: .ndjson)
        let blocks = [
            MarkdownBlock(
                id: "json.document",
                kind: .jsonDocument,
                plainText: source,
                sourceText: source,
                level: nil,
                listItemIndex: nil,
                indentLevel: 0,
                isTaskItem: false,
                isTaskCompleted: nil,
                table: nil,
                image: nil,
                video: nil,
                attributedText: nil,
                children: [],
                jsonDocument: MarkdownJSONDocument(kind: .ndjson, document: jsonDocument)
            )
        ]
        let composition = DocumentPrintComposition(
            scope: .selectedFile,
            workspaceTitle: "NDJSON Print Workspace",
            fontScale: 1,
            launchTheme: nil,
            tabularPresentation: TabularDocumentPresentation(),
            sections: [
                DocumentPrintSection(
                    path: WorkspacePath(rawValue: "events.ndjson"),
                    title: "events.ndjson",
                    kind: .ndjson,
                    blocks: blocks
                )
            ]
        )
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("native-ndjson-print-operation.pdf")

        try PlatformPrintPresenter.exportPrintOperationPDF(composition, to: outputURL)

        let data = try Data(contentsOf: outputURL)
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 500)
        let document = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)
        let pageImage = try firstPDFPageCGImage(from: outputURL, size: DocumentPrintPageLayout.letter.paperSize)
        let stats = try quantizedColorStats(
            for: pageImage,
            cropRect: CGRect(origin: .zero, size: DocumentPrintPageLayout.letter.paperSize),
            quantizationStep: 24
        )
        XCTAssertGreaterThan(stats.uniqueCount, 1)
    }

    @MainActor
    func testMacPrintOperationPDFOutputIsNotBlank() throws {
        let blocks = MarkdownRenderer.blocks(from: """
        # Native Print Preview

        This content must survive the same AppKit print operation path used by the print sheet.

        - Visible text
        - Visible bullets

        | Area | Status |
        | --- | --- |
        | Print Preview | Non-empty |
        """)
        let composition = DocumentPrintComposition(
            scope: .selectedFile,
            workspaceTitle: "Native Print Preview Workspace",
            fontScale: 1,
            launchTheme: nil,
            tabularPresentation: TabularDocumentPresentation(),
            sections: [
                DocumentPrintSection(
                    path: WorkspacePath(rawValue: "native-print-preview.md"),
                    title: "native-print-preview.md",
                    kind: .markdown,
                    blocks: blocks
                )
            ]
        )
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("native-print-operation.pdf")

        try PlatformPrintPresenter.exportPrintOperationPDF(composition, to: outputURL)

        let data = try Data(contentsOf: outputURL)
        XCTAssertTrue(data.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 500)
        let document = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertGreaterThanOrEqual(document.pageCount, 1)
        let pageImage = try firstPDFPageCGImage(from: outputURL, size: DocumentPrintPageLayout.letter.paperSize)
        let stats = try quantizedColorStats(
            for: pageImage,
            cropRect: CGRect(origin: .zero, size: DocumentPrintPageLayout.letter.paperSize),
            quantizationStep: 24
        )
        XCTAssertGreaterThan(stats.uniqueCount, 1)
    }
    #endif

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
    func testAppModelOpenFolderSelectsExplicitOpenedFileWhenEnumerationSkipsIt() async throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let hiddenMarkdownURL = tempRoot.appendingPathComponent(".launch-services-note.md")
        try "# Dropped File\n\nOpened directly.".write(to: hiddenMarkdownURL, atomically: true, encoding: .utf8)

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

        model.openFolder(
            at: tempRoot,
            selectedPathOverride: WorkspacePath(rawValue: ".launch-services-note.md"),
            explicitSelectedFileURL: hiddenMarkdownURL
        )
        try await Task.sleep(nanoseconds: 300_000_000)

        let snapshot = model.stateSnapshot()
        XCTAssertEqual(model.files.map(\.path.rawValue), [".launch-services-note.md"])
        XCTAssertEqual(snapshot.selectedFile, ".launch-services-note.md")
        XCTAssertEqual(snapshot.sidebar.selectedNode, ".launch-services-note.md")
        XCTAssertTrue(model.documentText.contains("Opened directly."))
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

    func testSidebarFileTreeCompactsSingleChildFolderChains() {
        let files = [
            MarkdownFileNode(path: WorkspacePath(rawValue: "alpha.md"), name: "alpha.md", kind: .markdown),
            MarkdownFileNode(path: WorkspacePath(rawValue: "emptyfolder/fullfolder/notes.md"), name: "notes.md", kind: .markdown),
            MarkdownFileNode(path: WorkspacePath(rawValue: "emptyfolder/fullfolder/table.csv"), name: "table.csv", kind: .csv),
        ]

        let collapsedRows = SidebarFileTree.visibleRows(from: files, expandedFolderIDs: [])
        XCTAssertEqual(sidebarRowDescriptions(collapsedRows), [
            "folder:emptyfolder / fullfolder:0:collapsed",
            "file:alpha.md:0",
        ])

        let expandedRows = SidebarFileTree.visibleRows(
            from: files,
            expandedFolderIDs: ["emptyfolder/fullfolder"]
        )
        XCTAssertEqual(sidebarRowDescriptions(expandedRows), [
            "folder:emptyfolder / fullfolder:0:expanded",
            "file:notes.md:1",
            "file:table.csv:1",
            "file:alpha.md:0",
        ])
    }

    func testSidebarFileTreeSupportsVisibleRowNavigation() {
        let files = [
            MarkdownFileNode(path: WorkspacePath(rawValue: "docs/release/plan.md"), name: "plan.md", kind: .markdown),
            MarkdownFileNode(path: WorkspacePath(rawValue: "docs/release/qa.md"), name: "qa.md", kind: .markdown),
        ]
        let rows = SidebarFileTree.visibleRows(from: files, expandedFolderIDs: ["docs/release"])

        XCTAssertEqual(
            SidebarFileTree.folderPathPrefixes(for: WorkspacePath(rawValue: "docs/release/plan.md")),
            Set(["docs", "docs/release"])
        )
        XCTAssertEqual(SidebarFileTree.adjacentRowID(from: nil, within: rows, offset: 1), "folder:docs/release")
        XCTAssertEqual(
            SidebarFileTree.adjacentRowID(from: "folder:docs/release", within: rows, offset: 1),
            "file:docs/release/plan.md"
        )
        XCTAssertEqual(
            SidebarFileTree.adjacentRowID(from: "file:docs/release/qa.md", within: rows, offset: -1),
            "file:docs/release/plan.md"
        )
    }

    func testSidebarFileTreeSnapshotHandlesLargeFolderExpansion() {
        let files = (0..<5_000).map { index in
            let name = String(format: "file-%04d.md", index)
            return MarkdownFileNode(
                path: WorkspacePath(rawValue: "docs/\(name)"),
                name: name,
                kind: .markdown
            )
        }
        let snapshot = SidebarFileTree.Snapshot(files: files)

        let collapsedRows = snapshot.visibleRows(expandedFolderIDs: [])
        XCTAssertEqual(sidebarRowDescriptions(collapsedRows), [
            "folder:docs:0:collapsed",
        ])

        let expandedRows = snapshot.visibleRows(expandedFolderIDs: ["docs"])
        XCTAssertEqual(expandedRows.count, 5_001)
        XCTAssertEqual(expandedRows.first?.id, "folder:docs")
        XCTAssertEqual(expandedRows.last?.id, "file:docs/file-4999.md")
    }

    func testDocumentSearchEngineReturnsBlockAnchoredMatches() {
        let documentText = """
        # Lifecycle Overview

        The patient lifecycle starts with intake.

        Follow-up lifecycle notes are tracked separately.
        """
        let blocks = MarkdownRenderer.blocks(from: documentText)

        let results = DocumentSearchEngine.results(
            query: "LIFECYCLE",
            path: WorkspacePath(rawValue: "case.md"),
            fileName: "case.md",
            documentText: documentText,
            blocks: blocks
        )

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.map(\.path.rawValue), ["case.md", "case.md", "case.md"])
        XCTAssertEqual(results.map(\.lineNumber), [1, 3, 5])
        XCTAssertTrue(results.allSatisfy { $0.blockID.isEmpty == false })
        XCTAssertTrue(results.first?.snippet.contains("Lifecycle Overview") == true)
    }

    @MainActor
    func testAppModelSearchesAllDocumentsAndSelectsNextResult() async throws {
        let workspace = try makeTemporaryWorkspace(named: "Search Workspace", files: [
            "alpha.md": "# Alpha\n\nLifecycle alpha.",
            "nested/beta.md": "# Beta\n\nLifecycle beta."
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
        retainForTestLifetime(model)
        model.bootstrap()
        try await Task.sleep(nanoseconds: 300_000_000)

        model.updateSearchQuery("lifecycle")
        model.activateSearch(scope: .allDocuments)

        for _ in 0..<100 where model.isSearching {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTAssertEqual(model.searchResults.map(\.path.rawValue), ["alpha.md", "nested/beta.md"])
        XCTAssertEqual(model.searchResults.map(\.lineNumber), [3, 3])
        XCTAssertEqual(model.selectedSearchResult?.path.rawValue, "alpha.md")

        model.selectNextSearchResult()
        XCTAssertEqual(model.selectedSearchResult?.path.rawValue, "nested/beta.md")
        model.selectNextSearchResult()
        XCTAssertEqual(model.selectedSearchResult?.path.rawValue, "alpha.md")
    }

    #if os(macOS)
    @MainActor
    func testMacSearchMenuControllerMapsFindShortcuts() throws {
        func event(key: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: key,
                charactersIgnoringModifiers: key.lowercased(),
                isARepeat: false,
                keyCode: keyCode
            ))
        }

        XCTAssertEqual(
            MacSearchMenuController.command(for: try event(key: "f", keyCode: 3, modifiers: [.command])),
            .currentDocument
        )
        XCTAssertEqual(
            MacSearchMenuController.command(for: try event(key: "F", keyCode: 3, modifiers: [.command, .shift])),
            .allDocuments
        )
        XCTAssertEqual(
            MacSearchMenuController.command(for: try event(key: "g", keyCode: 5, modifiers: [.command])),
            .nextResult
        )
        XCTAssertNil(MacSearchMenuController.command(for: try event(key: "f", keyCode: 3, modifiers: [.command, .option])))
    }
    #endif

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

    func testWorkspaceDocumentKindMappingIncludesJSONFamilyExtensions() {
        XCTAssertEqual(WorkspaceDocumentKind.forPath("payload.json"), .json)
        XCTAssertEqual(WorkspaceDocumentKind.forPath("payload.jsonc"), .jsonc)
        XCTAssertEqual(WorkspaceDocumentKind.forPath("events.ndjson"), .ndjson)
        XCTAssertEqual(WorkspaceDocumentKind.forPath("events.jsonl"), .ndjson)
        XCTAssertTrue(SupportedDocumentExtensions.contains("json"))
        XCTAssertTrue(SupportedDocumentExtensions.contains("jsonc"))
        XCTAssertTrue(SupportedDocumentExtensions.contains("ndjson"))
        XCTAssertTrue(SupportedDocumentExtensions.contains("jsonl"))
    }

    func testJSONViewerRowsPreserveOriginalLineNumbersAfterPrettyPrinting() throws {
        let document = JSONDocumentModel.parse(
            source: #"{"name":"Quick Markdown Viewer","count":2}"#,
            kind: .json
        )

        let rows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [])

        XCTAssertEqual(rows.map(\.lineNumber), [1, 1, 1])
        XCTAssertEqual(rows.map(\.key), [nil, "name", "count"])
    }

    func testJSONGutterHidesRepeatedVisibleLineNumbers() throws {
        let document = JSONDocumentModel.parse(
            source: #"{"name":"Quick Markdown Viewer","count":2}"#,
            kind: .json
        )
        let rows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [])
        let displayedRows = JSONGutterPresentationBuilder.rows(from: rows)

        XCTAssertEqual(rows.map(\.lineNumber), [1, 1, 1])
        XCTAssertEqual(displayedRows.map(\.visibleLineNumber), [1, nil, nil])
    }

    func testJSONGutterShowsLineNumberWhenVisibleLineChanges() throws {
        let document = JSONDocumentModel.parse(
            source: """
            {"event":"one","ok":true}

            {"event":"two","ok":true}
            """,
            kind: .ndjson
        )
        let rows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [])
        let displayedRows = JSONGutterPresentationBuilder.rows(from: rows)

        XCTAssertEqual(rows.first { $0.id == "record.1" }?.lineNumber, 3)

        var previousLineNumber: Int?
        for displayedRow in displayedRows {
            if displayedRow.row.lineNumber == previousLineNumber {
                XCTAssertNil(displayedRow.visibleLineNumber)
            } else {
                XCTAssertEqual(displayedRow.visibleLineNumber, displayedRow.row.lineNumber)
            }
            previousLineNumber = displayedRow.row.lineNumber
        }
    }

    func testJSONViewerRowsPreserveLineNumbersAfterCollapse() throws {
        let document = JSONDocumentModel.parse(
            source: """
            {
              "outer": {
                "inner": true
              }
            }
            """,
            kind: .json
        )
        let outerID = try XCTUnwrap(document.roots.first?.children.first?.id)

        let rows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [outerID])

        XCTAssertEqual(rows.map(\.key), [nil, "outer"])
        XCTAssertEqual(rows.map(\.lineNumber), [1, 2])
        XCTAssertTrue(try XCTUnwrap(rows.last).isCollapsed)
    }

    func testJSONViewerRowsRenderObjectArraysAsIndexedItems() throws {
        let document = JSONDocumentModel.parse(
            source: """
            {
              "events": [
                {"id": 1, "name": "launch"},
                {"id": 2, "name": "quit"}
              ]
            }
            """,
            kind: .json
        )

        let rows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [])
        let eventsRow = try XCTUnwrap(rows.first { $0.key == "events" })

        XCTAssertEqual(eventsRow.displayValue, "[ 2 ]")
        XCTAssertTrue(rows.contains { $0.id == "root.events.0" && $0.key == "[0]" && $0.displayValue == "{ 2 }" && $0.lineNumber == 3 })
        XCTAssertTrue(rows.contains { $0.id == "root.events.0.id" && $0.key == "id" && $0.displayValue == "1" && $0.lineNumber == 3 })
        XCTAssertTrue(rows.contains { $0.id == "root.events.0.name" && $0.key == "name" && $0.displayValue == #""launch""# && $0.lineNumber == 3 })
        XCTAssertTrue(rows.contains { $0.id == "root.events.1" && $0.key == "[1]" && $0.displayValue == "{ 2 }" && $0.lineNumber == 4 })

        let collapsedRows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: ["root.events.1"])
        XCTAssertTrue(collapsedRows.contains { $0.id == "root.events.1" && $0.isCollapsed })
        XCTAssertFalse(collapsedRows.contains { $0.id == "root.events.1.id" })
    }

    func testJSONViewerRowsRenderScalarArraysAsIndexedItems() throws {
        let document = JSONDocumentModel.parse(
            source: """
            {
              "labels": ["alpha", "beta", true, null, 42]
            }
            """,
            kind: .json
        )

        let rows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [])

        XCTAssertTrue(rows.contains { $0.id == "root.labels" && $0.key == "labels" && $0.displayValue == "[ 5 ]" })
        XCTAssertTrue(rows.contains { $0.id == "root.labels.0" && $0.key == "[0]" && $0.displayValue == #""alpha""# && $0.kind == .string })
        XCTAssertTrue(rows.contains { $0.id == "root.labels.1" && $0.key == "[1]" && $0.displayValue == #""beta""# && $0.kind == .string })
        XCTAssertTrue(rows.contains { $0.id == "root.labels.2" && $0.key == "[2]" && $0.displayValue == "true" && $0.kind == .bool })
        XCTAssertTrue(rows.contains { $0.id == "root.labels.3" && $0.key == "[3]" && $0.displayValue == "null" && $0.kind == .null })
        XCTAssertTrue(rows.contains { $0.id == "root.labels.4" && $0.key == "[4]" && $0.displayValue == "42" && $0.kind == .number })
    }

    func testJSONStickyHeaderFixtureProvidesDeepScrollableAncestorRows() throws {
        let fixture = repoRootURL.appendingPathComponent("Fixtures/docs/json_sticky_headers_showcase.json")
        let document = JSONDocumentModel.parse(
            source: try String(contentsOf: fixture, encoding: .utf8),
            kind: .json
        )

        let rows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [])
        let sampleRow = try XCTUnwrap(rows.first { $0.id == "root.workspace.release.streams.1.records.11.checks.duration" })

        XCTAssertGreaterThan(rows.count, 120)
        XCTAssertTrue(sampleRow.ancestorTitles.contains("workspace"))
        XCTAssertTrue(sampleRow.ancestorTitles.contains("release"))
        XCTAssertTrue(sampleRow.ancestorTitles.contains("streams"))
        XCTAssertTrue(sampleRow.ancestorTitles.contains("[1]"))
        XCTAssertTrue(sampleRow.ancestorTitles.contains("records"))
        XCTAssertTrue(sampleRow.ancestorTitles.contains("[11]"))
        XCTAssertTrue(sampleRow.ancestorTitles.contains("checks"))
    }

    func testJSONParserPublishesSourceTokensForHighlighting() throws {
        let document = JSONDocumentModel.parse(
            source: """
            {
              // accepted in jsonc
              "enabled": true
            }
            """,
            kind: .jsonc
        )

        XCTAssertTrue(document.syntaxTokens.contains { $0.kind == .comment && $0.range.start.line == 2 })
        XCTAssertTrue(document.syntaxTokens.contains { $0.kind == .string && $0.range.start.line == 3 })
        XCTAssertTrue(document.syntaxTokens.contains { $0.kind == .bool && $0.range.start.line == 3 })
    }

    func testMarkdownJSONFenceUsesBlockLocalLineNumbers() throws {
        let markdown = """
        # Payload

        ```json
        {"outer":{"inner":true}}
        ```
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)
        let jsonBlock = try XCTUnwrap(blocks.first(where: { $0.kind == .jsonDocument }))
        let jsonDocument = try XCTUnwrap(jsonBlock.jsonDocument?.document)
        let rows = JSONPresentationBuilder.rows(for: jsonDocument, collapsedNodeIDs: [])

        XCTAssertEqual(jsonBlock.codeBlock?.contentStartLine, 4)
        XCTAssertEqual(jsonDocument.sourceLineOffset, 0)
        XCTAssertEqual(rows.map(\.lineNumber), [1, 1, 1])
    }

    func testMarkdownJSONShowcaseFixtureUsesBlockLocalLineNumbersPerBox() throws {
        let fixture = repoRootURL.appendingPathComponent("Fixtures/docs/markdown_json_showcase.md")
        let blocks = MarkdownRenderer.blocks(from: try String(contentsOf: fixture, encoding: .utf8))
        let jsonBlocks = blocks.filter { $0.kind == .jsonDocument }

        XCTAssertEqual(jsonBlocks.compactMap(\.jsonDocument?.kind), [.json, .jsonc, .ndjson])

        let jsonDocuments = try jsonBlocks.map { block in
            try XCTUnwrap(block.jsonDocument?.document)
        }
        XCTAssertEqual(jsonDocuments.map(\.sourceLineOffset), [0, 0, 0])
        XCTAssertEqual(
            jsonDocuments.map(\.source),
            [
                #"{"project":"Quick Markdown Viewer","nested":{"lineNumbers":true}}"#,
                """
                {
                  // Comments are allowed in JSONC.
                  "trailingComma": true,
                }
                """,
                """
                {"event":"one"}
                {bad}
                {"event":"two"}
                """,
            ]
        )

        let rowLineNumbers = jsonDocuments.map { document in
            JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: []).map(\.lineNumber)
        }
        XCTAssertEqual(rowLineNumbers[0], [1, 1, 1, 1])
        XCTAssertEqual(rowLineNumbers[1], [1, 2, 3])
        XCTAssertTrue(rowLineNumbers[2].contains(1))
        XCTAssertTrue(rowLineNumbers[2].contains(2))
        XCTAssertTrue(rowLineNumbers[2].contains(3))
        XCTAssertFalse(rowLineNumbers[1].contains(12))
        XCTAssertFalse(rowLineNumbers[2].contains(21))
    }

    func testNDJSONParserRecoversAfterMalformedRecord() throws {
        let document = JSONDocumentModel.parse(
            source: """
            {"event":"one"}
            {bad}
            {"event":"two"}
            """,
            kind: .ndjson
        )

        let rows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [])

        XCTAssertEqual(document.roots.count, 3)
        XCTAssertEqual(document.roots.map(\.lineNumber), [1, 2, 3])
        XCTAssertEqual(document.roots[1].kind, .error)
        XCTAssertTrue(rows.contains { $0.lineNumber == 3 && $0.displayValue == "record { 1 }" })
    }

    func testNDJSONViewerRowsUseUniqueRecordScopedIDsAndPhysicalLineNumbers() throws {
        let document = JSONDocumentModel.parse(
            source: """
            {"event":"one","ok":true}

            {"event":"two","ok":true}
            {"event":"three","ok":false}
            """,
            kind: .ndjson
        )

        let expandedRows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [])
        let rowIDs = expandedRows.map(\.id)

        XCTAssertEqual(Set(rowIDs).count, rowIDs.count)
        XCTAssertTrue(expandedRows.contains { $0.id == "record.0" && $0.displayValue == "record { 2 }" })
        XCTAssertFalse(expandedRows.contains { $0.id == "record.0.root" })
        XCTAssertTrue(expandedRows.contains { $0.id == "record.0.root.event" && $0.lineNumber == 1 })
        XCTAssertTrue(expandedRows.contains { $0.id == "record.1.root.event" && $0.lineNumber == 3 })
        XCTAssertTrue(expandedRows.contains { $0.id == "record.2.root.event" && $0.lineNumber == 4 })
    }

    func testNDJSONViewerCanCollapseAndExpandLastRecord() throws {
        let document = JSONDocumentModel.parse(
            source: """
            {"event":"one","ok":true}
            {"event":"two","ok":true}
            {"event":"three","ok":false}
            """,
            kind: .ndjson
        )
        let lastRecordID = try XCTUnwrap(document.roots.last?.id)

        let collapsedRows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [lastRecordID])
        XCTAssertTrue(try XCTUnwrap(collapsedRows.first { $0.id == lastRecordID }).isCollapsed)
        XCTAssertFalse(collapsedRows.contains { $0.id == "\(lastRecordID).root.event" })
        XCTAssertEqual(try XCTUnwrap(collapsedRows.first { $0.id == lastRecordID }).lineNumber, 3)

        let expandedRows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [])
        XCTAssertTrue(expandedRows.contains { $0.id == "\(lastRecordID).root.event" && $0.lineNumber == 3 })
        XCTAssertTrue(expandedRows.contains { $0.id == "\(lastRecordID).root.ok" && $0.lineNumber == 3 })
    }

    func testJSONLAliasViewerCanCollapseAndExpandLastRecord() throws {
        let document = JSONDocumentModel.parse(
            source: """
            {"line":1,"message":"jsonl alias"}
            {"line":2,"message":"same parser as ndjson"}
            """,
            kind: .ndjson
        )
        let lastRecordID = try XCTUnwrap(document.roots.last?.id)

        let collapsedRows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [lastRecordID])
        XCTAssertTrue(try XCTUnwrap(collapsedRows.first { $0.id == lastRecordID }).isCollapsed)
        XCTAssertFalse(collapsedRows.contains { $0.id == "\(lastRecordID).root.message" })

        let expandedRows = JSONPresentationBuilder.rows(for: document, collapsedNodeIDs: [])
        XCTAssertTrue(expandedRows.contains { $0.id == "\(lastRecordID).root.message" && $0.lineNumber == 2 })
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
            isFenced: true,
            contentStartLine: 1
        )
        let bashVariant = MarkdownCodeBlock(
            code: "echo goodbye",
            infoString: "bash",
            rawLanguage: "bash",
            language: .bash,
            isFenced: true,
            contentStartLine: 1
        )
        let jsonBlock = MarkdownCodeBlock(
            code: "{\"message\": \"hello\"}",
            infoString: "json",
            rawLanguage: "json",
            language: .json,
            isFenced: true,
            contentStartLine: 1
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

    func testMarkdownRendererMarksLargePlainPipeTableAsPlainText() throws {
        let rows = (1...250).map { index in
            "| \(index) | linkedin | Person \(index) | https://example.com/in/person-\(index) | \(index) | \(index / 2) | \(index / 2) | 1 |"
        }.joined(separator: "\n")
        let markdown = """
        # Report

        | Rank | Provider | Display | Key | Total | From me | From them | Conversations |
        |---:|---|---|---|---:|---:|---:|---:|
        \(rows)
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)
        let table = try XCTUnwrap(blocks.last?.table)

        XCTAssertEqual(blocks.map(\.kind), [.heading, .table])
        XCTAssertTrue(table.prefersLazyInteractiveViewport)
        XCTAssertEqual(table.contentKind, .plainText)
        XCTAssertEqual(table.rows.count, 250)
        XCTAssertNil(table.header.first?.attributedText)
        XCTAssertNil(table.rows.last?.last?.attributedText)
    }

    func testMarkdownRendererMarksSmallWidePlainPipeTableForLazyViewport() throws {
        let longDigest = String(repeating: "AI infrastructure and agent workflows need bounded table rendering. ", count: 7)
        let markdown = """
        | Rank | Topic | Digest |
        |---:|---|---|
        | 1 | AI economics | \(longDigest) |
        | 2 | Agent tooling | \(longDigest) |
        """

        let table = try XCTUnwrap(MarkdownRenderer.blocks(from: markdown).first?.table)

        XCTAssertTrue(table.prefersLazyInteractiveViewport)
        XCTAssertEqual(table.contentKind, .plainText)
        XCTAssertNil(table.rows.first?.last?.attributedText)
    }

    func testMarkdownRendererKeepsSmallNormalPipeTableInDocumentFlow() throws {
        let markdown = """
        | Area | Status |
        |---|---|
        | Open | Ready |
        | Print | Done |
        """

        let table = try XCTUnwrap(MarkdownRenderer.blocks(from: markdown).first?.table)

        XCTAssertFalse(table.prefersLazyInteractiveViewport)
        XCTAssertEqual(table.contentKind, .markdown)
    }

    func testMarkdownRendererPreservesLargePipeTableLinksWhenCellsContainMarkdown() throws {
        let rows = (1...250).map { index in
            let display = index == 1 ? "[Submission](./app-store-submission.md)" : "Person \(index)"
            return "| \(index) | \(display) | \(index) |"
        }.joined(separator: "\n")
        let markdown = """
        | Rank | Display | Total |
        |---:|---|---:|
        \(rows)
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)
        let table = try XCTUnwrap(blocks.first?.table)
        let linkedCell = try XCTUnwrap(table.rows.first?[1])

        XCTAssertTrue(table.prefersLazyInteractiveViewport)
        XCTAssertEqual(table.contentKind, .markdown)
        XCTAssertEqual(linkedCell.plainText, "Submission")
        XCTAssertEqual(linkedCell.attributedText?.runs.first?.link, URL(string: "./app-store-submission.md"))
        XCTAssertNil(table.rows.last?[1].attributedText)
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

    func testMarkdownOutlineItemsUseHeadingBlocksInDocumentOrder() {
        let blocks = MarkdownRenderer.blocks(from: """
        # Overview

        Intro paragraph.

        ## Details

        ### Deep Cut
        """)

        let outlineItems = AppModel.outlineItems(from: blocks)

        XCTAssertEqual(outlineItems.map(\.title), ["Overview", "Details", "Deep Cut"])
        XCTAssertEqual(outlineItems.map(\.level), [1, 2, 3])
        XCTAssertTrue(outlineItems.allSatisfy { !$0.blockID.isEmpty })
    }

    func testMarkdownOutlineItemsPreserveInlineCodeRuns() {
        let blocks = MarkdownRenderer.blocks(from: """
        ## Use `qmv /tmp/file.md` correctly
        """)

        let outlineItem = AppModel.outlineItems(from: blocks).first

        XCTAssertEqual(outlineItem?.title, "Use qmv /tmp/file.md correctly")
        XCTAssertEqual(
            outlineItem?.titleRuns,
            [
                MarkdownOutlineTitleRun(text: "Use ", isCode: false),
                MarkdownOutlineTitleRun(text: "qmv /tmp/file.md", isCode: true),
                MarkdownOutlineTitleRun(text: " correctly", isCode: false),
            ]
        )
    }

    func testActiveOutlineBlockIDTracksLastHeadingAtViewportTop() {
        let items = [
            MarkdownOutlineItem(
                blockID: "heading.one",
                title: "One",
                titleRuns: [MarkdownOutlineTitleRun(text: "One", isCode: false)],
                level: 1
            ),
            MarkdownOutlineItem(
                blockID: "heading.two",
                title: "Two",
                titleRuns: [MarkdownOutlineTitleRun(text: "Two", isCode: false)],
                level: 2
            ),
            MarkdownOutlineItem(
                blockID: "heading.three",
                title: "Three",
                titleRuns: [MarkdownOutlineTitleRun(text: "Three", isCode: false)],
                level: 2
            ),
        ]

        XCTAssertEqual(
            AppModel.activeOutlineBlockID(
                from: ["heading.one": 4, "heading.two": 420],
                outlineItems: items,
                currentBlockID: nil
            ),
            "heading.one"
        )
        XCTAssertEqual(
            AppModel.activeOutlineBlockID(
                from: ["heading.one": -300, "heading.two": 20, "heading.three": 460],
                outlineItems: items,
                currentBlockID: "heading.one"
            ),
            "heading.two"
        )
        XCTAssertEqual(
            AppModel.activeOutlineBlockID(
                from: ["heading.two": 180, "heading.three": 620],
                outlineItems: items,
                currentBlockID: "heading.one"
            ),
            "heading.one"
        )
        XCTAssertEqual(
            AppModel.activeOutlineBlockID(
                from: [:],
                outlineItems: items,
                currentBlockID: "heading.two"
            ),
            "heading.two"
        )
    }

    func testDocumentOutlineActiveRowUsesNavigationFocusStyle() throws {
        let sourceURL = repoRootURL.appendingPathComponent(
            "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let rowStart = try XCTUnwrap(source.range(of: "private struct DocumentOutlineRow: View"))
        let rowEnd = try XCTUnwrap(source.range(of: "private struct DocumentOutlineTitleText: View"))
        let rowSource = String(source[rowStart.lowerBound..<rowEnd.lowerBound])

        XCTAssertTrue(rowSource.contains(".foregroundStyle(isActive ? Color.accentColor : Color.primary)"))
        XCTAssertTrue(rowSource.contains(".stroke(Color.secondary.opacity(0.42), lineWidth: 1)"))
        XCTAssertFalse(rowSource.contains(".fill(Color.accentColor.opacity(0.14))"))
        XCTAssertFalse(rowSource.contains(".frame(width: 3)"))
    }

    func testDocumentOutlineTrackingDebouncesFastScrollUpdates() throws {
        let sourceURL = repoRootURL.appendingPathComponent(
            "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("private enum DocumentOutlineTracking"))
        XCTAssertTrue(source.contains("updateIntervalNanoseconds: UInt64 = 80_000_000"))
        XCTAssertTrue(source.contains("@State private var pendingHeadingOffsets: [String: CGFloat]"))
        XCTAssertTrue(source.contains("@State private var activeOutlineUpdateTask: Task<Void, Never>?"))
        XCTAssertTrue(source.contains("scheduleActiveOutlineUpdate(headingOffsets)"))
        XCTAssertTrue(source.contains("Task.sleep(nanoseconds: DocumentOutlineTracking.updateIntervalNanoseconds)"))
    }

    @MainActor
    func testAppModelPublishesOutlineItemsForLoadedMarkdownDocument() async throws {
        let workspace = try makeTemporaryWorkspace(named: "Outline Workspace", files: [
            "guide.md": "# Guide\n\nBody\n\n## Usage\n\nText",
            "table.csv": "Name,Count\nAlpha,1"
        ])
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
        retainForTestLifetime(model)

        model.bootstrap()
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(model.outlineItems.map(\.title), ["Guide", "Usage"])

        model.openFile(WorkspacePath(rawValue: "table.csv"))
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertTrue(model.outlineItems.isEmpty)
    }

    func testDelimitedTextParserUsesPlainTextTableCellsForLargeCSV() {
        let rows = (0..<5_000).map { "Item \($0),\($0)" }.joined(separator: "\n")
        let csv = "Name,Count\n\(rows)"

        let table = DelimitedTextDocumentParser.markdownTable(from: csv, kind: .csv)

        XCTAssertEqual(table?.contentKind, .plainText)
        XCTAssertEqual(table?.rows.count, 5_000)
        XCTAssertNil(table?.header.first?.attributedText)
        XCTAssertNil(table?.rows.last?.last?.attributedText)
    }

    func testAppSourcesDoNotDeclareSelfUpdateChecks() throws {
        let appRootURL = repoRootURL.appendingPathComponent("Quick Markdown Viewer/Quick Markdown Viewer")
        let removedUpdateCheckerURL = appRootURL.appendingPathComponent("App/Shared/AppUpdateChecker.swift")

        XCTAssertFalse(FileManager.default.fileExists(atPath: removedUpdateCheckerURL.path))

        for relativePath in [
            "Quick_Markdown_ViewerApp.swift",
            "App/Shell/WindowSceneRootView.swift"
        ] {
            let sourceURL = appRootURL.appendingPathComponent(relativePath)
            let source = try String(contentsOf: sourceURL, encoding: .utf8)

            XCTAssertFalse(source.contains("AppUpdateChecker"), relativePath)
            XCTAssertFalse(source.contains("Check for Updates"), relativePath)
            XCTAssertFalse(source.contains("itunes.apple.com/lookup"), relativePath)
        }
    }

    func testQuickLookPreviewExtensionDeclaresMarkdownSupport() throws {
        let infoURL = repoRootURL.appendingPathComponent("Quick Markdown Viewer/QuickLookPreview-Info.plist")
        let data = try Data(contentsOf: infoURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        let extensionDictionary = try XCTUnwrap(plist["NSExtension"] as? [String: Any])
        let attributes = try XCTUnwrap(extensionDictionary["NSExtensionAttributes"] as? [String: Any])

        XCTAssertEqual(plist["CFBundleExecutable"] as? String, "$(EXECUTABLE_NAME)")
        XCTAssertEqual(extensionDictionary["NSExtensionPointIdentifier"] as? String, "com.apple.quicklook.preview")
        XCTAssertEqual(
            extensionDictionary["NSExtensionPrincipalClass"] as? String,
            "$(PRODUCT_MODULE_NAME).PreviewViewController"
        )
        XCTAssertEqual(attributes["QLIsDataBasedPreview"] as? Bool, false)
        XCTAssertEqual(attributes["QLSupportsSearchableItems"] as? Bool, false)
        XCTAssertEqual(
            attributes["QLSupportedContentTypes"] as? [String],
            [
                "net.daringfireball.markdown",
                "com.mermaidjs.mermaid",
                "public.comma-separated-values-text",
                "public.tab-separated-values-text",
                "public.json",
                "com.souschefstudio.jsonc",
                "com.souschefstudio.ndjson",
            ]
        )
    }

    func testMacDocumentTypeDeclarationsIncludeHandlerRanks() throws {
        let infoURL = repoRootURL.appendingPathComponent("Quick Markdown Viewer/Info-macOS.plist")
        let data = try Data(contentsOf: infoURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        let documentTypes = try XCTUnwrap(plist["CFBundleDocumentTypes"] as? [[String: Any]])

        for documentType in documentTypes {
            XCTAssertEqual(documentType["LSHandlerRank"] as? String, "Alternate")
        }

        let contentTypes = Set(documentTypes.flatMap { documentType in
            documentType["LSItemContentTypes"] as? [String] ?? []
        })
        XCTAssertTrue(contentTypes.isSuperset(of: [
            "net.daringfireball.markdown",
            "com.mermaidjs.mermaid",
            "public.comma-separated-values-text",
            "public.tab-separated-values-text",
            "public.json",
            "com.souschefstudio.jsonc",
            "com.souschefstudio.ndjson",
            "public.folder",
        ]))
    }

    func testQuickLookPreviewExtensionTargetIsEmbeddedForMacOS() throws {
        let projectURL = repoRootURL.appendingPathComponent(
            "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj"
        )
        let project = try String(contentsOf: projectURL, encoding: .utf8)

        XCTAssertTrue(project.contains("Quick Markdown Viewer QuickLook.appex in Embed App Extensions"))
        XCTAssertTrue(project.contains("productType = \"com.apple.product-type.app-extension\";"))
        XCTAssertTrue(project.contains("platformFilters = (macos, );"))
        XCTAssertTrue(project.contains("SUPPORTED_PLATFORMS = macosx;"))
    }

    func testQuickLookPreviewSourceUsesNativeMarkdownRendering() throws {
        let sourceURL = repoRootURL.appendingPathComponent(
            "Quick Markdown Viewer/Quick Markdown Viewer QuickLook/PreviewViewController.swift"
        )
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("QLPreviewingController"))
        XCTAssertTrue(source.contains("AttributedString("))
        XCTAssertTrue(source.contains("MarkdownParsingOptions"))
        XCTAssertTrue(source.contains("tableBlock"))
        XCTAssertTrue(source.contains("Mermaid Diagram"))
        XCTAssertTrue(source.contains("NSSegmentedControl"))
        XCTAssertTrue(source.contains("rawSourcePreview"))
        XCTAssertFalse(source.contains("WKWebView"))
        XCTAssertFalse(source.contains("JavaScript"))
    }

    func testQuickLookFeatureParitySpecDocumentsBoundedPreviewContract() throws {
        let specURL = repoRootURL.appendingPathComponent("docs/quicklook-feature-parity.md")
        let spec = try String(contentsOf: specURL, encoding: .utf8)

        XCTAssertTrue(spec.contains("Inline Mermaid fences"))
        XCTAssertTrue(spec.contains("Local inline images"))
        XCTAssertTrue(spec.contains("Remote or data images"))
        XCTAssertTrue(spec.contains("native image attachment"))
        XCTAssertTrue(spec.contains("Does not expose zoom, pan, detached preview UI"))
        XCTAssertTrue(spec.contains("built `.appex` loaded from the current build products"))
        XCTAssertTrue(spec.contains("WKWebView"))
    }

    #if os(macOS)
    @MainActor
    func testQuickLookPreviewExtensionRendersBasicMarkdownAsStyledPreview() throws {
        let fixtureURL = repoRootURL.appendingPathComponent("Fixtures/docs/basic_typography.md")
        let preview = try renderedQuickLookPreview(for: fixtureURL)
        let text = preview.string

        XCTAssertTrue(text.contains("Basic typography"))
        XCTAssertTrue(text.contains("strong text"))
        XCTAssertFalse(text.contains("# Basic typography"))

        let headingRange = (text as NSString).range(of: "Basic typography")
        let bodyRange = (text as NSString).range(of: "This is a small fixture")
        let headingFont = try XCTUnwrap(preview.attribute(.font, at: headingRange.location, effectiveRange: nil) as? NSFont)
        let bodyFont = try XCTUnwrap(preview.attribute(.font, at: bodyRange.location, effectiveRange: nil) as? NSFont)

        XCTAssertGreaterThan(headingFont.pointSize, bodyFont.pointSize)
    }

    @MainActor
    func testQuickLookPreviewExtensionCanSwitchBetweenRenderedAndSourceViews() throws {
        let fixtureURL = repoRootURL.appendingPathComponent("Fixtures/docs/basic_typography.md")
        let controller = try preparedQuickLookPreviewController(for: fixtureURL)
        let modeControl = try XCTUnwrap(findSegmentedControl(in: controller.view))

        XCTAssertEqual(modeControl.segmentCount, 2)
        XCTAssertEqual(modeControl.label(forSegment: 0), "Rendered")
        XCTAssertEqual(modeControl.label(forSegment: 1), "Source")
        XCTAssertEqual(modeControl.selectedSegment, 0)

        let renderedText = try currentQuickLookPreviewText(in: controller)
        XCTAssertTrue(renderedText.contains("Basic typography"))
        XCTAssertFalse(renderedText.contains("# Basic typography"))

        let sourceSelector = NSSelectorFromString("selectSourcePreviewForTesting")
        XCTAssertTrue(controller.responds(to: sourceSelector))
        controller.perform(sourceSelector)

        let sourceText = try currentQuickLookPreviewText(in: controller)
        XCTAssertTrue(sourceText.contains("# Basic typography"))
        XCTAssertEqual(modeControl.selectedSegment, 1)

        let renderedSelector = NSSelectorFromString("selectRenderedPreviewForTesting")
        XCTAssertTrue(controller.responds(to: renderedSelector))
        controller.perform(renderedSelector)

        let restoredText = try currentQuickLookPreviewText(in: controller)
        XCTAssertTrue(restoredText.contains("Basic typography"))
        XCTAssertFalse(restoredText.contains("# Basic typography"))
        XCTAssertEqual(modeControl.selectedSegment, 0)
    }

    @MainActor
    func testQuickLookPreviewExtensionRendersInlineMermaidFenceAsBoundedPreview() throws {
        let fixtureURL = repoRootURL.appendingPathComponent("Fixtures/docs/mermaid_inline_showcase.md")
        let preview = try renderedQuickLookPreview(for: fixtureURL)
        let text = preview.string

        XCTAssertTrue(text.contains("Mermaid Inline Showcase"))
        XCTAssertTrue(text.contains("Mermaid Diagram"))
        XCTAssertTrue(text.contains("Checkout Flow"))
        XCTAssertTrue(text.contains("Flowchart"))
        XCTAssertFalse(text.contains("```mermaid"))
        XCTAssertFalse(text.contains("flowchart LR"))
        XCTAssertTrue(preview.containsImageAttachment)
    }

    @MainActor
    func testQuickLookPreviewExtensionRendersLocalImagesAsAttachments() throws {
        let workspaceURL = try makeTemporaryWorkspace(named: "QuickLookImage", files: [
            "docs/image.md": "# Image\n\n![Rick preview](../media/rickrolled.png \"Fixture image\")\n\nAfter image.",
            "media/.keep": "",
        ])
        let sourceImageURL = repoRootURL.appendingPathComponent("Fixtures/media/rickrolled.png")
        let targetImageURL = workspaceURL.appendingPathComponent("media/rickrolled.png")
        try FileManager.default.copyItem(at: sourceImageURL, to: targetImageURL)

        let preview = try renderedQuickLookPreview(for: workspaceURL.appendingPathComponent("docs/image.md"))
        let text = preview.string

        XCTAssertTrue(text.contains("Image"))
        XCTAssertTrue(text.contains("Rick preview"))
        XCTAssertTrue(text.contains("After image."))
        XCTAssertTrue(preview.containsImageAttachment)
    }

    @MainActor
    func testQuickLookPreviewExtensionRendersMarkdownTablesInRenderedMode() throws {
        let workspaceURL = try makeTemporaryWorkspace(named: "QuickLookTable", files: [
            "table.md": """
            # Inline Table

            This table is embedded in a Markdown document.

            | Package | Status | Notes |
            | --- | --- | --- |
            | `QuickLook` | **Rendered** | Escaped \\| pipe stays in the cell |

            Tail paragraph.
            """,
        ])

        let preview = try renderedQuickLookPreview(for: workspaceURL.appendingPathComponent("table.md"))
        let text = preview.string

        XCTAssertTrue(text.contains("Inline Table"))
        XCTAssertTrue(text.contains("Package"))
        XCTAssertTrue(text.contains("QuickLook"))
        XCTAssertTrue(text.contains("Rendered"))
        XCTAssertTrue(text.contains("Escaped | pipe stays in the cell"))
        XCTAssertTrue(text.contains("Tail paragraph."))
        XCTAssertFalse(text.contains("| --- |"))
        XCTAssertFalse(text.contains("`QuickLook`"))
        XCTAssertFalse(text.contains("**Rendered**"))
    }

    @MainActor
    func testQuickLookPreviewExtensionRendersJSONWithLineNumbers() throws {
        let workspaceURL = try makeTemporaryWorkspace(named: "QuickLookJSON", files: [
            "payload.json": #"{"z":2,"a":{"enabled":true}}"#,
        ])

        let preview = try renderedQuickLookPreview(for: workspaceURL.appendingPathComponent("payload.json"))
        let text = preview.string

        XCTAssertTrue(text.contains("1  {"))
        XCTAssertTrue(text.contains(#""a""#))
        XCTAssertTrue(text.contains(#""enabled""#))
        XCTAssertTrue(text.contains(#""z""#))
    }

    @MainActor
    func testQuickLookPreviewExtensionRendersEmbeddedMarkdownJSONFamilyFences() throws {
        let workspaceURL = try makeTemporaryWorkspace(named: "QuickLookEmbeddedJSON", files: [
            "payloads.md": """
            # Payloads

            ```json
            {"z":2,"a":{"enabled":true}}
            ```

            ```jsonc
            {
              // comment
              "feature": {
                "enabled": true,
              },
            }
            ```

            ```ndjson
            {"event":"open","metadata":{"path":"README.md"}}
            {"event":"close","metadata":{"path":"README.md"}}
            ```

            ```jsonl
            {"line":1,"message":"jsonl alias"}
            {"line":2,"message":"same parser as ndjson"}
            ```
            """,
        ])

        let preview = try renderedQuickLookPreview(for: workspaceURL.appendingPathComponent("payloads.md"))
        let text = preview.string

        XCTAssertFalse(text.contains("```json"))
        XCTAssertFalse(text.contains("```jsonc"))
        XCTAssertFalse(text.contains("```ndjson"))
        XCTAssertFalse(text.contains("```jsonl"))
        XCTAssertTrue(text.contains("1  {"))
        XCTAssertTrue(text.contains(#""enabled""#))
        XCTAssertTrue(text.contains(#""feature""#))
        XCTAssertTrue(text.contains(#"1  {"event":"open","metadata":{"path":"README.md"}}"#))
        XCTAssertTrue(text.contains(#"1  {"line":1,"message":"jsonl alias"}"#))
        XCTAssertTrue(text.contains(#"2  {"line":2,"message":"same parser as ndjson"}"#))
    }

    @MainActor
    func testQuickLookPreviewExtensionCollapsesJSONContainers() throws {
        let workspaceURL = try makeTemporaryWorkspace(named: "QuickLookJSONCollapse", files: [
            "payload.json": #"{"z":2,"a":{"enabled":true},"items":[{"id":1},{"id":2}]}"#,
        ])
        let controller = try preparedQuickLookPreviewController(for: workspaceURL.appendingPathComponent("payload.json"))
        let selector = NSSelectorFromString("collapseJSONPreviewForTesting")
        XCTAssertTrue(controller.responds(to: selector))

        _ = controller.perform(selector)
        let text = try currentQuickLookPreviewText(in: controller)

        XCTAssertTrue(text.contains(#""a": {...}"#))
        XCTAssertTrue(text.contains(#""items": [...]"#))
        XCTAssertTrue(text.contains(#""z": 2"#))
        XCTAssertFalse(text.contains(#""enabled": true"#))
    }

    @MainActor
    func testQuickLookPreviewExtensionCollapsesJSONCAndNDJSON() throws {
        let workspaceURL = try makeTemporaryWorkspace(named: "QuickLookJSONFamilyCollapse", files: [
            "settings.jsonc": """
            {
              // comment
              "feature": {
                "enabled": true,
              },
            }
            """,
            "events.ndjson": """
            {"event":"open","metadata":{"path":"README.md"}}
            {"event":"close","metadata":{"path":"README.md"}}
            """,
            "events.jsonl": """
            {"line":1,"message":"jsonl alias"}
            {"line":2,"message":"same parser as ndjson"}
            """,
        ])

        let jsoncController = try preparedQuickLookPreviewController(for: workspaceURL.appendingPathComponent("settings.jsonc"))
        let collapseSelector = NSSelectorFromString("collapseJSONPreviewForTesting")
        XCTAssertTrue(jsoncController.responds(to: collapseSelector))
        _ = jsoncController.perform(collapseSelector)
        let jsoncText = try currentQuickLookPreviewText(in: jsoncController)
        XCTAssertTrue(jsoncText.contains(#""feature": {...}"#))
        XCTAssertFalse(jsoncText.contains("comment"))

        let ndjsonController = try preparedQuickLookPreviewController(for: workspaceURL.appendingPathComponent("events.ndjson"))
        XCTAssertTrue(ndjsonController.responds(to: collapseSelector))
        _ = ndjsonController.perform(collapseSelector)
        let ndjsonText = try currentQuickLookPreviewText(in: ndjsonController)
        XCTAssertTrue(ndjsonText.contains("1  record 1: {...}"))
        XCTAssertTrue(ndjsonText.contains("2  record 2: {...}"))

        let jsonlController = try preparedQuickLookPreviewController(for: workspaceURL.appendingPathComponent("events.jsonl"))
        XCTAssertTrue(jsonlController.responds(to: collapseSelector))
        _ = jsonlController.perform(collapseSelector)
        let jsonlText = try currentQuickLookPreviewText(in: jsonlController)
        XCTAssertTrue(jsonlText.contains("1  record 1: {...}"))
        XCTAssertTrue(jsonlText.contains("2  record 2: {...}"))
    }

    @MainActor
    func testQuickLookPreviewExtensionRendersEverySupportedFixtureDocument() throws {
        let fixtureURLs = try supportedQuickLookFixtureURLs()
        XCTAssertFalse(fixtureURLs.isEmpty)

        for fixtureURL in fixtureURLs {
            let preview = try renderedQuickLookPreview(for: fixtureURL)
            XCTAssertGreaterThan(preview.length, 0, fixtureURL.path)
            if ["md", "markdown", "mdown", "mkd", "mkdn"].contains(fixtureURL.pathExtension.lowercased()) {
                let source = try String(contentsOf: fixtureURL, encoding: .utf8)
                if let firstHeading = source.components(separatedBy: "\n").first(where: { $0.hasPrefix("# ") }) {
                    XCTAssertFalse(preview.string.contains(firstHeading), fixtureURL.path)
                }
            }
        }
    }
    #endif

    #if os(macOS)
    @MainActor
    private func renderedQuickLookPreview(for url: URL) throws -> NSAttributedString {
        let controller = try quickLookPreviewController()
        let selector = NSSelectorFromString("renderPreviewForTestingAtURL:")
        XCTAssertTrue(controller.responds(to: selector))
        let result = controller.perform(selector, with: url as NSURL)
        return try XCTUnwrap(result?.takeUnretainedValue() as? NSAttributedString)
    }

    @MainActor
    private func preparedQuickLookPreviewController(for url: URL) throws -> NSViewController {
        let controller = try quickLookPreviewController()
        _ = controller.view
        let selector = NSSelectorFromString("preparePreviewForTestingAtURL:")
        XCTAssertTrue(controller.responds(to: selector))
        let result = controller.perform(selector, with: url as NSURL)
        let prepared = try XCTUnwrap(result?.takeUnretainedValue() as? NSNumber)
        XCTAssertTrue(prepared.boolValue)
        return controller
    }

    @MainActor
    private func currentQuickLookPreviewText(in controller: NSViewController) throws -> String {
        let selector = NSSelectorFromString("currentPreviewTextForTesting")
        XCTAssertTrue(controller.responds(to: selector))
        let result = controller.perform(selector)
        let text = try XCTUnwrap(result?.takeUnretainedValue() as? NSString)
        return text as String
    }

    private func findSegmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl {
            return control
        }
        for subview in view.subviews {
            if let control = findSegmentedControl(in: subview) {
                return control
            }
        }
        return nil
    }

    @MainActor
    private func quickLookPreviewController() throws -> NSViewController {
        let extensionBundle = try quickLookExtensionBundle()
        try loadQuickLookExtensionCode(from: extensionBundle)

        let extensionDictionary = try XCTUnwrap(extensionBundle.infoDictionary?["NSExtension"] as? [String: Any])
        let className = try XCTUnwrap(extensionDictionary["NSExtensionPrincipalClass"] as? String)
        let resolvedClassName = className.contains("$")
            ? "Quick_Markdown_Viewer_QuickLook.PreviewViewController"
            : className
        let candidateClassNames = [
            resolvedClassName,
            "_TtC31Quick_Markdown_Viewer_QuickLook21PreviewViewController",
        ]
        let viewControllerType = try XCTUnwrap(
            candidateClassNames.compactMap { NSClassFromString($0) as? NSViewController.Type }.first
        )
        let controller = viewControllerType.init(nibName: nil, bundle: extensionBundle)
        return controller
    }

    private func loadQuickLookExtensionCode(from extensionBundle: Bundle) throws {
        if extensionBundle.load() {
            return
        }

        let executableName = try XCTUnwrap(extensionBundle.infoDictionary?["CFBundleExecutable"] as? String)
        let debugDylibURL = extensionBundle.bundleURL
            .appendingPathComponent("Contents/MacOS/\(executableName).debug.dylib")
        guard FileManager.default.fileExists(atPath: debugDylibURL.path) else {
            return
        }
        guard dlopen(debugDylibURL.path, RTLD_NOW | RTLD_GLOBAL) != nil else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen failure"
            throw NSError(
                domain: "QuickLookPreviewTest",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    private func quickLookExtensionBundle() throws -> Bundle {
        let bundleName = "Quick Markdown Viewer QuickLook.appex"
        let candidates = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns/\(bundleName)", isDirectory: true),
            Bundle(for: Self.self).bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent(bundleName, isDirectory: true),
        ]

        for candidate in candidates {
            if let bundle = Bundle(url: candidate) {
                return bundle
            }
        }

        return try XCTUnwrap(nil, "Expected embedded Quick Look extension bundle")
    }

    private func supportedQuickLookFixtureURLs() throws -> [URL] {
        let supportedExtensions: Set<String> = [
            "md",
            "markdown",
            "mdown",
            "mkd",
            "mkdn",
            "mermaid",
            "mmd",
            "csv",
            "json",
            "jsonc",
            "jsonl",
            "ndjson",
            "tsv",
        ]
        let roots = [
            repoRootURL.appendingPathComponent("Fixtures/docs", isDirectory: true),
            repoRootURL.appendingPathComponent("Fixtures/app-store", isDirectory: true),
        ]

        var urls: [URL] = []
        for root in roots {
            let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            while let url = enumerator?.nextObject() as? URL {
                guard supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
                let values = try url.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                urls.append(url)
            }
        }

        return urls.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
    #endif

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

#if os(macOS)
private extension NSAttributedString {
    var containsImageAttachment: Bool {
        var found = false
        enumerateAttribute(.attachment, in: NSRange(location: 0, length: length)) { value, _, stop in
            guard let attachment = value as? NSTextAttachment else { return }
            if attachment.image != nil {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}
#endif
