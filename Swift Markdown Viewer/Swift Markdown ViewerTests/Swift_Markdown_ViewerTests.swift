//
//  Swift_Markdown_ViewerTests.swift
//  Swift Markdown ViewerTests
//
//  Created by Matthew Moore on 3/19/26.
//

import XCTest
@testable import Swift_Markdown_Viewer

final class Swift_Markdown_ViewerTests: XCTestCase {
    private final class HTMLTextCollector: NSObject, XMLParserDelegate {
        var parts: [String] = []

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            parts.append(string)
        }
    }

    private static var retainedModels: [AppModel] = []

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
            "--platform-target", "ios",
            "--device-class", "ipad",
            "--dump-visible-state", stateURL.path,
            "--dump-perf-state", perfURL.path,
            "--ui-test-mode", "1",
        ])

        XCTAssertEqual(options.fixtureRoot?.path, "/tmp/fixtures")
        XCTAssertEqual(options.openFile, "basic_typography.md")
        XCTAssertEqual(options.uiTestOpenFolderURL?.path, "/tmp/selected-folder")
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
        XCTAssertEqual(model.documentText, "No markdown files found.")
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
                selectedFile: "beta.md"
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

    func testWorkspaceProviderReturnsRelativePathsForTemporaryRoots() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "# Alpha".write(to: tempRoot.appendingPathComponent("alpha.md"), atomically: true, encoding: .utf8)
        try "# Beta".write(to: tempRoot.appendingPathComponent("beta.md"), atomically: true, encoding: .utf8)

        let provider = LocalWorkspaceProvider(rootURL: tempRoot, embeddedDocs: EmbeddedFixtures.docs)
        let workspace = try provider.loadRoot()

        XCTAssertEqual(workspace.files.map(\.path.rawValue), ["alpha.md", "beta.md"])
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
            MarkdownFileNode(path: WorkspacePath(rawValue: "alpha.md"), name: "alpha.md"),
            MarkdownFileNode(path: WorkspacePath(rawValue: "beta.md"), name: "beta.md"),
            MarkdownFileNode(path: WorkspacePath(rawValue: "gamma.md"), name: "gamma.md"),
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
        let rendered = SelectableDocumentFormatter.attributedText(from: blocks).string

        XCTAssertTrue(rendered.contains("Heading"))
        XCTAssertTrue(rendered.contains("Intro with bold text."))
        XCTAssertTrue(rendered.contains("- Item one"))
        XCTAssertTrue(rendered.contains("1. Item two"))
        XCTAssertTrue(rendered.contains("let x = 1"))
        XCTAssertFalse(rendered.contains("# Heading"))
        XCTAssertFalse(rendered.contains("**bold**"))
        XCTAssertFalse(rendered.contains("```"))
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

    func testMarkdownRendererParsesTableFromSpecExample() {
        let markdown = """
        | abc | defghi |
        :-: | -----------:
        bar | baz
        """

        let blocks = MarkdownRenderer.blocks(from: markdown)

        XCTAssertEqual(blocks.map(\.kind), [.table])
        XCTAssertEqual(blocks[0].plainText, "abc defghi bar baz")
        XCTAssertEqual(blocks[0].table?.header, ["abc", "defghi"])
        XCTAssertEqual(blocks[0].table?.rows, [["bar", "baz"]])
        XCTAssertEqual(blocks[0].table?.alignments, [.center, .trailing])
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
        XCTAssertEqual(blocks[2].table?.header, ["abc", "defghi"])
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
        XCTAssertEqual(tableBlocks.first?.table?.header, ["foo", "bar"])
        XCTAssertEqual(tableBlocks.first?.table?.rows, [["baz", "bim"]])
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
