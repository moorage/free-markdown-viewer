//
//  Quick_Markdown_ViewerUITests.swift
//  Quick Markdown ViewerUITests
//
//  Created by Matthew Moore on 3/19/26.
//

import XCTest
#if os(iOS)
import PDFKit
import UIKit
#endif

final class Quick_Markdown_ViewerUITests: XCTestCase {

    private struct UITestHarnessCommandRequest: Codable {
        let id: String
        let command: String
        let arguments: [String: String]?
    }

    private struct UITestHarnessCommandResponse: Codable {
        let id: String
        let status: String
        let result: [String: String]?
        let error: String?
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSmokeLaunchShowsHarnessShell() throws {
        let app = XCUIApplication()
        let fixtureRoot = repoRootURL().appendingPathComponent("Fixtures/docs", isDirectory: true).path
        app.launchArguments = [
            "--fixture-root", fixtureRoot,
            "--open-file", "basic_typography.md",
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["nav.back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["nav.forward"].exists)
        XCTAssertTrue(app.buttons["toolbar.revealInFinder"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["nav.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["document.scrollView"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testColdLaunchWithoutWorkspaceShowsOpenFolderPrompt() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["empty-state.message"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Open a folder of Markdown, CSV, or TSV files to get started."].exists)
        XCTAssertTrue(app.buttons["empty-state.open-folder"].exists)
        XCTAssertTrue(app.staticTexts["empty-state.commandLineTool.message"].exists)
        XCTAssertTrue(app.staticTexts["Install `qmv` in ~/.local/bin to open folders from Terminal."].exists)
        XCTAssertTrue(app.buttons["empty-state.commandLineTool.button"].exists)
    }

    @MainActor
    func testEmptyStateLoadsGitHubWorkspaceFromURL() throws {
        let app = XCUIApplication()
        let fixtureURL = try makeGitHubFixtureFile()
        app.launchArguments = [
            "--ui-test-mode", "1",
            "--ui-test-github-fixture", fixtureURL.path,
        ]
        app.launch()
        app.activate()

        let field = app.textFields["empty-state.github-url.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("https://github.com/moorage/free-markdown-viewer/tree/main/docs")

        let loadButton = app.buttons["empty-state.github-url.load"]
        XCTAssertTrue(loadButton.exists)
        loadButton.tap()

        XCTAssertTrue(app.buttons["sidebar.node.guide.md"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["moorage/free-markdown-viewer@main/docs > guide.md"].waitForExistence(timeout: 5))
    }

    #if os(iOS)
    @MainActor
    func testiPhoneEmptyStateLoadsGitHubWorkspaceFromURL() throws {
        let app = XCUIApplication()
        let fixtureURL = try makeGitHubFixtureFile()
        app.launchArguments = [
            "--platform-target", "ios",
            "--device-class", "iphone",
            "--ui-test-mode", "1",
            "--ui-test-github-fixture", fixtureURL.path,
        ]
        app.launch()

        let field = app.textFields["empty-state.github-url.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("https://github.com/moorage/free-markdown-viewer")
        app.buttons["empty-state.github-url.load"].tap()

        XCTAssertTrue(app.staticTexts["moorage/free-markdown-viewer@main > README.md"].waitForExistence(timeout: 5))
    }
    #endif

    @MainActor
    func testInstallCommandLineToolButtonWritesLauncherAndHidesPrompt() throws {
        let app = XCUIApplication()
        let installURL = URL(fileURLWithPath: "/tmp").appendingPathComponent(UUID().uuidString).appendingPathComponent("qmv")

        app.launchArguments = [
            "--ui-test-mode", "1",
            "--ui-test-reset-command-line-tool-install-state",
            "--ui-test-install-command-line-tool", installURL.path,
        ]
        app.launch()
        app.activate()

        let installButton = app.buttons["empty-state.commandLineTool.button"]
        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertTrue(installButton.waitForExistence(timeout: 5))

        installButton.click()

        let installPromptGone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: installPromptGone, object: installButton)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
        XCTAssertFalse(app.staticTexts["empty-state.commandLineTool.message"].exists)
        XCTAssertTrue(app.staticTexts["command-line-tool.post-install.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["command-line-tool.post-install.message"].exists)
        XCTAssertTrue(app.buttons["command-line-tool.post-install.copy"].exists)
        XCTAssertTrue(app.buttons["command-line-tool.post-install.done"].exists)
    }

    @MainActor
    func testOpenFolderCommandUpdatesSidebarAndTitle() throws {
        let app = XCUIApplication()
        let initialFixtureRoot = repoRootURL().appendingPathComponent("Fixtures/docs", isDirectory: true).path
        let selectedFolder = try makeWorkspace(named: "UITest Workspace", files: [
            "zeta.md": "# Zeta\n\nOpened from UI test."
        ])

        app.launchArguments = [
            "--fixture-root", initialFixtureRoot,
            "--open-file", "basic_typography.md",
            "--ui-test-open-folder", selectedFolder.path,
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["nav.back"].waitForExistence(timeout: 5))

        app.windows.element(boundBy: 0).click()
        app.typeKey("o", modifierFlags: .command)

        let openedSidebarNode = app.buttons["sidebar.node.zeta.md"]
        XCTAssertTrue(openedSidebarNode.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["UITest Workspace > zeta.md"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testEmptyWorkspaceShowsCenteredOpenFolderCallToAction() throws {
        let app = XCUIApplication()
        let initialFixtureRoot = repoRootURL().appendingPathComponent("Fixtures/docs", isDirectory: true).path
        let emptyWorkspace = try makeWorkspace(named: "Empty Workspace", files: [:])

        app.launchArguments = [
            "--fixture-root", initialFixtureRoot,
            "--open-file", "basic_typography.md",
            "--ui-test-open-folder", emptyWorkspace.path,
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["nav.back"].waitForExistence(timeout: 5))

        app.windows.element(boundBy: 0).click()
        app.typeKey("o", modifierFlags: .command)

        XCTAssertTrue(app.staticTexts["No Markdown, CSV, or TSV files found."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["empty-state.open-folder"].exists)
    }

    #if os(iOS)
    @MainActor
    func testiPhoneCSVDocumentShowsTabularAndPrintControls() throws {
        let app = XCUIApplication()
        let workspace = try makeWorkspace(named: "iPhone CSV Workspace", files: [
            "table.csv": "Name,Count,Notes\nAlpha,1,First row\nBeta,2,Second row"
        ])

        app.launchArguments = [
            "--fixture-root", workspace.path,
            "--open-file", "table.csv",
            "--platform-target", "ios",
            "--device-class", "iphone",
            "--ui-test-mode", "1",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.tableWrap"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["toolbar.tableSizing"].exists)
        XCTAssertTrue(app.buttons["toolbar.print"].exists)
    }

    @MainActor
    func testiOSExportPrintedAllDocumentsWritesNonEmptyMultiPagePDF() throws {
        let app = XCUIApplication()
        let repeatedBody = (1...220).map { "Paragraph \($0)" }.joined(separator: "\n\n")
        let workspace = try makeWorkspace(named: "iOS Print All Workspace", files: [
            "alpha.md": "# Alpha\n\n\(repeatedBody)",
            "beta.md": "# Beta\n\n\(repeatedBody)",
            "gamma.md": "# Gamma\n\n\(repeatedBody)"
        ])
        let commandDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("print-all-ios.pdf")
        try FileManager.default.createDirectory(at: commandDirectory, withIntermediateDirectories: true)

        let deviceClass = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        app.launchArguments = [
            "--fixture-root", workspace.path,
            "--open-file", "alpha.md",
            "--platform-target", "ios",
            "--device-class", deviceClass,
            "--harness-command-dir", commandDirectory.path,
            "--ui-test-mode", "1",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["iOS Print All Workspace > alpha.md"].waitForExistence(timeout: 5))

        let response = try waitForHarnessResponse(
            command: "exportPrintedAllDocuments",
            arguments: ["path": outputURL.path],
            in: commandDirectory,
            timeout: 20
        )

        XCTAssertEqual(response.status, "ok")
        let pdfData = try Data(contentsOf: outputURL)
        XCTAssertTrue(pdfData.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(pdfData.count, 10_000)

        let document = try XCTUnwrap(PDFDocument(url: outputURL))
        XCTAssertGreaterThan(document.pageCount, 1)
        let firstPage = try XCTUnwrap(document.page(at: 0))
        XCTAssertTrue(hasSubstantialInk(on: firstPage))
    }
    #endif

    @MainActor
    func testClickingSidebarNodeSwitchesPrimaryViewer() throws {
        let app = XCUIApplication()
        let workspace = try makeWorkspace(named: "Click Workspace", files: [
            "alpha.md": "# Alpha\n\nFirst file.",
            "beta.md": "# Beta\n\nSecond file."
        ])

        app.launchArguments = [
            "--fixture-root", workspace.path,
            "--open-file", "alpha.md",
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Click Workspace > alpha.md"].waitForExistence(timeout: 5))

        let betaNode = app.buttons["sidebar.node.beta.md"]
        XCTAssertTrue(betaNode.waitForExistence(timeout: 5))
        betaNode.click()

        XCTAssertTrue(app.staticTexts["Click Workspace > beta.md"].waitForExistence(timeout: 5))
    }

    #if os(macOS)
    @MainActor
    func testToolbarPrintMenuTriggersSelectedAndAllDocumentActions() throws {
        let app = XCUIApplication()
        let workspace = try makeWorkspace(named: "Print UI Workspace", files: [
            "guide.md": "# Guide\n\nFirst file.",
            "table.csv": "Name,Count\nAlpha,1\nBeta,2"
        ])
        let commandDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: commandDirectory, withIntermediateDirectories: true)

        app.launchArguments = [
            "--fixture-root", workspace.path,
            "--open-file", "guide.md",
            "--harness-command-dir", commandDirectory.path,
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
        let printButton = app.buttons["ui-test.printSelectedAction"].firstMatch
        XCTAssertTrue(printButton.waitForExistence(timeout: 5))
        printButton.click()

        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["print.request.scope"], label: "selectedFile", timeout: 5))
        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["print.request.status"], label: "presented", timeout: 5))

        let printAllButton = app.buttons["ui-test.printAllAction"].firstMatch
        XCTAssertTrue(printAllButton.waitForExistence(timeout: 5))
        printAllButton.click()

        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["print.request.scope"], label: "allFiles", timeout: 5))
        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["print.request.status"], label: "presented", timeout: 5))
    }

    @MainActor
    func testJSONViewerShowsStickyAncestorHeaderAfterScrollingDeepNestedRows() throws {
        let app = XCUIApplication()
        let fixtureRoot = repoRootURL().appendingPathComponent("Fixtures/docs", isDirectory: true).path

        app.launchArguments = [
            "--fixture-root", fixtureRoot,
            "--open-file", "json_sticky_headers_showcase.json",
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(waitForWindowTitle(app, label: "Fixtures/docs > json_sticky_headers_showcase.json", timeout: 5))
        XCTAssertTrue(app.scrollViews["document.scrollView"].waitForExistence(timeout: 5))

        let jsonScrollView = app.scrollViews["json.viewerScrollView"]
        XCTAssertTrue(jsonScrollView.waitForExistence(timeout: 5))
        let stickyHeader = app.descendants(matching: .any)["json.stickyHeader"].firstMatch
        let expectedHeaderFragment = "workspace > release > streams > [1] > records"
        for _ in 0..<18 {
            if stickyHeader.exists && stickyHeader.label.contains(expectedHeaderFragment) {
                break
            }
            jsonScrollView.swipeUp()
        }

        XCTAssertTrue(
            waitForElementLabelContaining(
                stickyHeader,
                expectedHeaderFragment,
                timeout: 5
            )
        )
    }
    #endif

    @MainActor
    func testSidebarArrowKeysSwitchMarkdownFiles() throws {
        let app = XCUIApplication()
        let workspace = try makeWorkspace(named: "Keyboard Workspace", files: [
            "alpha.md": "# Alpha\n\nFirst file.",
            "beta.md": "# Beta\n\nSecond file.",
            "gamma.md": "# Gamma\n\nThird file."
        ])

        app.launchArguments = [
            "--fixture-root", workspace.path,
            "--open-file", "alpha.md",
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Keyboard Workspace > alpha.md"].waitForExistence(timeout: 5))

        let alphaNode = app.buttons["sidebar.node.alpha.md"]
        XCTAssertTrue(alphaNode.waitForExistence(timeout: 5))
        alphaNode.click()

        app.typeKey(XCUIKeyboardKey.downArrow.rawValue, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Keyboard Workspace > beta.md"].waitForExistence(timeout: 5))

        app.typeKey(XCUIKeyboardKey.downArrow.rawValue, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Keyboard Workspace > gamma.md"].waitForExistence(timeout: 5))

        app.typeKey(XCUIKeyboardKey.upArrow.rawValue, modifierFlags: [])
        XCTAssertTrue(app.staticTexts["Keyboard Workspace > beta.md"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSidebarCompactsFoldersAndExpandsWithArrowKeys() throws {
        let app = XCUIApplication()
        let workspace = try makeWorkspace(named: "Tree Workspace", files: [
            "emptyfolder/fullfolder/nested.md": "# Nested\n\nDeep file.",
            "root.md": "# Root\n\nTop level file."
        ])

        app.launchArguments = [
            "--fixture-root", workspace.path,
            "--open-file", "root.md",
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))

        let compactFolder = app.buttons["sidebar.folder.emptyfolder.fullfolder"]
        XCTAssertTrue(compactFolder.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sidebar.node.emptyfolder.fullfolder.nested.md"].exists)

        compactFolder.click()
        let nestedNode = app.buttons["sidebar.node.emptyfolder.fullfolder.nested.md"]
        XCTAssertTrue(nestedNode.waitForExistence(timeout: 5))

        app.typeKey(XCUIKeyboardKey.leftArrow.rawValue, modifierFlags: [])
        XCTAssertFalse(nestedNode.exists)

        app.typeKey(XCUIKeyboardKey.rightArrow.rawValue, modifierFlags: [])
        XCTAssertTrue(nestedNode.waitForExistence(timeout: 5))

        app.typeKey(XCUIKeyboardKey.downArrow.rawValue, modifierFlags: [])
        XCTAssertTrue(waitForWindowTitle(app, label: "Tree Workspace > nested.md", timeout: 5))

        app.typeKey(XCUIKeyboardKey.leftArrow.rawValue, modifierFlags: [])
        app.typeKey(XCUIKeyboardKey.leftArrow.rawValue, modifierFlags: [])
        XCTAssertTrue(compactFolder.waitForExistence(timeout: 5))
        XCTAssertFalse(nestedNode.exists)
    }

    @MainActor
    func testSearchCurrentDocumentFindsMatchesAndNextResultStaysInDocument() throws {
        let app = XCUIApplication()
        let workspace = try makeWorkspace(named: "Search Current Workspace", files: [
            "alpha.md": "# Lifecycle Overview\n\nLifecycle starts here.\n\nAnother lifecycle reference.",
            "beta.md": "# Beta\n\nLifecycle exists outside the selected document."
        ])

        app.launchArguments = [
            "--fixture-root", workspace.path,
            "--open-file", "alpha.md",
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(waitForWindowTitle(app, label: "Search Current Workspace > alpha.md", timeout: 5))

        let searchTab = sidebarSearchTab(in: app)
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5))
        searchTab.click()

        let searchField = searchField(in: app)
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()
        searchField.typeText("lifecycle")
        XCTAssertEqual(searchField.value as? String, "lifecycle")
        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["search.query"], label: "lifecycle", timeout: 2))
        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["search.resultCount"], label: "3", timeout: 5))

        let alphaResult = app.descendants(matching: .any)["search.result.file.alpha-md"].firstMatch
        XCTAssertTrue(alphaResult.waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["search.result.file.beta-md"].firstMatch.exists)

        alphaResult.click()
        XCTAssertTrue(waitForWindowTitle(app, label: "Search Current Workspace > alpha.md", timeout: 5))

        let nextButton = app.buttons["search.next"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
        nextButton.click()
        XCTAssertTrue(waitForWindowTitle(app, label: "Search Current Workspace > alpha.md", timeout: 5))
    }

    @MainActor
    func testSearchAllDocumentsFindsMatchesAndOpensClickedResult() throws {
        let app = XCUIApplication()
        let workspace = try makeWorkspace(named: "Search All Workspace", files: [
            "alpha.md": "# Alpha\n\nNo global token here.",
            "notes/beta.md": "# Beta\n\nThe globaltoken result lives here.",
            "notes/gamma.md": "# Gamma\n\nAnother globaltoken result."
        ])

        app.launchArguments = [
            "--fixture-root", workspace.path,
            "--open-file", "alpha.md",
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(waitForWindowTitle(app, label: "Search All Workspace > alpha.md", timeout: 5))

        let searchTab = sidebarSearchTab(in: app)
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5))
        searchTab.click()

        let searchField = searchField(in: app)
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        let allScope = app.radioButtons["All"].firstMatch
        XCTAssertTrue(allScope.waitForExistence(timeout: 5))
        allScope.click()
        searchField.click()
        searchField.typeText("globaltoken")
        XCTAssertEqual(searchField.value as? String, "globaltoken")
        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["search.query"], label: "globaltoken", timeout: 2))
        XCTAssertTrue(waitForElement(app.descendants(matching: .any)["search.resultCount"], label: "2", timeout: 5))

        let betaResult = app.descendants(matching: .any)["search.result.file.notes-beta-md"].firstMatch
        XCTAssertTrue(betaResult.waitForExistence(timeout: 5))
        betaResult.click()

        XCTAssertTrue(waitForWindowTitle(app, label: "Search All Workspace > beta.md", timeout: 5))
    }

    #if os(iOS)
    @MainActor
    func testiPhoneDrawerQuickFilterNarrowsSidebarFiles() throws {
        let app = XCUIApplication()
        let workspace = try makeWorkspace(named: "iPhone Filter Workspace", files: [
            "alpha.md": "# Alpha\n\nFirst file.",
            "beta-notes.md": "# Beta\n\nSecond file.",
            "release-plan.md": "# Release\n\nThird file."
        ])

        app.launchArguments = [
            "--fixture-root", workspace.path,
            "--open-file", "alpha.md",
            "--platform-target", "ios",
            "--device-class", "iphone",
            "--ui-test-mode", "1",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.openFolder.sidebar"].waitForExistence(timeout: 5))
        app.buttons["toolbar.openFolder.sidebar"].tap()

        let filterField = app.textFields["sidebar.filterField"]
        XCTAssertTrue(filterField.waitForExistence(timeout: 5))
        filterField.tap()
        filterField.typeText("beta")

        XCTAssertTrue(app.buttons["sidebar.node.beta-notes.md"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sidebar.node.alpha.md"].waitForExistence(timeout: 1))
        XCTAssertFalse(app.buttons["sidebar.node.release-plan.md"].waitForExistence(timeout: 1))
    }
    #endif

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
        }
    }

    private func makeWorkspace(named folderName: String, files: [String: String]) throws -> URL {
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

    private func makeGitHubFixtureFile() throws -> URL {
        let payload: [String: Any] = [
            "repositories": [
                "moorage/free-markdown-viewer": [
                    "default_branch": "main"
                ]
            ],
            "commits": [
                "moorage/free-markdown-viewer": [
                    "main": "sha-main"
                ]
            ],
            "trees": [
                "moorage/free-markdown-viewer": [
                    "sha-main": [
                        ["path": "README.md", "type": "blob"],
                        ["path": "docs/guide.md", "type": "blob"]
                    ]
                ]
            ],
            "files": [
                "moorage/free-markdown-viewer": [
                    "sha-main": [
                        "README.md": "# Repo Root\n\nWelcome.",
                        "docs/guide.md": "# Guide\n\nLoaded from docs."
                    ]
                ]
            ]
        ]
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-github-ui-fixture.json")
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        try data.write(to: url, options: .atomic)
        return url
    }

    private func waitForHarnessResponse(
        command: String,
        arguments: [String: String]?,
        in directoryURL: URL,
        timeout: TimeInterval = 5
    ) throws -> UITestHarnessCommandResponse {
        let inboxURL = directoryURL.appendingPathComponent("inbox", isDirectory: true)
        let outboxURL = directoryURL.appendingPathComponent("outbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outboxURL, withIntermediateDirectories: true)

        let request = UITestHarnessCommandRequest(
            id: UUID().uuidString,
            command: command,
            arguments: arguments
        )
        let requestURL = inboxURL.appendingPathComponent("\(request.id).json")
        let responseURL = outboxURL.appendingPathComponent("\(request.id).json")
        let requestData = try JSONEncoder().encode(request)
        try requestData.write(to: requestURL, options: .atomic)

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: responseURL.path) {
                let responseData = try Data(contentsOf: responseURL)
                return try JSONDecoder().decode(UITestHarnessCommandResponse.self, from: responseData)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        throw XCTSkip("Timed out waiting for harness response for \(command)")
    }

    private func waitForElement(_ element: XCUIElement, label: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForElementLabelContaining(_ element: XCUIElement, _ text: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForWindowTitle(_ app: XCUIApplication, label: String, timeout: TimeInterval) -> Bool {
        waitForElement(app.descendants(matching: .any)["nav.title"], label: label, timeout: timeout)
    }

    private func waitForWindowCount(_ app: XCUIApplication, expected: Int, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { _, _ in
            app.windows.count == expected
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func searchField(in app: XCUIApplication) -> XCUIElement {
        let searchField = app.searchFields["search.field"]
        if searchField.waitForExistence(timeout: 1) {
            return searchField
        }
        return app.textFields["search.field"]
    }

    private func sidebarSearchTab(in app: XCUIApplication) -> XCUIElement {
        app.buttons["sidebar.tab.search"].firstMatch
    }

    #if os(iOS)
    private func hasSubstantialInk(on page: PDFPage) -> Bool {
        let image = page.thumbnail(of: CGSize(width: 320, height: 320), for: .mediaBox)
        guard let cgImage = image.cgImage,
              let dataProvider = cgImage.dataProvider,
              let pixelData = dataProvider.data else {
            return false
        }

        let bytes = CFDataGetBytePtr(pixelData)
        let length = CFDataGetLength(pixelData)
        guard let bytes, length > 0 else { return false }

        let bytesPerPixel = max(cgImage.bitsPerPixel / 8, 1)
        var inkedPixels = 0
        var pixelCount = 0
        var index = 0

        while index + (bytesPerPixel - 1) < length {
            let red = bytes[index]
            let green = bytes[index + min(1, bytesPerPixel - 1)]
            let blue = bytes[index + min(2, bytesPerPixel - 1)]
            if red < 245 || green < 245 || blue < 245 {
                inkedPixels += 1
            }
            pixelCount += 1
            index += bytesPerPixel
        }

        guard pixelCount > 0 else { return false }
        return Double(inkedPixels) / Double(pixelCount) > 0.02
    }
    #endif

    private func repoRootURL(filePath: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

}
