//
//  Swift_Markdown_ViewerTests.swift
//  Swift Markdown ViewerTests
//
//  Created by Matthew Moore on 3/19/26.
//

import XCTest
@testable import Swift_Markdown_Viewer

final class Swift_Markdown_ViewerTests: XCTestCase {

    func testLaunchOptionsParsePlatformAndPaths() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let stateURL = tempRoot.appendingPathComponent("state.json")
        let perfURL = tempRoot.appendingPathComponent("perf.json")

        let options = HarnessLaunchOptions.fromProcess(arguments: [
            "App",
            "--fixture-root", "/tmp/fixtures",
            "--open-file", "basic_typography.md",
            "--platform-target", "ios",
            "--device-class", "ipad",
            "--dump-visible-state", stateURL.path,
            "--dump-perf-state", perfURL.path,
            "--ui-test-mode", "1",
        ])

        XCTAssertEqual(options.fixtureRoot?.path, "/tmp/fixtures")
        XCTAssertEqual(options.openFile, "basic_typography.md")
        XCTAssertEqual(options.platformTarget, .ios)
        XCTAssertEqual(options.deviceClass, .ipad)
        XCTAssertEqual(options.dumpVisibleStateURL?.path, stateURL.path)
        XCTAssertEqual(options.dumpPerfStateURL?.path, perfURL.path)
        XCTAssertTrue(options.uiTestMode)
    }

    func testWorkspaceProviderFallsBackToEmbeddedDocs() throws {
        let provider = LocalWorkspaceProvider(rootURL: URL(fileURLWithPath: "/path/that/does/not/exist"), embeddedDocs: EmbeddedFixtures.docs)
        let workspace = try provider.loadRoot()

        XCTAssertEqual(workspace.rootIdentifier, "Fixtures/docs")
        XCTAssertTrue(workspace.files.contains(where: { $0.path.rawValue == "basic_typography.md" }))
        XCTAssertEqual(try provider.readFile(at: WorkspacePath(rawValue: "basic_typography.md")).contains("Basic typography"), true)
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
        XCTAssertEqual(snapshot.visibleBlocks.first?.text, "# Fixture")
    }
}
