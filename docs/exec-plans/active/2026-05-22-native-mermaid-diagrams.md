# Native Mermaid Diagram Rendering

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Quick Markdown Viewer should render Mermaid diagrams natively on macOS, iPhone, and iPad. Inline fenced blocks using `mermaid` should appear as polished diagram cards in Markdown, and standalone `.mermaid` / `.mmd` files should open as first-class workspace documents. Clicking an inline diagram should open the same preview presentation path used for video/media previews, with a zoomable and pannable native diagram viewport.

The implementation must stay native Swift. The app must not embed Mermaid.js, run JavaScript, use `WKWebView`, render author HTML/CSS, call a remote diagram service, or shell out to a renderer. Mermaid syntax should be compiled into a typed Swift model, laid out with native layout engines, and rendered with SwiftUI/CoreGraphics/AppKit/UIKit primitives.

The target is Mermaid OSS syntax as documented by the official Mermaid 11.15.0 docs at plan creation time, plus common Markdown ecosystem conventions such as GitHub-style fenced `mermaid` blocks and `.mermaid` / `.mmd` standalone files. Because Mermaid includes experimental and beta diagram types whose syntax may change, this plan treats support as a compatibility matrix with explicit status, tests, and diagnostics rather than an untracked best-effort parser.

## Progress

- [x] (2026-05-22T05:39Z) Read the repo control-plane docs, adjacent media/code-block ExecPlans, current Markdown/media renderer seams, and official Mermaid/GitHub documentation before drafting this plan.
- [x] (2026-05-22T05:39Z) Created this active ExecPlan for native Mermaid inline and standalone-file rendering; implementation has not started.
- [x] (2026-05-22T06:11Z) Began implementation. Reconfirmed that the project uses Xcode file-system-synchronized source groups, so new Swift/test files can be added on disk without manual `project.pbxproj` source-phase edits.
- [x] (2026-05-22T06:26Z) Added the first native Mermaid compiler/model layer, inline fence conversion, standalone `.mermaid` / `.mmd` document discovery, native SwiftUI diagram cards/previews, fixtures, accessibility IDs, and focused unit tests. The targeted `MermaidDiagramTests` slice passes.
- [x] (2026-05-22T06:33Z) Validated the implementation with `./scripts/build --platform all` and `./scripts/test-unit`; both passed. Focused Mermaid UI tests compile, but local macOS UI automation timed out while enabling automation mode before running assertions.
- [x] (2026-05-22T06:34Z) Re-ran `python3 scripts/check_execplan.py` and `python3 scripts/knowledge/check_docs.py` after documentation updates; both passed.
- [x] (2026-05-22T06:38Z) Attempted a separate `./scripts/test-integration` run. It stalled after the build phase with no test output for several minutes and was interrupted; the same integration test had already passed inside `./scripts/test-unit`.
- [x] (2026-05-22T15:05Z) Re-ran Mermaid validation after macOS XCTest permission changes. Focused `MermaidDiagramTests`, `./scripts/test-unit`, and `./scripts/build --platform all` passed. Harness checkpoints for inline and standalone Mermaid files captured valid `mermaidDiagram` state and screenshots. Direct app interaction confirmed inline card click opens `mermaid-preview.*` controls, zoom works, drag-pan works, Fit recenters, and Close dismisses the preview. The focused macOS UI test runner now launches but wedges before reporting test cases.
- [x] (2026-05-22T16:34Z) Unblocked macOS UI XCTest by running focused UI tests with signing enabled (`DEVELOPMENT_TEAM=GG34PA8F4A`) instead of `CODE_SIGNING_ALLOWED=NO`, and by exposing print status probes as stable accessibility elements. Focused print UI XCTest and focused Mermaid UI XCTest both pass.
- [x] (2026-05-23T02:34Z) Added Mermaid fixture scene snapshot unit coverage, checked-in visual checkpoint goldens for inline Markdown Mermaid plus standalone flowchart and sequence files, and a unit guard that the expected Mermaid visual outputs stay present and structured. The new scene snapshot test caught and fixed a sequence parser bug where `-->>` was matched as `->>`. Focused `MermaidDiagramTests`, `./scripts/test-unit`, and exact `./scripts/compare-goldens` runs for `mermaid-inline-macos`, `mermaid-flowchart-macos`, and `mermaid-sequence-macos` pass.
- [x] (2026-05-23T02:54Z) Hid the normal Mermaid compatibility/status pill from diagram cards so labels like "Native common syntax" do not appear as visual content. Refreshed the three checked-in macOS visual goldens. Focused `MermaidDiagramTests`, `./scripts/test-unit`, and exact `./scripts/compare-goldens` runs for `mermaid-inline-macos`, `mermaid-flowchart-macos`, and `mermaid-sequence-macos` pass.
- [x] (2026-05-23T03:20Z) Reworked native graph layout to preserve Mermaid graph direction (`TD`/`TB`/`BT`/`LR`/`RL`), source-order node insertion, rank-based placement, clipped-but-scrollable diagram canvases, and edge endpoints trimmed to node boundaries. Verified the `tmp/2026-05-21-patient-case-database-schema-review.md` lifecycle graph no longer wraps into overlapping rows. Focused `MermaidDiagramTests`, `./scripts/test-unit`, `./scripts/build --platform all`, and exact `./scripts/compare-goldens` runs for `mermaid-inline-macos`, `mermaid-flowchart-macos`, and `mermaid-sequence-macos` pass.
- [x] (2026-05-24T21:21Z) Split Mermaid preview rendering from embedded-card scrolling so preview mode owns one zoomable/scrollable canvas instead of nesting a graph viewport inside the preview viewport. Added a macOS-only "Open in Window" action that promotes the preview into a normal resizable/full-screen-capable `NSWindow`, stabilized macOS harness screenshot title/focus setup, refreshed Mermaid visual goldens, and verified the patient-case flowchart preview by direct app interaction. Focused `MermaidDiagramTests`, signed focused `MermaidDiagramUITests.testInlineMermaidDiagramOpensZoomablePreview`, `./scripts/test-unit`, `./scripts/build --platform all`, and exact `./scripts/compare-goldens` runs for `mermaid-inline-macos`, `mermaid-flowchart-macos`, and `mermaid-sequence-macos` pass.
- [x] (2026-05-24T22:10Z) Fixed Mermaid preview Fit for the `tmp/2026-05-21-patient-case-database-schema-review.md` Lifecycle Overview by lowering the preview zoom floor below the wide `graph LR` fit scale, making preview graph paper full-bleed, and removing the scaled inner canvas background in preview mode. Direct app verification shows the Lifecycle Overview fits into the preview and the graph-paper viewport no longer leaves a gray moat. Focused `MermaidDiagramTests`, signed focused `MermaidDiagramUITests.testInlineMermaidDiagramOpensZoomablePreview`, `./scripts/test-unit`, `./scripts/build --platform macos`, and exact `./scripts/compare-goldens` for the Mermaid macOS checkpoints pass.
- [x] (2026-05-25T02:57Z) Changed untitled Mermaid diagram chrome to display `Mermaid Diagram` as the card, preview, and detached-window title while keeping the detected diagram kind such as `Flowchart` as the subtitle. Authored titles from frontmatter or `accTitle` still win. Direct app verification against `tmp/2026-05-21-patient-case-database-schema-review.md` confirms the inline block, preview sheet, and detached macOS window now show `Mermaid Diagram` / `Flowchart`. Focused `MermaidDiagramTests`, signed focused `MermaidDiagramUITests.testInlineMermaidDiagramOpensZoomablePreview`, `./scripts/build --platform macos`, `./scripts/test-unit`, and exact Mermaid macOS visual-golden comparisons pass.
- [x] (2026-05-25T03:09Z) Removed the sheet-sized max-width/max-height cap from detached Mermaid preview windows so full-screen and manually resized detached windows expand the zoomable graph-paper viewport to fill the window. Direct app verification against `tmp/2026-05-21-patient-case-database-schema-review.md` shows the detached Mermaid window entering full screen with the viewport full-width/full-height instead of remaining capped. Focused `MermaidDiagramTests`, signed focused `MermaidDiagramUITests.testInlineMermaidDiagramOpensZoomablePreview`, `./scripts/test-unit`, and exact Mermaid macOS visual-golden comparisons pass.

