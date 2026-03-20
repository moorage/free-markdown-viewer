//
//  Swift_Markdown_ViewerUITests.swift
//  Swift Markdown ViewerUITests
//
//  Created by Matthew Moore on 3/19/26.
//

import XCTest

final class Swift_Markdown_ViewerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSmokeLaunchShowsHarnessShell() throws {
        let app = XCUIApplication()
        let repoRoot = ProcessInfo.processInfo.environment["PWD"] ?? FileManager.default.currentDirectoryPath
        let fixtureRoot = "\(repoRoot)/Fixtures/docs"
        app.launchArguments = [
            "--fixture-root", fixtureRoot,
            "--open-file", "basic_typography.md",
            "--ui-test-mode", "1",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["nav.back"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["nav.forward"].exists)
        XCTAssertTrue(app.staticTexts["nav.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["document.scrollView"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
        }
    }
}
