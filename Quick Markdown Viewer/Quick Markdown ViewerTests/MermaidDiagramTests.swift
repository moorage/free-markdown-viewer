import CoreGraphics
import XCTest
@testable import Quick_Markdown_Viewer

final class MermaidDiagramTests: XCTestCase {
    private var repoRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @MainActor
    private static var retainedModels: [AppModel] = []

    @MainActor
    private func retainForTestLifetime(_ model: AppModel) {
        Self.retainedModels.append(model)
    }

    func testEveryOfficialMermaidDeclarationHasNativeCompatibilityStatus() {
        let samples: [(MermaidDiagramKind, String)] = [
            (.flowchart, "flowchart LR\n  A[Start] --> B{Done?}"),
            (.sequenceDiagram, "sequenceDiagram\n  participant A\n  A->>B: Hello"),
            (.classDiagram, "classDiagram\n  Animal <|-- Duck\n  Animal : +String name"),
            (.stateDiagram, "stateDiagram-v2\n  [*] --> Still\n  Still --> [*]"),
            (.erDiagram, "erDiagram\n  CUSTOMER ||--o{ ORDER : places"),
            (.journey, "journey\n  section Shop\n  Browse: 5: User"),
            (.gantt, "gantt\n  dateFormat YYYY-MM-DD\n  section Build\n  Parser: 2026-05-22, 1d"),
            (.pie, "pie showData\n  \"Flowchart\" : 42\n  \"Sequence\" : 28"),
            (.quadrantChart, "quadrantChart\n  x-axis Low --> High\n  Item: [0.3, 0.7]"),
            (.requirementDiagram, "requirementDiagram\n  requirement test_req { id: 1 text: native risk: low verifymethod: test }"),
            (.gitGraph, "gitGraph\n  commit\n  branch feature\n  checkout feature\n  commit"),
            (.c4, "C4Context\n  Person(user, \"User\")\n  System(app, \"App\")\n  Rel(user, app, \"Uses\")"),
            (.mindmap, "mindmap\n  root((Mermaid))\n    Native\n    Swift"),
            (.timeline, "timeline\n  title Releases\n  2026 : Mermaid diagrams"),
            (.zenuml, "zenuml\n  A->B: request\n  B-->A: response"),
            (.sankey, "sankey-beta\n  Source,Target,10"),
            (.xyChart, "xychart-beta\n  x-axis [a, b]\n  y-axis 0 --> 10\n  bar [2, 7]"),
            (.block, "block-beta\n  columns 2\n  A B\n  A-->B"),
            (.packet, "packet-beta\n  0-15: Source Port\n  16-31: Destination Port"),
            (.kanban, "kanban\n  Todo\n    Native renderer"),
            (.architecture, "architecture-beta\n  service api(server)[API]\n  service db(database)[DB]\n  api:R -- L:db"),
            (.radar, "radar-beta\n  axis Native\n  axis Coverage\n  curve App{5,4}"),
            (.eventModeling, "eventModeling\n  timeframe 1\n  command \"Open\""),
            (.treemap, "treemap-beta\n  Root\n    Child: 10"),
            (.venn, "venn\n  A [10]\n  B [5]\n  A&B [2]"),
            (.ishikawa, "ishikawa\n  Problem\n    Cause\n      Detail"),
            (.wardley, "wardley\n  title Map\n  component User [0.9, 0.2]"),
            (.treeView, "treeview\n  Root\n    Child"),
            (.info, "info")
        ]

        XCTAssertEqual(Set(samples.map { $0.0 }), Set(MermaidDiagramKind.allCases))

        for (expectedKind, source) in samples {
            let diagram = MermaidCompiler.compile(source: source, context: .inline)
            XCTAssertEqual(diagram.kind, expectedKind, "Expected \(expectedKind.rawValue) for source:\n\(source)")
            XCTAssertFalse(diagram.kind.displayName.isEmpty)
            XCTAssertFalse(diagram.kind.supportStatus.summary.isEmpty)
            XCTAssertFalse(diagram.scene.title == nil && diagram.scene.nodes.isEmpty && diagram.scene.edges.isEmpty && diagram.scene.sections.isEmpty && diagram.scene.metrics.isEmpty)
        }
    }

    func testMarkdownRendererTurnsInlineMermaidFenceIntoDiagramBlock() throws {
        let blocks = MarkdownRenderer.blocks(from: """
        # Diagram

        ```mermaid
        flowchart LR
          accTitle: Purchase Flow
          Cart[Cart] --> Checkout[Checkout]
        ```
        """)

        XCTAssertEqual(blocks.map(\.kind), [.heading, .mermaidDiagram])
        let diagram = try XCTUnwrap(blocks.last?.mermaidDiagram)
        XCTAssertEqual(diagram.kind, .flowchart)
        XCTAssertEqual(diagram.accessibilityTitle, "Purchase Flow")
        XCTAssertEqual(diagram.scene.edges.count, 1)
    }