## Surprises & Discoveries

- Observation: Mermaid's current official surface is much larger than the older core diagram set and now includes new/beta diagrams such as architecture, radar, event modeling, treemap, Venn, Ishikawa, and Wardley.
  Evidence: the official Mermaid 11.15.0 sidebar and config schema list flowchart, sequence, class, state, ER, journey, Gantt, pie, quadrant, requirement, gitgraph, C4, mindmap, timeline, ZenUML, sankey, XY, block, packet, kanban, architecture, radar, eventmodeling, treemap, Venn, Ishikawa, Wardley, and TreeView-related config.

- Observation: GitHub treats Mermaid as both an inline Markdown fenced-code feature and a standalone non-code file type.
  Evidence: GitHub Docs require a fenced code block with language identifier `mermaid`, and the GitHub changelog lists `.mermaid` and `.mmd` as supported Mermaid file extensions.

- Observation: the live app already has the right high-level seams for this feature but no Mermaid model.
  Evidence: `WorkspaceDocumentKind` currently supports only Markdown, CSV, and TSV; fenced `mermaid` blocks currently flow through `MarkdownBlockKind.codeBlock`; `shouldRenderStructuredContent(for:)` already routes code/media/table blocks into SwiftUI block rendering; media preview presentation already lives in `ViewerShellView`.

- Observation: the repo's native-rendering invariant conflicts with the easiest Mermaid implementation path.
  Evidence: the repo forbids `WKWebView` and HTML/CSS/JavaScript renderers, while official Mermaid is a JavaScript-based renderer. This means compatibility must be implemented as native Swift parsing, layout, and drawing rather than by embedding the upstream renderer.

- Observation: Mermaid supports author-controlled configuration, themes, icon packs, links, callbacks, HTML labels, and math, but not all of those are safe or native.
  Evidence: official docs cover frontmatter/directives, theme variables, layouts, registered icon packs, accessibility metadata, and KaTeX-backed math; these need native equivalents, safe fallbacks, or explicit diagnostics.

- Observation: the local macOS UI test runner can fail before app assertions execute.
  Evidence: `Quick Markdown ViewerUITests-Runner` twice failed with `The test runner failed to initialize for UI testing. (Underlying Error: Timed out while enabling automation mode.)` when running the focused Mermaid UI tests.

- Observation: a standalone integration wrapper invocation can stall even when the covered test passes under the unit-suite wrapper.
  Evidence: `./scripts/test-integration` remained running after its build phase without test output for several minutes and had to be interrupted, while `testIntegrationWorkspaceLoadsFixtureAndSnapshot` passed during `./scripts/test-unit`.

