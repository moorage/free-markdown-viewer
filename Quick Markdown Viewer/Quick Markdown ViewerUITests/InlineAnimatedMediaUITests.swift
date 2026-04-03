import XCTest

final class InlineAnimatedMediaUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAnimatedGIFFixtureShowsAccessibleInlineImageBlock() throws {
        let app = launchApp(opening: "animated_gif.md")
        let imageBlocks = elements(in: app, withIdentifierPrefix: "block.image.")

        XCTAssertTrue(imageBlocks.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAnimatedAPNGFixtureShowsAccessibleInlineImageBlock() throws {
        let app = launchApp(opening: "animated_apng.md")
        let imageBlocks = elements(in: app, withIdentifierPrefix: "block.image.")

        XCTAssertTrue(imageBlocks.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLocalMP4FixtureShowsAccessibleVideoBlockAndPlayButton() throws {
        let app = launchApp(opening: "video_local_mp4.md")
        let videoBlocks = elements(in: app, withIdentifierPrefix: "block.video.")
        let playButtons = elements(in: app, withIdentifierPrefix: "video.playButton.")

        XCTAssertTrue(videoBlocks.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(playButtons.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchApp(opening fileName: String) -> XCUIApplication {
        let app = XCUIApplication()
        let fixtureRoot = repoRootURL().appendingPathComponent("Fixtures/docs", isDirectory: true).path

        app.launchArguments = [
            "--fixture-root", fixtureRoot,
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
