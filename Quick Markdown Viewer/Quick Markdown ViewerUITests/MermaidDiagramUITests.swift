import XCTest

final class MermaidDiagramUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testInlineMermaidDiagramOpensZoomablePreview() throws {
        let app = launchApp(opening: "mermaid_inline_showcase.md")
        let diagramBlocks = elements(in: app, withIdentifierPrefix: "block.mermaid.")

        XCTAssertTrue(diagramBlocks.firstMatch.waitForExistence(timeout: 5))
        diagramBlocks.firstMatch.click()

        XCTAssertTrue(app.descendants(matching: .any)["mermaid-preview.container"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mermaid-preview.zoomIn"].exists)
        XCTAssertTrue(app.buttons["mermaid-preview.zoomOut"].exists)
        XCTAssertTrue(app.buttons["mermaid-preview.fit"].exists)
        XCTAssertTrue(app.buttons["mermaid-preview.reset"].exists)
        XCTAssertTrue(app.buttons["mermaid-preview.openWindow"].exists)

        app.buttons["mermaid-preview.openWindow"].click()

        let detachedPreview = app.windows["Checkout Flow"]
        XCTAssertTrue(detachedPreview.waitForExistence(timeout: 5))
        XCTAssertTrue(detachedPreview.descendants(matching: .any)["mermaid-preview.container"].exists)
        XCTAssertFalse(detachedPreview.buttons["mermaid-preview.openWindow"].exists)
    }

    @MainActor
    func testStandaloneMermaidFileShowsDiagramBlock() throws {
        let app = launchApp(opening: "mermaid/flowchart_basic.mmd")
        let diagramBlocks = elements(in: app, withIdentifierPrefix: "block.mermaid.")

        XCTAssertTrue(diagramBlocks.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchApp(opening fileName: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--fixture-root", repoRootURL().appendingPathComponent("Fixtures/docs", isDirectory: true).path,
            "--open-file", fileName,
            "--ui-test-mode", "1",
        ]
        app.launch()
        app.activate()

        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["document.scrollView"].waitForExistence(timeout: 5))
        return app
    }

    private func elements(in app: XCUIApplication, withIdentifierPrefix prefix: String) -> XCUIElementQuery {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        return app.descendants(matching: .any).matching(predicate)
    }

    private func repoRootURL(filePath: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