- Observation: macOS UI XCTest progressed past the previous automation-mode timeout, but still wedges before executing Mermaid UI test assertions.
  Evidence: the focused Mermaid UI retake launched `Quick Markdown ViewerUITests-Runner`, then produced no XCTest case output for several minutes and had to be interrupted. Direct app and harness validation exercised the same Mermaid preview path successfully.

- Observation: macOS UI XCTest was not fundamentally blocked; the broken runner was caused by disabling code signing for a UI-test runner that must be re-signed after Xcode copies XCTest resources.
  Evidence: the `CODE_SIGNING_ALLOWED=NO` UI-test command produced a "Quick Markdown ViewerUITests-Runner.app is damaged" Gatekeeper dialog and `spctl` reported `code has no resources but signature indicates they must be present`. Re-running with `DEVELOPMENT_TEAM=GG34PA8F4A` let the runner launch and execute focused print and Mermaid UI tests.

- Observation: the first deterministic Mermaid scene snapshot exposed a real sequence-arrow parser bug.
  Evidence: `MermaidDiagramTests.testMermaidFixtureScenesMatchExpectedSnapshots` expected `App-->>User` to render as a dotted return edge, but the parser matched the inner `->>` substring first and produced a solid edge. The parser now chooses the earliest operator in the source line and prefers the longer operator on ties.

- Observation: Mermaid flowchart direction is an orientation/rank choice, not a viewport-wrapping instruction.
  Evidence: the official Mermaid flowchart syntax page defines directions such as `TD`/`TB` for top-to-bottom and `LR` for left-to-right, and separately mentions automatic wrapping only for Markdown text labels. The native renderer now expands the diagram canvas for directed graph ranks instead of wrapping nodes into viewport-sized rows.

- Observation: putting the scrollable graph surface inside the preview zoom/pan wrapper creates a nested viewport that looks like a small diagram window inside the preview.
  Evidence: the patient-case preview screenshot showed the graph clipped inside a smaller blue-grid rectangle. The preview now uses `graphViewportMode: .canvasOnly` and wraps the scaled canvas in the preview's single scroll view, while embedded cards retain their own scrollable viewport.

- Observation: wide `graph LR` diagrams can require a fit scale below `0.35`.
  Evidence: the Lifecycle Overview graph spans many left-to-right ranks, so its canvas-to-preview width ratio is roughly a quarter of the preview width. The old `0.35` minimum prevented Fit from zooming out enough to show the whole diagram.

- Observation: drawing graph paper only inside the zoomed canvas leaves a gray preview area when Fit shrinks the canvas below viewport size.
  Evidence: the Lifecycle Overview preview showed a smaller blue graph-paper rectangle surrounded by the preview material after Fit. The preview now owns the full-bleed graph-paper background, and preview graph content renders transparently over it.

- Observation: `graph` is Mermaid's older flowchart declaration, but using the detected kind as the title makes untitled diagrams look as if the app renamed the user's diagram.
  Evidence: the patient-case Lifecycle Overview begins with `graph LR`, so the compiler correctly detects the kind as `Flowchart`; the visible chrome now uses `Mermaid Diagram` for untitled diagrams and reserves `Flowchart` for the subtitle.

- Observation: detached Mermaid preview windows inherited the sheet preview's `980x760` viewport cap.
  Evidence: a detached macOS window could enter full screen while the actual Mermaid graph-paper viewport stayed at the sheet-sized maximum with unused surrounding space. The preview now uses explicit sheet vs detached-window presentation sizing.

## Decision Log

- Decision: implement a native Swift Mermaid compiler and renderer instead of embedding Mermaid.js or rendering SVG/HTML output from a JavaScript runtime.
  Rationale: this preserves the repo invariants, keeps the app local-first, and avoids shipping a web renderer inside a native Markdown viewer.
  Date/Author: 2026-05-22 / Codex

- Decision: define the compatibility target as Mermaid OSS 11.15.0 docs plus GitHub-style Markdown integration, with beta/new diagrams tracked explicitly in the support matrix.
  Rationale: Mermaid evolves quickly and some diagrams are documented as experimental or beta; a versioned support matrix prevents invisible drift.
  Date/Author: 2026-05-22 / Codex

- Decision: accept all official diagram declarations through a central `MermaidDiagramKind` detector, even before every renderer reaches full fidelity.
  Rationale: users should get a clear native diagnostic and preserved source text for unsupported or partially supported syntax, not an ordinary code block that looks like the app missed the diagram entirely.
  Date/Author: 2026-05-22 / Codex

- Decision: map unsafe or web-only features to safe native behavior.
  Rationale: `themeCSS`, HTML labels, JavaScript callbacks, remote icon-pack loading, and KaTeX/CSS rendering cannot be implemented literally without violating the app's security and native-rendering constraints.
  Date/Author: 2026-05-22 / Codex

- Decision: reuse the existing media preview presentation pattern for inline diagram expansion while adding a diagram-specific zoom/pan viewport.
  Rationale: the user explicitly asked for a popover like videos; the existing media preview path already centralizes platform presentation, close behavior, and harness identifiers.
  Date/Author: 2026-05-22 / Codex

- Decision: implement the first shippable native pass as broad parsed support with polished generic renderers per diagram family, plus source-preserving diagnostics for unsupported Mermaid corner cases, rather than attempting a line-for-line native clone of Mermaid.js in one change.
  Rationale: Mermaid's full JavaScript renderer includes many independent DSLs and web-only features. A native Swift app can safely support the complete declaration surface and common syntax patterns now, while tests record partial/beta support where native fidelity intentionally differs.
  Date/Author: 2026-05-22 / Codex

