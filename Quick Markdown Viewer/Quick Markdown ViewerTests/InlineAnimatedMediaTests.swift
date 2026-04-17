import XCTest
import Network
@testable import Quick_Markdown_Viewer

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

    func testUnreadableMediaErrorExplainsSandboxEscapeForSiblingFixture() {
        let workspaceRootURL = repoRootURL.appendingPathComponent("Fixtures/docs", isDirectory: true)
        let resolvedURL = repoRootURL.appendingPathComponent("Fixtures/media/rickrolled.gif")
        let message = sandboxEscapeMediaError(
            resolvedURL: resolvedURL,
            sourceURL: "../media/rickrolled.gif",
            kindLabel: "Animated image",
            workspaceRootURL: workspaceRootURL
        )

        #if os(macOS)
        if isAppSandboxEnabled() {
            XCTAssertEqual(
                message,
                """
                Animated image is outside the opened folder and macOS sandbox access is blocked.
                Open the parent folder that contains both the markdown file and the media file.
                source: ../media/rickrolled.gif
                opened root: \(workspaceRootURL.resolvingSymlinksInPath().standardizedFileURL.path)
                resolved: \(resolvedURL.resolvingSymlinksInPath().standardizedFileURL.path)
                """
            )
        } else {
            XCTAssertNil(message)
        }
        #else
        XCTAssertNil(message)
        #endif
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
    func testRemoteAnimatedGIFFixtureExportsAnimatedImageVisibleBlock() async throws {
        let mediaRoot = repoRootURL.appendingPathComponent("Fixtures/media", isDirectory: true)
        let server = try LoopbackHTTPServer(rootDirectory: mediaRoot)
        defer { server.stop() }

        let workspace = try makeWorkspace(named: "Remote Media Workspace", files: [
            "remote_gif.md": """
            # Remote GIF

            Uses a loopback URL.

            ![Remote GIF](\(server.baseURL.appendingPathComponent("rickrolled.gif").absoluteString))

            After the image.
            """
        ])

        let snapshot = try await loadStateSnapshot(for: "remote_gif.md", fixtureRoot: workspace)

        XCTAssertEqual(snapshot.selectedFile, "remote_gif.md")
        XCTAssertEqual(snapshot.visibleBlocks.map(\.kind), ["heading", "paragraph", "animatedImage", "paragraph"])
    }

    @MainActor
    func testRemoteMP4FixtureExportsVideoVisibleBlock() async throws {
        let mediaRoot = repoRootURL.appendingPathComponent("Fixtures/media", isDirectory: true)
        let server = try LoopbackHTTPServer(rootDirectory: mediaRoot)
        defer { server.stop() }

        let workspace = try makeWorkspace(named: "Remote Video Workspace", files: [
            "remote_video.md": """
            # Remote Video

            Uses a loopback URL.

            !video[Remote Video](\(server.baseURL.appendingPathComponent("rickrolled.mp4").absoluteString))

            After the video.
            """
        ])

        let snapshot = try await loadStateSnapshot(for: "remote_video.md", fixtureRoot: workspace)

        XCTAssertEqual(snapshot.selectedFile, "remote_video.md")
        XCTAssertEqual(snapshot.visibleBlocks.map(\.kind), ["heading", "paragraph", "video", "paragraph"])
    }

    @MainActor
    private func loadStateSnapshot(for fileName: String, fixtureRoot: URL? = nil) async throws -> HarnessStateSnapshot {
        let resolvedFixtureRoot = fixtureRoot ?? repoRootURL.appendingPathComponent("Fixtures/docs", isDirectory: true)
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: resolvedFixtureRoot,
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
}

private final class LoopbackHTTPServer {
    let baseURL: URL

    private let listener: NWListener
    private let queue = DispatchQueue(label: "LoopbackHTTPServer")

    init(rootDirectory: URL) throws {
        listener = try NWListener(using: .tcp, on: .any)

        let ready = DispatchSemaphore(value: 0)
        var startupError: Error?

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                ready.signal()
            case .failed(let error):
                startupError = error
                ready.signal()
            default:
                break
            }
        }

        listener.newConnectionHandler = { connection in
            Self.handle(connection, rootDirectory: rootDirectory)
        }

        listener.start(queue: queue)

        guard ready.wait(timeout: .now() + .seconds(5)) == .success else {
            listener.cancel()
            throw NSError(domain: "LoopbackHTTPServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out starting loopback server"])
        }

        if let startupError {
            listener.cancel()
            throw startupError
        }

        guard let port = listener.port?.rawValue else {
            listener.cancel()
            throw NSError(domain: "LoopbackHTTPServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Loopback server did not publish a port"])
        }
        baseURL = URL(string: "http://127.0.0.1:\(port)")!
    }

    func stop() {
        listener.cancel()
    }

    private static func handle(_ connection: NWConnection, rootDirectory: URL) {
        let queue = DispatchQueue(label: "LoopbackHTTPServer.Connection")
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                receiveRequest(on: connection, rootDirectory: rootDirectory)
            }
        }
        connection.start(queue: queue)
    }

    private static func receiveRequest(on connection: NWConnection, rootDirectory: URL) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, _ in
            let response = httpResponse(for: data, rootDirectory: rootDirectory)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private static func httpResponse(for requestData: Data?, rootDirectory: URL) -> Data {
        guard
            let requestData,
            let requestText = String(data: requestData, encoding: .utf8),
            let requestLine = requestText.split(separator: "\r\n").first
        else {
            return response(status: "400 Bad Request", contentType: "text/plain", body: Data("Bad Request".utf8))
        }

        let components = requestLine.split(separator: " ")
        guard components.count >= 2, components[0] == "GET" else {
            return response(status: "405 Method Not Allowed", contentType: "text/plain", body: Data("Method Not Allowed".utf8))
        }

        let requestPath = String(components[1])
        guard let fileURL = resolvedFileURL(for: requestPath, rootDirectory: rootDirectory) else {
            return response(status: "404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8))
        }

        guard let fileData = try? Data(contentsOf: fileURL) else {
            return response(status: "404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8))
        }

        return response(status: "200 OK", contentType: mimeType(for: fileURL), body: fileData)
    }

    private static func resolvedFileURL(for requestPath: String, rootDirectory: URL) -> URL? {
        let pathOnly = requestPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? requestPath
        let decoded = pathOnly.removingPercentEncoding ?? pathOnly
        let components = decoded.split(separator: "/").filter { !$0.isEmpty && $0 != "." }

        guard components.allSatisfy({ $0 != ".." }) else {
            return nil
        }

        return components.reduce(rootDirectory) { partialURL, component in
            partialURL.appendingPathComponent(String(component), isDirectory: false)
        }
    }

    private static func response(status: String, contentType: String, body: Data) -> Data {
        var response = Data("HTTP/1.1 \(status)\r\n".utf8)
        response.append(Data("Content-Type: \(contentType)\r\n".utf8))
        response.append(Data("Content-Length: \(body.count)\r\n".utf8))
        response.append(Data("Connection: close\r\n\r\n".utf8))
        response.append(body)
        return response
    }

    private static func mimeType(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "gif":
            return "image/gif"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "webp":
            return "image/webp"
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        default:
            return "application/octet-stream"
        }
    }
}
