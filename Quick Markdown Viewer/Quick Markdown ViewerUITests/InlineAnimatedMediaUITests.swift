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
    func testLinkedLocalVideoShowsPreviewAndPlayButton() throws {
        let app = launchApp(
            opening: "basic_typography.md",
            previewURL: repoRootURL().appendingPathComponent("Fixtures/media/rickrolled.mp4").absoluteString
        )
        let closeButton = app.buttons["media-preview.close"]
        let playButtons = elements(in: app, withIdentifierPrefix: "video.playButton.")

        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(playButtons.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLinkedLocalImageShowsPreviewAndCloseButton() throws {
        let app = launchApp(
            opening: "basic_typography.md",
            previewURL: repoRootURL().appendingPathComponent("Fixtures/media/rickrolled.gif").absoluteString
        )

        let closeButton = app.buttons["media-preview.close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["media-preview.open-in-browser"].exists)
    }

    @MainActor
    func testLinkedLocalImagePreviewClosesOnEscape() throws {
        let app = launchApp(
            opening: "basic_typography.md",
            previewURL: repoRootURL().appendingPathComponent("Fixtures/media/rickrolled.gif").absoluteString
        )

        let closeButton = app.buttons["media-preview.close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))

        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])

        let previewGone = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: previewGone, object: closeButton)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed)
    }

    @MainActor
    private func launchApp(opening fileName: String, fixtureRoot: String? = nil, previewURL: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        let resolvedFixtureRoot = fixtureRoot ?? repoRootURL().appendingPathComponent("Fixtures/docs", isDirectory: true).path

        app.launchArguments = [
            "--fixture-root", resolvedFixtureRoot,
            "--open-file", fileName,
            "--ui-test-mode", "1",
        ]
        if let previewURL {
            app.launchArguments.append(contentsOf: ["--ui-test-open-linked-media", previewURL])
        }
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

    private func repoRootURL(filePath: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