- Decision: keep support-status labels such as "Native common syntax" out of normal Mermaid diagram card chrome.
  Rationale: the label describes internal compatibility coverage, not user document content. Diagnostics and compiler metadata still preserve support state where it is useful for unsupported or partial syntax.
  Date/Author: 2026-05-23 / Codex

- Decision: make Mermaid graph cards use a direction-aware ranked canvas rather than a fixed viewport grid.
  Rationale: `graph LR` and `graph TD` describe graph orientation. If the graph is wider or taller than the card, the canvas should grow and scroll inside the existing viewport so node placement and edge paths remain readable.
  Date/Author: 2026-05-23 / Codex

- Decision: separate embedded Mermaid graph scrolling from preview canvas ownership, and implement macOS preview breakout as a detached `NSWindow`.
  Rationale: the inline card still needs an embedded viewport, but preview mode should have exactly one viewport controlling the whole canvas. A detached AppKit window gives macOS users resize, close, minimize, and full-screen behavior without contorting the sheet/popover presentation itself.
  Date/Author: 2026-05-24 / Codex

- Decision: lower the Mermaid preview zoom floor to `0.12` and centralize preview zoom math in `MermaidPreviewZoom`.
  Rationale: Fit must be able to show very wide directed graphs in one viewport, while shared clamping keeps button, gesture, and Fit behavior consistent and testable.
  Date/Author: 2026-05-24 / Codex

- Decision: make the Mermaid preview viewport own the graph-paper background, with graph canvases optionally rendering without their own background in preview mode.
  Rationale: graph paper should remain full-bleed even when zoomed-out graph content is smaller than the viewport; embedded cards still render their own scrollable canvas background.
  Date/Author: 2026-05-24 / Codex

- Decision: add a UI-specific Mermaid `presentationTitle` instead of changing the model `displayTitle`.
  Rationale: parser snapshots and plain-text summaries still benefit from a deterministic detected-kind fallback, while visible card/preview/window chrome should distinguish the generic Mermaid container from the specific diagram kind.
  Date/Author: 2026-05-24 / Codex

- Decision: keep Mermaid sheets constrained but let detached Mermaid windows expand without a preview max-size cap.
  Rationale: sheets need predictable modal sizing, while detached macOS windows should behave like normal resizable/full-screen document windows and let the single zoomable canvas fill the available view.
  Date/Author: 2026-05-25 / Codex

## Outcomes & Retrospective

This plan is the current outcome. No code, fixtures, tests, or harness contracts have been changed yet. The implementation should begin with fixtures and red coverage because this feature spans parsing, file discovery, rendering, preview interaction, accessibility, printing, and platform-specific gestures.

The main risk is scope. "Full Mermaid" is not one renderer; it is a family of DSLs, layout engines, charts, and configuration behavior. The plan handles that by building a shared compiler/rendering substrate first, then implementing diagram families in layers with explicit acceptance tests.

Implementation has landed a broad native compatibility substrate rather than a Mermaid.js-equivalent renderer. Every official Mermaid 11.15.0 diagram declaration maps to `MermaidDiagramKind`, inline/file integration works, and the renderer produces polished native cards with diagnostics for unsafe/web-only or beta/partial syntax. Exact Mermaid.js layout parity for every corner case remains intentionally out of scope for this native-only pass.

Validation evidence is green for compilation, unit-level behavior, native rendering state, direct preview interaction, focused macOS UI behavior, and checked-in visual checkpoints: `./scripts/build --platform all` passed for macOS and iOS/iPad simulator builds after the single-viewport preview change, `./scripts/build --platform macos` passed after the full-bleed Fit and title-chrome corrections, `./scripts/test-unit` passed, the focused `MermaidDiagramTests` slice passed, signed focused `MermaidDiagramUITests.testInlineMermaidDiagramOpensZoomablePreview` passed after the preview title and detached-window sizing changes, and exact `./scripts/compare-goldens` runs pass for `mermaid-inline-macos`, `mermaid-flowchart-macos`, and `mermaid-sequence-macos` after refreshing expected output. Retest evidence also includes macOS harness checkpoints for inline and standalone Mermaid files plus direct app interaction verifying preview open, zoom, Fit, Close, a single scrollable preview canvas, macOS detached preview window behavior, detached full-screen viewport expansion, the patient-case Lifecycle Overview fitting into a full-bleed graph-paper preview, and untitled Mermaid chrome showing `Mermaid Diagram` with the detected kind as subtitle.

## Context and Orientation