    func testUntitledMermaidDiagramPresentationTitleUsesGenericChromeTitle() throws {
        let diagram = MermaidCompiler.compile(
            source: """
            graph LR
              A[Start] --> B[Done]
            """,
            context: .inline
        )

        XCTAssertEqual(diagram.displayTitle, "Flowchart")
        XCTAssertEqual(diagram.presentationTitle, "Mermaid Diagram")
        XCTAssertEqual(diagram.kind.displayName, "Flowchart")
    }

    func testAuthoredMermaidDiagramPresentationTitleUsesAuthorTitle() throws {
        let diagram = MermaidCompiler.compile(
            source: """
            sequenceDiagram
              accTitle: Checkout callbacks
              participant App
              participant Gateway
              App->>Gateway: Capture
            """,
            context: .inline
        )

        XCTAssertEqual(diagram.displayTitle, "Checkout callbacks")
        XCTAssertEqual(diagram.presentationTitle, "Checkout callbacks")
        XCTAssertEqual(diagram.kind.displayName, "Sequence Diagram")
    }

    func testFlowchartDirectionAndNodeOrderArePreservedForNativeLayout() throws {
        let diagram = MermaidCompiler.compile(
            source: """
            graph LR
              A[Patient WhatsApp inbound]
              B[Webhook parse and receipt]
              C[Identity and contact state]
              D[Buffered patient reply]
              A --> B
              B --> C
              C --> D
            """,
            context: .inline
        )

        XCTAssertEqual(diagram.scene.direction, .leftRight)
        XCTAssertEqual(
            diagram.scene.nodes.map(\.label),
            [
                "Patient WhatsApp inbound",
                "Webhook parse and receipt",
                "Identity and contact state",
                "Buffered patient reply"
            ]
        )
        XCTAssertEqual(diagram.scene.edges.map(\.sourceID), ["a", "b", "c"])
        XCTAssertEqual(diagram.scene.edges.map(\.targetID), ["b", "c", "d"])
    }

    func testMermaidPreviewFitScaleAllowsWideLifecycleGraphsToFit() {
        let lifecycleCanvas = CGSize(width: 3_634, height: 560)
        let previewViewport = CGSize(width: 920, height: 560)

        let fitScale = MermaidPreviewZoom.fitScale(
            canvasSize: lifecycleCanvas,
            viewportSize: previewViewport
        )

        XCTAssertLessThan(fitScale, 0.35)
        XCTAssertGreaterThanOrEqual(fitScale, MermaidPreviewZoom.minimum)
        XCTAssertEqual(fitScale, previewViewport.width / lifecycleCanvas.width, accuracy: 0.001)
    }

    func testDetachedMermaidPreviewPresentationAllowsViewportExpansion() {
        XCTAssertEqual(MermaidPreviewPresentation.constrainedSheet.maximumViewportWidth, 980)
        XCTAssertEqual(MermaidPreviewPresentation.constrainedSheet.maximumViewportHeight, 760)
        XCTAssertTrue(MermaidPreviewPresentation.detachedWindow.maximumViewportWidth.isInfinite)
        XCTAssertTrue(MermaidPreviewPresentation.detachedWindow.maximumViewportHeight.isInfinite)
    }

    func testWebOnlyMermaidFeaturesProduceSafeDiagnostics() throws {
        let diagram = MermaidCompiler.compile(
            source: """
            %%{init: {"themeCSS": ".node{display:none}", "htmlLabels": true}}%%
            flowchart TD
              A[<b>HTML label</b>] --> B[Safe]
              click A callback "unsafe"
            """,
            context: .inline
        )

        XCTAssertEqual(diagram.kind, .flowchart)
        XCTAssertTrue(diagram.diagnostics.contains { $0.message.contains("web-only") || $0.message.contains("HTML/CSS") })
        XCTAssertTrue(diagram.diagnostics.contains { $0.message.contains("JavaScript callback") })
        XCTAssertTrue(diagram.scene.nodes.contains { $0.label.contains("HTML label") })
    }

    func testLocalWorkspaceIncludesStandaloneMermaidFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "flowchart LR\n  A-->B".write(to: root.appendingPathComponent("diagram.mmd"), atomically: true, encoding: .utf8)
        try "sequenceDiagram\n  A->>B: hi".write(to: root.appendingPathComponent("sequence.mermaid"), atomically: true, encoding: .utf8)
        try "# Notes".write(to: root.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)

        let workspace = try LocalWorkspaceProvider(rootURL: root, embeddedDocs: EmbeddedFixtures.docs).loadRoot()

