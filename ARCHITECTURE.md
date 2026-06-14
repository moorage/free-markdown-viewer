# ARCHITECTURE.md

This document is the top-level codemap for the live repository. It names the major modules, boundaries, and cross-cutting concerns so a newcomer can navigate the repository without guessing.

## System overview

This repository is building a universal Apple-platform Markdown viewer with eight major subsystems:

1. workspace browsing
2. navigation and history
3. markdown parsing and lightweight rendering state
4. native Mermaid diagram parsing/rendering
5. media classification and playback hosts
6. macOS Quick Look preview extension
7. native JSON-family parsing/rendering
8. platform shells and harness tooling

The live codebase is still early. The Xcode template exists, but most durable structure is being added by the harness bootstrap plan.

## Top-level domains

### App shell

Purpose:

- host the viewer on macOS, iPhone, and iPad
- expose a shared shell with platform-specific host adapters

Primary code area:

- `Quick Markdown Viewer/Quick Markdown Viewer/`

Stable concepts:

- `AppModel`
- `WorkspaceProvider`
- `NavigationEntry`
- `HarnessLaunchOptions`
- `HarnessStateSnapshot`

### Tests

Purpose:

- verify launch-option parsing, workspace selection, snapshot correctness, and UI accessibility contracts

Primary code areas:

- `Quick Markdown Viewer/Quick Markdown ViewerTests/`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/`

### Native Mermaid diagrams

Purpose:

- detect inline `mermaid` fenced blocks and standalone `.mermaid` / `.mmd` files
- compile Mermaid source into a safe typed Swift model
- render diagrams with native SwiftUI/CoreGraphics surfaces and media-style zoom/pan preview

Primary code areas:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Mermaid/`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/MermaidDiagramViews.swift`

Stable concepts:

- `MermaidDiagramKind`
- `MermaidCompiler`
- `MarkdownMermaidDiagram`
- `MermaidScene`
- `MermaidDiagramBlockView`

### Structured JSON documents

Purpose:

- detect standalone `.json`, `.jsonc`, `.ndjson`, and `.jsonl` files
- detect Markdown fenced `json`, `jsonc`, `ndjson`, and `jsonl` blocks
- parse JSON-family source into native source-mapped rows with diagnostics
- render viewer/source modes with line gutters, token highlighting, collapsible sections, sticky ancestor context, and compact table projections for homogeneous object arrays

Primary code areas:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/JSON/`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/JSONDocumentView.swift`

Stable concepts:

- `JSONFamilyDocumentKind`
- `JSONDocumentModel`
- `JSONValueNode`
- `JSONPresentationBuilder`
- `MarkdownJSONDocument`

### macOS Quick Look extension

Purpose:

- provide Finder Quick Look previews for Markdown files by bundling a macOS app extension
- render read-only Markdown previews with native AppKit text surfaces
- keep the extension enabled by default through normal app-extension registration, without a separate installer step

Primary code areas:

- `Quick Markdown Viewer/Quick Markdown Viewer QuickLook/`
- `Quick Markdown Viewer/QuickLookPreview-Info.plist`

Stable concepts:

- `PreviewViewController`
- `MarkdownQuickLookPreviewFormatter`

### Fixtures and artifacts

Purpose:

- provide deterministic markdown/media inputs and checked-in expected outputs

Primary code areas:

- `Fixtures/docs/`
- `Fixtures/media/`
- `Fixtures/expected/`
- `artifacts/` for runtime outputs only

### Harness and knowledge tooling

Purpose:

- provide shell-first build/test/capture entry points
- keep docs and repo-map artifacts current

Primary code areas:

- `scripts/`
- `docs/`
- `.agents/`
- `.codex/`

## Layering rules

- shared state and contracts stay in platform-neutral Swift files
- AppKit usage stays behind `#if os(macOS)` adapters
- Quick Look extension code stays macOS-only and uses AppKit/QuickLook APIs only inside the extension target
- UIKit usage stays behind `#if os(iOS)` adapters
- shell scripts call shared helpers in `scripts/lib/`
- docs verification and repo-map generation must use only standard Python 3 library modules

## Cross-cutting concerns

### Observability

The harness must be able to:

- launch the app deterministically
- dump machine-readable state and perf snapshots
- capture app-owned screenshots
- identify key UI elements through stable accessibility identifiers

### Reliability

Critical commands should fail clearly when:

- Xcode is missing
- the shared scheme is absent
- the requested simulator device is unavailable
- required docs or plans are missing

### Product drift control

If code changes affect:

- command surface -> update `docs/harness.md`
- snapshot schema -> update `docs/debug-contracts.md`
- architecture boundaries -> update this file
- workflow expectations -> update `AGENTS.md` and `README.md`