Relevant existing files:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/SyntaxHighlighting/CodeBlockSyntaxHighlighting.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/GitHubWorkspace.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`
- `Fixtures/docs/`
- `Fixtures/expected/`
- `docs/debug-contracts.md`

Expected new implementation area:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Mermaid/`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/MermaidDiagramView.swift` or a nearby shell view file
- `Quick Markdown Viewer/Quick Markdown ViewerTests/MermaidDiagramTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/MermaidDiagramUITests.swift`
- `Fixtures/docs/mermaid_inline_showcase.md`
- `Fixtures/docs/mermaid/` for one fixture per supported diagram family
- `Fixtures/expected/mermaid/` for parser/layout/rendering expectations

Current live seams:

- `WorkspaceDocumentKind.forPath(_:)` and `SupportedDocumentExtensions` must learn `.mermaid` and `.mmd`.
- `MarkdownRenderer.blocks(from:)` currently annotates fenced code blocks after parsing; Mermaid block detection should happen at or near this existing fenced-code catalog step so syntax highlighting does not claim Mermaid blocks.
- `MarkdownBlockKind` needs a new `mermaidDiagram` case and a `MarkdownMermaidDiagram` payload.
- `AppModel.blocks(for:kind:)` needs a Mermaid-file path that produces one diagram block from the whole file.
- `ViewerShellView` already has sheet/popover bindings for media preview and structured block rendering for images/videos; Mermaid should reuse that presentation pattern but render with a diagram-specific zoom/pan viewport.
- `docs/debug-contracts.md` must gain stable IDs such as `block.mermaid.<id>`, `mermaid-preview.container`, `mermaid-preview.zoomIn`, `mermaid-preview.zoomOut`, `mermaid-preview.fit`, and `mermaid-preview.reset`.

## Plan of Work

### Milestone 1: compatibility matrix, fixtures, and red tests

Create a repo-owned Mermaid support matrix inside this plan or a new durable doc if it becomes too large. Add deterministic fixtures for inline Mermaid fences, standalone `.mermaid` and `.mmd` files, malformed diagrams, large diagrams, frontmatter/directives, and representative official examples for every documented diagram type. Add red unit and UI tests that freeze file discovery, inline block classification, preview presentation, zoom/pan controls, print behavior, accessibility metadata, and fallback diagnostics.

### Milestone 2: native Mermaid document model and parser substrate

Add `MarkdownBlockKind.mermaidDiagram`, `MarkdownMermaidDiagram`, `MermaidDiagramKind`, `MermaidParseResult`, `MermaidDiagnostic`, and a small shared compiler entry point such as `MermaidCompiler.compile(source:context:)`. The first compiler layer should normalize line endings, strip Mermaid frontmatter, parse `%%` comments, parse `accTitle` / `accDescr`, apply safe config/directive settings, detect diagram kind, and preserve source text for fallback.

### Milestone 3: graph-family native rendering

Implement the shared native vector scene model and the first graph-family renderers: `flowchart` / `graph`, `stateDiagram` / `stateDiagram-v2`, `classDiagram`, `erDiagram`, `requirementDiagram`, and core `block` diagrams. This milestone should deliver the polished visual language: SF text rendering, careful line heights, readable rounded cards, subtle shadows, crisp strokes, arrowheads, edge-label capsules, dark/light/high-contrast palettes, and native accessibility elements.

### Milestone 4: sequence, schedule, and timeline-family rendering

Implement `sequenceDiagram`, `zenuml`, `journey`, `gantt`, `timeline`, `gitGraph`, and `eventmodeling`. These renderers need domain-specific layout rather than a generic graph pass: lifelines and activations for sequence/ZenUML, time scales and exclusions for Gantt, commit lanes for GitGraph, swimlanes for event modeling, and sectioned timeline/journey layouts.

### Milestone 5: chart and beta diagram rendering

Implement `pie`, `quadrantChart`, `xychart`, `sankey`, `packet`, `radar-beta`, `treemap-beta`, `venn-beta`, `mindmap`, `kanban`, `architecture-beta`, `C4*`, `ishikawa`, and `wardley-beta`. Preserve beta/new syntax status in diagnostics and tests. `TreeView` should remain "research required" until an official syntax page or upstream grammar evidence is found beyond config-schema references.

### Milestone 6: preview, zoom/pan, printing, and polish

Add `MermaidDiagramBlockView`, `MermaidDiagramPreviewView`, and a reusable `ZoomPanViewport`. Inline diagrams should render at a comfortable fitted height with click/tap affordance. Preview should support pinch/trackpad zoom, pan, fit-to-window, reset, keyboard shortcuts on macOS, accessible zoom buttons, and a minimum/maximum zoom clamp. Printing/export should render diagrams as native vector content where possible and never fall back to screenshots unless explicitly documented.

### Milestone 7: full validation and docs update

Run platform builds, unit tests, UI smoke tests, Mermaid-focused UI tests, print/export tests, and checkpoint captures. Update `ARCHITECTURE.md`, `docs/debug-contracts.md`, `docs/harness.md` if harness-visible state changes, `.agents/DOCUMENTATION.md`, and release/app-review docs if user-visible file type support changes. Move this ExecPlan to completed only after the support matrix and acceptance evidence are current.

## Mermaid Support Matrix

Inline and file integration:

- ` ```mermaid ` fenced blocks: supported as inline `mermaidDiagram` blocks.
- `.mermaid` and `.mmd` files: supported as standalone Mermaid documents.
- Common Markdown aliases such as `mmd` fences: consider as compatibility aliases only after tests prove they do not collide with code highlighting expectations; GitHub's documented fence language is `mermaid`.

Cross-cutting syntax/configuration:

- Frontmatter `--- ... ---`: parse YAML-like `title`, `displayMode`, and safe `config` keys needed by Mermaid diagrams.
- Directives `%%{init: ...}%%` / `%%{initialize: ...}%%`: parse for compatibility, prefer frontmatter where both are present, and reject unsafe keys with diagnostics.
- `%%` comments: strip from parsing while preserving line mapping for diagnostics.
- `accTitle` and `accDescr`: map to native accessibility labels/descriptions.
- `theme`, `themeVariables`, `darkMode`, `fontFamily`, `fontSize`: map into a native `MermaidDiagramTheme`.
- `themeCSS`, raw CSS, HTML labels, `<br>`/HTML-rich labels: do not render as HTML/CSS; support safe Markdown/text equivalents and emit diagnostics for ignored web-only styling.
- `click` links and actor menus: support safe URL opening through native `openURL`; ignore JavaScript callbacks.
- Icon packs and architecture icons: support a built-in offline symbol resolver; never fetch icon packs from a CDN at render time.
- Math labels using `$$`: parse as math spans, render as native text fallback first, and add a later native math renderer only if the repo gains one without HTML/CSS/JS.
- Layout config values `dagre`, `elk`, `tidy-tree`, and `cose-bilkent`: parse config values; map to native layout engines where implemented, otherwise render with the closest native fallback and emit diagnostics.
- Mermaid `info`: render a native informational card that reports the implemented compatibility version and support matrix version.