        XCTAssertEqual(workspace.files.map(\.path.rawValue), ["diagram.mmd", "notes.md", "sequence.mermaid"])
        XCTAssertEqual(workspace.files.map(\.kind), [.mermaid, .markdown, .mermaid])
    }

    @MainActor
    func testAppModelOpensStandaloneMermaidFileAsStructuredDiagram() async throws {
        let model = AppModel(
            launchOptions: HarnessLaunchOptions(
                fixtureRoot: repoRootURL.appendingPathComponent("Fixtures/docs", isDirectory: true),
                openFile: "mermaid/flowchart_basic.mmd",
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
        retainForTestLifetime(model)
        model.bootstrap()

        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(model.selectedDocumentKind, .mermaid)
        XCTAssertTrue(model.shouldRenderBlockContent)
        XCTAssertEqual(model.stateSnapshot().visibleBlocks.map(\.kind), ["mermaidDiagram"])
        XCTAssertEqual(model.documentBlocks.first?.mermaidDiagram?.kind, .flowchart)
    }

    func testMermaidPlainTextPrintSummaryPreservesSourceContext() throws {
        let block = MermaidMarkdownBlockCatalog.standaloneBlock(
            from: "pie showData\n  \"Native\" : 10",
            path: WorkspacePath(rawValue: "chart.mmd")
        )

        let rendered = DocumentPlainTextRenderer.render(blocks: [block])

        XCTAssertTrue(rendered.contains("Mermaid Diagram"))
        XCTAssertTrue(rendered.contains("Pie Chart"))
        XCTAssertTrue(rendered.contains("chart.mmd"))
    }

    func testMermaidFixtureScenesMatchExpectedSnapshots() throws {
        let expectedRoot = repoRootURL.appendingPathComponent("Fixtures/expected/mermaid-scenes", isDirectory: true)
        let expectedURLs = try FileManager.default.contentsOfDirectory(
            at: expectedRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(expectedURLs.isEmpty, "Mermaid scene expectations must be checked in.")

        for expectedURL in expectedURLs where expectedURL.pathExtension == "json" {
            let expected = try JSONDecoder().decode(MermaidSceneSnapshot.self, from: Data(contentsOf: expectedURL))
            let sourceURL = repoRootURL
                .appendingPathComponent("Fixtures/docs", isDirectory: true)
                .appendingPathComponent(expected.sourceFile)
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            let diagram = MermaidCompiler.compile(
                source: source,
                context: .file(WorkspacePath(rawValue: expected.sourceFile))
            )

            XCTAssertEqual(MermaidSceneSnapshot(sourceFile: expected.sourceFile, diagram: diagram), expected)
        }
    }

    func testExpectedMermaidVisualGoldensArePresentAndStructured() throws {
        let cases: [(checkpoint: String, selectedFile: String, blockCount: Int)] = [
            ("mermaid-inline-macos", "mermaid_inline_showcase.md", 4),
            ("mermaid-flowchart-macos", "mermaid/flowchart_basic.mmd", 1),
            ("mermaid-sequence-macos", "mermaid/sequence_basic.mermaid", 1),
        ]
        let expectedRoot = repoRootURL.appendingPathComponent("Fixtures/expected", isDirectory: true)
        let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

        for testCase in cases {
            let checkpointURL = expectedRoot.appendingPathComponent(testCase.checkpoint, isDirectory: true)
            let stateURL = checkpointURL.appendingPathComponent("state.json")
            let perfURL = checkpointURL.appendingPathComponent("perf.json")
            let windowURL = checkpointURL.appendingPathComponent("window.png")

            let state = try JSONDecoder().decode(ExpectedHarnessStateSnapshot.self, from: Data(contentsOf: stateURL))
            let perf = try JSONDecoder().decode(ExpectedHarnessPerformanceSnapshot.self, from: Data(contentsOf: perfURL))
            let pngData = try Data(contentsOf: windowURL)

            XCTAssertEqual(state.selectedFile, testCase.selectedFile)
            XCTAssertEqual(state.visibleBlocks.count, testCase.blockCount)
            XCTAssertTrue(state.visibleBlocks.contains { $0.kind == "mermaidDiagram" })
            XCTAssertEqual(perf.visibleBlockCount, testCase.blockCount)
            XCTAssertEqual(Array(pngData.prefix(pngSignature.count)), pngSignature)
            XCTAssertGreaterThan(pngData.count, 1_000)
        }
    }

    private struct MermaidSceneSnapshot: Codable, Equatable {
        let sourceFile: String
        let displayTitle: String
        let kind: MermaidDiagramKind
        let supportStatus: MermaidSupportStatus
        let accessibilityTitle: String?
        let accessibilityDescription: String?
        let diagnosticMessages: [String]
        let scene: MermaidScene

        init(sourceFile: String, diagram: MarkdownMermaidDiagram) {
            self.sourceFile = sourceFile
            displayTitle = diagram.displayTitle
            kind = diagram.kind
            supportStatus = diagram.kind.supportStatus
            accessibilityTitle = diagram.accessibilityTitle
            accessibilityDescription = diagram.accessibilityDescription
            diagnosticMessages = diagram.diagnostics.map(\.message)
            scene = diagram.scene
        }
    }

    private struct ExpectedHarnessStateSnapshot: Decodable {
        let selectedFile: String?
        let visibleBlocks: [ExpectedVisibleBlockSnapshot]
    }

    private struct ExpectedVisibleBlockSnapshot: Decodable {
        let kind: String
    }

    private struct ExpectedHarnessPerformanceSnapshot: Decodable {
        let visibleBlockCount: Int
    }
}
