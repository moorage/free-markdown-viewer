//
//  Swift_Markdown_ViewerUITestsLaunchTests.swift
//  Swift Markdown ViewerUITests
//
//  Created by Matthew Moore on 3/19/26.
//

import XCTest

final class Swift_Markdown_ViewerUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