Graph and model diagrams:

- `flowchart` / `graph`: nodes, edges, directions, labels, subgraphs, shapes, arrow variants, edge IDs, classes, styles, Markdown strings, and layout/look config.
- `stateDiagram` / `stateDiagram-v2`: states, transitions, start/end, composite states, choice/fork/join/note/concurrency where documented.
- `classDiagram`: classes, labels, members, annotations, relationships, namespaces, generics, cardinality labels, notes, comments, and safe click links.
- `erDiagram`: entities, crow's-foot cardinality, identifying/non-identifying relationships, attributes, keys, comments, aliases.
- `requirementDiagram`: SysML requirement/element/relationship declarations, Markdown formatting in quoted text, risk and verification enums.
- `block`: blocks, columns, explicit block positioning, spaces, connectors, block arrows, styles.
- `architecture-beta`: groups, services, junctions, icons, side-specific edges, arrows, and nested groups.
- `C4*`: C4Context, C4Container, C4Component, C4Dynamic, C4Deployment, boundaries, relationships, update directives, sprites/icons where safely mappable; mark as experimental.

Sequence and timeline diagrams:

- `sequenceDiagram`: participants/actors, aliases, actor symbols, create/destroy, grouping boxes, messages and all current arrow variants, activations, notes, loops, alt/opt/par/critical/break/rect, autonumber including start/increment, actor menus and safe links.
- `zenuml`: participants, annotators, aliases, sync/async/create/reply messages, nesting, comments, loops, if/else, opt, par, try/catch/finally.
- `journey`: sections and tasks with 1-5 scores and actors.
- `gantt`: titles, date formats, axis formats, sections, tags, milestones, IDs, `after` dependencies, exclusions, weekdays/weekends, today marker, compact/display config.
- `timeline`: title, sections, periods, multiple events per period, ordering.
- `gitGraph`: commit, branch, checkout/switch, merge, cherry-pick if documented, custom commit IDs/types/tags, branch order, orientation, and theme styling.
- `eventmodeling`: compact and relaxed timeframes, inline data, data blocks, reset frames, multiple relations, entity types, namespaces/swimlanes, and documented data-type labels.

Charts and structured visualizations:

- `pie`: title, `showData`, positive decimal values, legend and label placement.
- `quadrantChart`: title, axes, quadrants, points, direct styles, class styles, chart config.
- `xychart`: horizontal/vertical orientation, title, categorical/numeric x-axis, numeric y-axis, line/bar series, data labels, palette config.
- `sankey`: three-column CSV input, quoted commas/quotes, link color, node alignment, label styles, node width/padding, node colors.
- `packet`: explicit bit ranges, `+<count>` ranges, labels.
- `radar-beta`: axes, curves, key-value values, legends, min/max/ticks/graticules.
- `treemap-beta`: indentation hierarchy, values, `:::class` styling, value formatting.
- `venn-beta`: sets, unions, labels, sizes, text nodes, styles.
- `wardley-beta`: coordinates, anchors, decorators, links/dependencies, evolution arrows, trend indicators, pipelines, custom stages, notes.
- `mindmap`: indentation hierarchy, supported shapes, classes, icons as safe offline symbols.
- `kanban`: columns, tasks, task metadata, priority/ticket/assigned rendering, `ticketBaseUrl` as safe native links.
- `ishikawa`: problem line, indentation-based cause hierarchy.
- `TreeView`: keep as research-required unless an official syntax document or upstream grammar evidence is found.

## Concrete Steps

Run all commands from `/Users/matthewmoore/Projects/free-markdown-viewer` unless stated otherwise.

1. Add support-matrix fixtures and red parser tests:

       xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-mermaid-parser-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/MermaidDiagramTests" test

   Expected initial result: tests fail because the app still treats Mermaid fences as code blocks and does not discover `.mermaid` / `.mmd` files.

2. Extend document discovery:

       rg -n "WorkspaceDocumentKind|SupportedDocumentExtensions|normalizedRequest|missingMarkdownContent" "Quick Markdown Viewer/Quick Markdown Viewer"

   Expected implementation result: `.mermaid` and `.mmd` are included in local folders, GitHub workspaces, direct file opens, sidebar nodes, session restore, print/export, and harness open-file flows.

3. Add the shared Mermaid model/compiler:

       rg -n "MarkdownBlockKind|MarkdownCodeBlockCatalog|shouldRenderStructuredContent|blocks\\(for text" "Quick Markdown Viewer/Quick Markdown Viewer"

   Expected implementation result: fenced `mermaid` code blocks and Mermaid files produce `MarkdownBlockKind.mermaidDiagram` with typed parse diagnostics instead of syntax-highlighted code blocks.

