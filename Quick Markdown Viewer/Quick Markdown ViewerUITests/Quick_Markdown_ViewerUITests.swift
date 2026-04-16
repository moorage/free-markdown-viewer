//
//  Quick_Markdown_ViewerUITests.swift
//  Quick Markdown ViewerUITests
//
//  Created by Matthew Moore on 3/19/26.
//

import XCTest

final class Quick_Markdown_ViewerUITests: XCTestCase {

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
        XCTAssertTrue(app.staticTexts["Open a folder of markdown files to get started."].exists)
        XCTAssertTrue(app.buttons["empty-state.open-folder"].exists)
        XCTAssertTrue(app.staticTexts["empty-state.commandLineTool.message"].exists)
        XCTAssertTrue(app.staticTexts["Install `qmv` in ~/.local/bin to open folders from Terminal."].exists)
        XCTAssertTrue(app.buttons["empty-state.commandLineTool.button"].exists)
    }

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

        XCTAssertTrue(app.staticTexts["No markdown files found."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["empty-state.open-folder"].exists)
    }

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

    private func waitForWindowCount(_ app: XCUIApplication, expected: Int, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { _, _ in
            app.windows.count == expected
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func repoRootURL(filePath: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

}
