import XCTest
@testable import Swift_Markdown_Viewer

final class InlineAnimatedMediaTests: XCTestCase {
    private var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testRepoContainsRickrollMediaFixtures() {
        let expectedFiles = [
            "rickrolled.gif",
            "rickrolled.mp4",
            "rickrolled.png",
        ]

        for fileName in expectedFiles {
            let fileURL = repoRootURL.appendingPathComponent("Fixtures/media/\(fileName)")
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: fileURL.path),
                "Expected \(fileName) to exist in Fixtures/media."
            )
        }
    }

    @MainActor
    func testAnimatedGIFFixtureExportsAnimatedImageVisibleBlock() async throws {
        let snapshot = try await loadStateSnapshot(for: "animated_gif.md")

        XCTAssertEqual(snapshot.selectedFile, "animated_gif.md")
        XCTAssertEqual(snapshot.visibleBlocks.map(\.kind), ["heading", "paragraph", "animatedImage", "paragraph"])
    }

    @MainActor
    func testAnimatedAPNGFixtureExportsAnimatedImageVisibleBlock() async throws {
        let snapshot = try await loadStateSnapshot(for: "animated_apng.md")

        XCTAssertEqual(snapshot.selectedFile, "animated_apng.md")
        XCTAssertEqual(snapshot.visibleBlocks.map(\.kind), ["heading", "paragraph", "animatedImage", "paragraph"])
    }

    @MainActor
    func testLocalMP4FixtureExportsVideoVisibleBlock() async throws {
        let snapshot = try await loadStateSnapshot(for: "video_local_mp4.md")

        XCTAssertEqual(snapshot.selectedFile, "video_local_mp4.md")
        XCTAssertEqual(snapshot.visibleBlocks.map(\.kind), ["heading", "paragraph", "video", "paragraph"])
    }

    @MainActor
    private func loadStateSnapshot(for fileName: String) async throws -> HarnessStateSnapshot {
        let fixtureRoot = repoRootURL.appendingPathComponent("Fixtures/docs", isDirectory: true)
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: fixtureRoot,
                openFile: fileName,
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
        try await Task.sleep(nanoseconds: 500_000_000)
        return model.stateSnapshot()
    }
}