4. Add native graph-family renderer and focused tests:

       xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-mermaid-graph-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/MermaidDiagramTests/testFlowchartRendersNativeScene" "-only-testing:Quick Markdown ViewerTests/MermaidDiagramTests/testStateDiagramRendersNativeScene" "-only-testing:Quick Markdown ViewerTests/MermaidDiagramTests/testERDiagramRendersNativeScene" test

   Expected result: parser snapshots and native scene snapshots are deterministic; unsupported syntax yields diagnostics without crashing.

5. Add inline UI and preview behavior:

       xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-mermaid-ui-tests -destination "platform=macOS,arch=arm64" "-only-testing:Quick Markdown ViewerUITests/MermaidDiagramUITests" test

   Expected result: clicking an inline diagram opens the media-style preview path, exposes `mermaid-preview.container`, and zoom/pan controls update the visible diagram scale.

6. Validate standalone Mermaid files:

       ./scripts/capture-checkpoint --fixture mermaid/flowchart_basic.mmd --platform-target macos --checkpoint mermaid-file-macos
       ./scripts/compare-goldens --checkpoint mermaid-file-macos

   Expected result: `.mmd` opens as a rendered diagram document, not a Markdown source page or an ignored file.

7. Validate universal builds and narrow app tests:

       ./scripts/build --platform all
       ./scripts/test-unit
       ./scripts/test-ui-macos --smoke
       ./scripts/test-ui-ios --device both --smoke
       python3 scripts/check_execplan.py
       python3 scripts/knowledge/check_docs.py

   Expected result: all pass before this plan is marked complete.

## Validation and Acceptance

The feature is acceptable only when all of these are true:

- Inline fenced `mermaid` blocks render as native diagram cards in Markdown and no longer render as syntax-highlighted code blocks.
- Clicking/tapping an inline diagram opens a video/media-style preview with native zoom and pan controls.
- `.mermaid` and `.mmd` files are discoverable in local and GitHub workspaces and open as rendered Mermaid documents.
- The app compiles and runs without `WKWebView`, JavaScript execution, HTML/CSS rendering, remote diagram services, or external renderer subprocesses.
- Every official Mermaid 11.15.0 diagram declaration is represented in `MermaidDiagramKind` and has a tested support status: supported, partially supported with diagnostics, beta-supported, or explicitly unsupported with source-preserving fallback.
- Core graph-family diagrams render with polished Apple-quality typography, spacing, shadows, strokes, labels, arrowheads, and dark/light/high-contrast behavior.
- Unsafe features such as JavaScript callbacks, remote icon loading, raw HTML labels, and `themeCSS` do not execute or render as web content.
- Accessibility labels use `accTitle` / `accDescr` when present and expose meaningful native elements for diagrams, preview controls, and interactive links.
- Print/export paths render diagrams legibly and preserve source text in plain-text print artifacts.
- Focused unit/UI tests, platform builds, smoke tests, docs checks, and relevant checkpoints pass.

## Idempotence and Recovery

Parser output, layout output, render scenes, and preview state are derived data from source text, theme, diagram kind, and available size. Caches must be disposable and keyed by source hash, theme identifier, diagram kind, and layout inputs. A bad cache should be recoverable by clearing memory without touching user files.

If a renderer regresses, the safe fallback is a native diagnostic card that preserves the original Mermaid source text and never crashes document loading. If the whole feature needs rollback, remove the `mermaidDiagram` block wiring and `.mermaid` / `.mmd` document-kind support while keeping fixtures and red tests as the durable backlog contract.

No migration is required for user workspaces. No production credentials, network entitlement changes, or database changes are involved.

## Artifacts and Notes

Primary research sources used while drafting:

- Mermaid syntax reference, version 11.15.0: https://mermaid.js.org/intro/syntax-reference
- Mermaid config schema: https://mermaid.js.org/config/schema-docs/config.html
- Mermaid configuration/frontmatter: https://mermaid.js.org/config/configuration
- Mermaid directives: https://mermaid.js.org/config/directives
- Mermaid theming: https://mermaid.js.org/config/theming.html
- Mermaid layouts: https://mermaid.js.org/config/layouts.html
- Mermaid icons: https://mermaid.js.org/config/icons.html
- Mermaid math: https://mermaid.js.org/config/math.html
- Mermaid accessibility: https://mermaid.js.org/config/accessibility.html
- GitHub Mermaid fenced block docs: https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams
- GitHub `.mermaid` / `.mmd` file support changelog: https://github.blog/changelog/2022-03-17-mermaid-topojson-geojson-and-ascii-stl-diagrams-are-now-supported-in-markdown-and-as-files/

Official diagram syntax pages consulted:

- https://mermaid.js.org/syntax/flowchart.html
- https://mermaid.js.org/syntax/sequenceDiagram.html
- https://mermaid.js.org/syntax/classDiagram.html
- https://mermaid.js.org/syntax/stateDiagram.html
- https://mermaid.js.org/syntax/entityRelationshipDiagram.html
- https://mermaid.js.org/syntax/userJourney.html
- https://mermaid.js.org/syntax/gantt.html
- https://mermaid.js.org/syntax/pie.html
- https://mermaid.js.org/syntax/quadrantChart.html
- https://mermaid.js.org/syntax/requirementDiagram.html
- https://mermaid.js.org/syntax/gitgraph.html
- https://mermaid.js.org/syntax/c4
- https://mermaid.js.org/syntax/mindmap.html
- https://mermaid.js.org/syntax/timeline.html
- https://mermaid.js.org/syntax/zenuml.html
- https://mermaid.js.org/syntax/sankey.html
- https://mermaid.js.org/syntax/xyChart.html
- https://mermaid.js.org/syntax/block.html
- https://mermaid.js.org/syntax/packet.html
- https://mermaid.js.org/syntax/kanban.html
- https://mermaid.js.org/syntax/architecture.html
- https://mermaid.js.org/syntax/radar.html
- https://mermaid.js.org/syntax/eventmodeling.html
- https://mermaid.js.org/syntax/treemap.html
- https://mermaid.js.org/syntax/venn.html
- https://mermaid.js.org/syntax/ishikawa.html
- https://mermaid.js.org/syntax/wardley.html

Validation commands run for this planning slice:

- `sed -n '1,220p' README.md`
- `sed -n '1,240p' ARCHITECTURE.md`
- `sed -n '1,260p' .agents/PLANS.md`
- `sed -n '1,260p' docs/PLANS.md`
- `sed -n '1,260p' docs/harness.md`
- `sed -n '1,260p' docs/debug-contracts.md`
- `sed -n '1,280p' docs/exec-plans/active/2026-03-23-inline-animated-media.md`
- `sed -n '1,260p' docs/exec-plans/active/2026-04-15-fenced-code-syntax-highlighting.md`
- `rg -n "Markdown|fence|code block|media|popover|video|QuickLook|Renderer|Preview" "Quick Markdown Viewer" docs ARCHITECTURE.md README.md`
- `rg -n "WorkspaceDocumentKind|markdownExtensions|mmd|mermaid|codeBlock|MediaPreview|popover|sheet|zoom|pan|Magnification|block.video|media-preview" "Quick Markdown Viewer/Quick Markdown Viewer"`
- `git status --short`

Implementation validation commands run:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-mermaid-parser-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/MermaidDiagramTests" test` passed.
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-mermaid-ui-tests -destination "platform=macOS,arch=arm64" "-only-testing:Quick Markdown ViewerUITests/MermaidDiagramUITests" test` compiled but failed before assertions because the local UI runner timed out while enabling automation mode.
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-mermaid-ui-tests-retry -destination "platform=macOS,arch=arm64" "-only-testing:Quick Markdown ViewerUITests/MermaidDiagramUITests" test` reproduced the same UI automation bootstrap timeout.
- `./scripts/build --platform all` passed.
- `./scripts/test-unit` passed.
- `./scripts/test-integration` was attempted separately, stalled after build with no test output for several minutes, and was interrupted; the same integration test passed under `./scripts/test-unit`.
- `python3 scripts/check_execplan.py` passed.
- `python3 scripts/knowledge/check_docs.py` passed.
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-mermaid-unit-retake -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/MermaidDiagramTests" test` passed.
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-mermaid-ui-retake -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerUITests/MermaidDiagramUITests" test` built and launched the UI test runner, then wedged before test-case output and was interrupted.
- `./scripts/capture-checkpoint --fixture mermaid_inline_showcase.md --platform-target macos --checkpoint mermaid-inline-retake` passed and captured `visibleKinds: ["heading", "paragraph", "mermaidDiagram", "paragraph"]`.
- `./scripts/capture-checkpoint --fixture mermaid/flowchart_basic.mmd --platform-target macos --checkpoint mermaid-flowchart-retake` passed and captured `visibleKinds: ["mermaidDiagram"]`.
- Direct debug-app interaction with `mermaid_inline_showcase.md` verified that clicking `block.mermaid.*` opens `mermaid-preview.container`, zoom controls change scale, drag-pan moves the diagram, Fit recenters it, and Close dismisses the preview.
- `./scripts/test-unit` passed again.
- `./scripts/build --platform all` passed again.
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-print-ui-signed-unwedge-fixed2 -destination "platform=macOS,arch=arm64" DEVELOPMENT_TEAM=GG34PA8F4A "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testToolbarPrintMenuTriggersSelectedAndAllDocumentActions" test` passed.
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-print-ui-signed-unwedge-fixed2 -destination "platform=macOS,arch=arm64" DEVELOPMENT_TEAM=GG34PA8F4A "-only-testing:Quick Markdown ViewerUITests/MermaidDiagramUITests" test` passed.

## Interfaces and Dependencies

New or changed shared interfaces:

- `WorkspaceDocumentKind.mermaid`
- `MarkdownBlockKind.mermaidDiagram`
- `MarkdownMermaidDiagram`
- `MermaidDiagramKind`
- `MermaidCompiler`
- `MermaidParseResult`
- `MermaidDiagnostic`
- `MermaidDiagramConfig`
- `MermaidDiagramTheme`
- `MermaidScene`
- `MermaidLayoutEngine`
- `MermaidRenderer`
- `ZoomPanViewport`
- `MermaidDiagramPreviewView`

Expected dependencies:

- Foundation, SwiftUI, CoreGraphics, CoreText, AppKit/UIKit adapters as needed.
- No runtime JavaScript, `WKWebView`, HTML/CSS renderer, Mermaid CLI, Graphviz binary, or remote rendering service.
- If a third-party Swift package is considered for graph layout, it must be source-available, compile on all supported Apple platforms, not embed a web renderer, and have a small enough API surface to keep the implementation auditable.

Harness and docs dependencies:

- `docs/debug-contracts.md` must add diagram block/preview accessibility IDs and visible block kind `mermaidDiagram`.
- `ARCHITECTURE.md` must add the Mermaid compiler/renderer subsystem once code lands.
- `.agents/DOCUMENTATION.md` must list this active workstream while the plan remains active.
- Release docs should mention native Mermaid support only after implementation and validation are complete.
