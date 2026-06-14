# Structured JSON Viewer

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Quick Markdown Viewer should treat JSON-family content as first-class readable documents, not just source text. Standalone `.json`, `.jsonc`, `.ndjson`, and `.jsonl` files, plus Markdown fenced code blocks declared as `json`, `jsonc`, `ndjson`, or `jsonl`, should have a native structured viewer with collapsible object/array sections, a source/viewer toggle, syntax highlighting, compact indentation, and original source line numbers in a gutter.

The line gutter is part of the product contract: viewer rows must continue to identify their original source line even when the viewer pretty-prints a one-line object over multiple visual rows, wraps long values, or hides descendants behind a collapsed ancestor. Long nested arrays or table-like JSON sections should keep the active ancestor headers visible while scrolling so users can tell which object, array, or record they are reading. The behavior must work in the main app, macOS Quick Look, and printing without introducing `WKWebView`, HTML/CSS/JavaScript rendering, external renderer subprocesses, or remote services.

## Progress

- [x] (2026-06-14T06:43Z) Created this ExecPlan after auditing the existing document-kind list, Markdown code-block highlighting path, lazy table rendering, Quick Look formatter, drag/drop coordinator, and print composition path.
- [x] (2026-06-14T07:02Z) Added a shared JSON-family lexer/parser/model with source-mapped viewer rows, diagnostics, JSONC comments/trailing commas, and NDJSON/JSONL record recovery.
- [x] (2026-06-14T07:02Z) Added first-class `.json`, `.jsonc`, `.ndjson`, and `.jsonl` workspace/document recognition, macOS document type declarations, Quick Look content type declarations, and macOS file-drop/open normalization coverage.
- [x] (2026-06-14T07:02Z) Wired standalone JSON-family files and Markdown fenced JSON-family blocks into `MarkdownBlockKind.jsonDocument`, with viewer/source SwiftUI rendering, line gutters, collapsible rows, print fallback text, and deterministic fixtures.
- [x] (2026-06-14T07:02Z) Added bounded Quick Look rendered support for JSON-family files with native line-numbered previews.
- [x] (2026-06-14T07:46Z) Added shared syntax tokens, token-highlighted source mode, live active-ancestor sticky headers, readable array rendering, and print text output for JSON viewer rows.
- [x] (2026-06-14T07:46Z) Added Quick Look strict-JSON expand/collapse controls, plus focused parser and Quick Look collapse coverage.
- [x] (2026-06-14T16:54Z) Replaced object-array table rendering with regular indexed array rows, added scalar-array coverage, and added a large nested fixture for sticky ancestor validation.
- [x] (2026-06-14T17:06Z) Verified interactive macOS printing opens the native print sheet for `events.ndjson`, verified NDJSON/JSONL harness PDF export, and added regression coverage for NDJSON/JSONL print composition plus NDJSON AppKit print-operation output.
- [x] (2026-06-14T18:04Z) Added macOS UI automation for JSON sticky ancestor scrolling, with stable JSON viewer scroll and sticky-header accessibility identifiers. The focused signed UI test now launches, scrolls the large nested fixture, and verifies the sticky ancestor header.

## Surprises & Discoveries

- Observation: JSON syntax highlighting already exists for fenced `json` code blocks, but it only renders highlighted source text.
  Evidence: `CodeBlockSyntaxHighlighting.swift` includes `SyntaxHighlightLanguage.json` and `CodeBlockSyntaxHighlighter.highlightedAttributedText(...)`, while `MarkdownBlockView.codeBlockContent` only chooses highlighted `Text` or plain `Text(verbatim:)`.

- Observation: supported workspace document kinds currently stop at Markdown, Mermaid, CSV, and TSV.
  Evidence: `WorkspaceDocumentKind.forPath(_:)` and `SupportedDocumentExtensions.all` do not include `json`, `jsonc`, `ndjson`, or `jsonl`.

- Observation: drag/drop and Launch Services file-open behavior should become JSON-aware automatically once supported extensions and document types are added.
  Evidence: `ExternalWorkspaceOpenCoordinator.normalizedRequest(for:)` accepts any file whose extension is in `SupportedDocumentExtensions`, then opens the parent folder with the dropped file selected.

- Observation: the current Markdown code-block model preserves fence metadata but not source line spans.
  Evidence: `MarkdownCodeBlock` stores `code`, `infoString`, `rawLanguage`, `language`, and `isFenced`, but no original opening line, content line range, or source byte/character range.

- Observation: the current lazy table renderer already uses pinned section headers for large CSV/TSV and large Markdown tables, but JSON needs sticky active ancestor headers rather than only a single column header row.
  Evidence: `MarkdownBlockView.tableContent(_:)` uses `LazyVStack(... pinnedViews: [.sectionHeaders])` for lazy tables.

- Observation: Quick Look currently owns an extension-local AppKit formatter, so JSON parity needs either shared model code that can also be target-membered into the extension or a carefully duplicated parser.
  Evidence: `PreviewViewController.swift` defines `MarkdownQuickLookPreviewFormatter` inside the Quick Look extension target instead of linking the full app renderer.

- Observation: printing already renders the same structured SwiftUI block stack used by the app, which is the right integration point for printable JSON output.
  Evidence: `PrintableDocumentCompositionView` renders `DocumentBlockStackView` with `isPrinting: true`.

- Observation: the project uses filesystem-synchronized Xcode groups for the app target, so new Swift files under the app source tree are picked up without manual `project.pbxproj` edits.
  Evidence: the macOS app build included `App/Shared/JSON/JSONDocument.swift` and `App/Shell/JSONDocumentView.swift` after adding them to the filesystem.

- Observation: the focused macOS UI test for JSON sticky ancestor scrolling is sensitive to exact scroll landing depth, so it should assert the stable ancestor path rather than one exact deepest descendant label.
  Evidence: the passing test waits for `json.stickyHeader` to contain `workspace > release > streams > [1] > records` after swiping the `json.viewerScrollView`.

## Decision Log

- Decision: Add a first-class shared JSON presentation model instead of converting JSON into Markdown tables or plain code blocks.
  Rationale: collapsibility, stable line mapping, JSONC comments, NDJSON records, source/viewer toggling, and sticky ancestor headers are JSON-specific behavior that should not leak into generic table or code-block rendering.
  Date/Author: 2026-06-14 / Codex

- Decision: Preserve source locations in the model and derive visible viewer rows from source-mapped nodes.
  Rationale: line numbers must remain correct across pretty rendering, wrapping, expansion, and collapse, which is only reliable if every rendered row carries an original source line.
  Date/Author: 2026-06-14 / Codex

- Decision: Use a repo-owned lightweight JSON-family lexer/parser for the presentation layer, while keeping Tree-sitter JSON highlighting available for source-mode JSON where appropriate.
  Rationale: Foundation JSON parsing loses comments, can reject useful JSONC/partial NDJSON diagnostics, and does not preserve token locations. A small lexer can support JSON, JSONC comments/trailing commas, NDJSON record boundaries, diagnostics, and line mapping without adding a broad dependency.
  Date/Author: 2026-06-14 / Codex

- Decision: Treat Markdown fenced `json`, `jsonc`, `ndjson`, and `jsonl` blocks as structured JSON blocks, but leave inline code spans as text in this milestone.
  Rationale: fenced blocks are block-level content and can host toggles, disclosure controls, sticky ancestry, and gutters. Inline code spans live inside flowing paragraph text and cannot carry an ergonomic collapsible control without destabilizing the Markdown text surface.
  Date/Author: 2026-06-14 / Codex

- Decision: Keep Quick Look native and bounded with extension-local JSON-family formatting for collapsible previews.
  Rationale: the Quick Look formatter is intentionally extension-local; strict JSON and sanitized JSONC can be safely pretty-printed and collapsed through Foundation, while NDJSON can collapse each parseable physical record line without linking the app parser into the extension.
  Date/Author: 2026-06-14 / Codex

- Decision: Render JSON arrays as indexed tree rows instead of compact tables.
  Rationale: tables hide the actual array structure and make object arrays feel different from scalar arrays. Indexed rows keep arrays, nested objects, and simple strings readable with the same disclosure, gutter, and sticky-ancestor behavior.
  Date/Author: 2026-06-14 / Codex

## Outcomes & Retrospective

Implementation completed for the current milestone. JSON-family files are workspace-visible and draggable/openable on macOS, Markdown fenced JSON-family blocks render as structured JSON blocks, and the app exposes a native viewer/source JSON surface with source-mapped gutters, collapsible rows, indexed array items, token-highlighted source mode, and live active-ancestor sticky headers. Print text output includes the same expanded row outline with source line gutters. Quick Look declares JSON-family content types, pretty-prints JSON/JSONC when possible, collapses JSON/JSONC containers, collapses parseable NDJSON/JSONL record lines, and preserves native line-numbered source fallback.

Remaining follow-up candidates: add Quick Look JSONC/NDJSON structural parsing if extension target sharing becomes desirable, and add screenshot/checkpoint artifacts for the new JSON fixtures. Sticky ancestor UI automation now has a clean signed macOS run.

## Context and Orientation

Relevant existing files:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/SyntaxHighlighting/CodeBlockSyntaxHighlighting.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/DocumentPrinting.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/PlatformPrintPresenter.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer QuickLook/PreviewViewController.swift`
- `Quick Markdown Viewer/Info-macOS.plist`
- `Quick Markdown Viewer/QuickLookPreview-Info.plist`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `docs/debug-contracts.md`
- `docs/quicklook-feature-parity.md`

Current behavior:

- Fenced `json` code blocks can be syntax-highlighted as source.
- Standalone JSON-family files are not included in workspaces, drag/drop normalization, Launch Services document types, print composition, or Quick Look content types.
- Code blocks do not expose original source line metadata.
- The app has table controls and lazy table headers, but no general collapsible tree/table JSON view.

Expected new implementation areas:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/JSON/`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/JSONDocumentView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer QuickLook/JSONQuickLookPreviewView.swift` or a small AppKit view section inside `PreviewViewController.swift`
- JSON fixtures under `Fixtures/docs/`

## Plan of Work

1. Add JSON-family file recognition and platform registration.
2. Build a shared JSON-family lexer/parser that preserves token spans, original line numbers, comments where relevant, diagnostics, and NDJSON record boundaries.
3. Add a shared presentation model that converts parsed JSON into visible rows for viewer mode and source rows for source mode.
4. Wire standalone JSON-family files and Markdown fenced JSON-family blocks into the shared block model.
5. Build the main app UI with viewer/source toggles, disclosure state, compact indentation, syntax highlighting, line gutters, and sticky ancestor headers.
6. Add Quick Look support with the same parser/model and native AppKit controls.
7. Update printing so JSON-family content prints in a readable source-mapped structured format.
8. Add focused fixtures, unit tests, UI tests where practical, Quick Look runtime tests, print/PDF checks, docs, and checkpoint evidence.

## Concrete Steps

1. Extend `WorkspaceDocumentKind` with `json`, `jsonc`, and `ndjson` cases. Map `.json` to `json`, `.jsonc` to `jsonc`, and both `.ndjson` and `.jsonl` to `ndjson`. Update `isDelimitedText`, `iconSystemName`, `forPath(_:)`, `SupportedDocumentExtensions.all`, local workspace enumeration, GitHub workspace enumeration, search inputs, and any switch over document kind.

2. Update macOS app document registration in `Info-macOS.plist`. Add a JSON document type using the platform JSON content type where available, plus imported plain-text conforming UTTypes for JSONC and NDJSON/JSONL if no stable system type is available. Add the same supported content types to `QuickLookPreview-Info.plist`. Keep folder, Markdown, Mermaid, CSV, and TSV declarations unchanged.

3. Add shared JSON source types under `App/Shared/JSON/`:
   - `JSONFamilyDocumentKind` for `json`, `jsonc`, `ndjson`, and `jsonl` aliases.
   - `JSONSourceLocation` with one-based line and column.
   - `JSONSourceRange` with start/end locations plus character offsets.
   - `JSONToken` with punctuation, key/string, number, bool, null, comment, error, and newline/record boundary roles.
   - `JSONDiagnostic` with message, severity, source range, and record index for NDJSON.
   - `JSONValueNode` with stable IDs, path components, value kind, optional key token, summary text, source range, children, and record metadata.
   - `JSONDocumentModel` with original source, document kind, root nodes, tokens, diagnostics, and line index.

4. Implement a small `JSONFamilyLexer` that normalizes CRLF to LF for parsing while preserving original one-based line numbers. It should tokenize strings with escapes, numbers, keywords, punctuation, line comments, block comments, and invalid characters. JSON mode rejects comments and trailing commas with diagnostics. JSONC mode accepts comments and trailing commas. NDJSON/JSONL mode parses each nonblank physical line as one record; a malformed record yields a diagnostic row without preventing later records from rendering.

5. Implement a recursive-descent `JSONFamilyParser` over the token stream. It should construct object, array, string, number, boolean, null, comment, and error nodes with source ranges. It should recover after missing commas, missing colons, unclosed containers, and malformed NDJSON records so the viewer remains useful for imperfect files.

6. Add a `JSONPresentationBuilder` that transforms `JSONDocumentModel` plus a collapsed-node set into visible `JSONViewerRow` values. Rows must carry:
   - stable row ID
   - source line number from the original document
   - indentation depth using compact fixed increments
   - visible label/key/value fragments with syntax roles
   - disclosure availability and collapsed state
   - ancestor chain for sticky headers
   - indexed array labels for object and scalar array items
   - diagnostic state where parsing recovered

7. Define the line-gutter rule before UI work: source mode shows physical source lines. Viewer mode shows the original source line that produced each rendered row. If a minified one-line object is pretty-rendered into many rows, each derived row uses the same original source line, with continuation styling allowed but not a blank or synthetic line number. When a node is collapsed, the collapsed summary row keeps the container's opening source line.

8. Render arrays as normal tree rows with indexed item labels such as `[0]` and `[1]`. Object arrays and scalar arrays use the same disclosure, gutter, and sticky ancestor behavior as any other JSON node.

9. Extend the shared block model. Either add `MarkdownBlockKind.jsonDocument` with a `MarkdownJSONDocument` payload, or add a JSON payload to `MarkdownCodeBlock` and introduce a standalone JSON block wrapper. The chosen shape must support both standalone files and Markdown fenced JSON-family blocks without losing current code-block fallback behavior for unknown languages.

10. Extend Markdown fenced code annotation so `json`, `jsonc`, `ndjson`, and `jsonl` fences record the fence opening line and content line range. Use that range to parse inline fenced JSON and maintain original Markdown document line numbers in the gutter. Unknown or invalid fence languages stay on the existing code-block path.

11. Update `AppModel.blocks(for:kind:path:)` so standalone JSON-family files produce a structured JSON block instead of Markdown blocks. Outline items can stay empty for JSON in the first implementation unless a later decision adds a JSON path outline. Search should keep using the original text and line index so JSON source lines remain findable.

12. Add a `JSONDocumentView` in the app shell. It should include:
   - a compact segmented `Viewer` / `Source` toggle
   - disclosure buttons for object, array, record, and table sections in viewer mode
   - source and viewer gutters aligned to rows
   - syntax-colored keys, strings, numbers, booleans, nulls, comments, and diagnostics
   - small indentation, with stable row heights where possible
   - a sticky ancestor header stack derived from visible row preferences while scrolling
   - accessibility identifiers for mode toggle, source gutter rows, viewer rows, disclosure buttons, and sticky ancestry

13. Wire `MarkdownBlockView` so fenced JSON-family blocks render through `JSONDocumentView` inside Markdown documents. The block-level toggle is local to that block. Source mode should preserve the raw fence content, not the full Markdown fence markers, and the gutter should use original Markdown source lines for the fenced content.

14. Wire standalone JSON-family documents so the main document toolbar exposes the same viewer/source mode. Store selected mode and collapsed IDs in view state keyed by selected path; reset or reconcile that state when the selected file changes. Avoid persisting collapsed state to disk in this milestone.

15. Update printing. `PrintableDocumentCompositionView` should render JSON-family sections through a print-specific JSON view that is deterministic, noninteractive, and source-mapped. Printing a selected JSON document should honor current source/viewer mode when the mode is available in the composition input; print-all may default to viewer mode with all nodes expanded. Printed output must include line gutters and syntax styling where the platform print renderer supports color.

16. Update `DocumentPlainTextRenderer` so harness text-print artifacts for JSON-family documents remain useful. Include source text for source-mode artifacts and a deterministic tree outline for viewer-mode artifacts if mode state is threaded into the composition; otherwise default to raw source in plain-text artifacts and rely on PDF export for visual acceptance.

17. Update Quick Look. The extension should read JSON-family sources with the existing text-decoding helper, parse with the shared JSON model, default to viewer mode, include a native AppKit `Viewer` / `Source` segmented control, and allow disclosure toggling in viewer mode. Reuse the same line-number and diagnostic rules. Quick Look source mode may use an AppKit text view with gutter layout rather than the SwiftUI app view.

18. Update `docs/quicklook-feature-parity.md`, `docs/debug-contracts.md` if new accessibility IDs or state snapshot kinds are exposed, `ARCHITECTURE.md` for the new JSON subsystem, and `.agents/DOCUMENTATION.md` as milestones land.

19. Add fixtures:
   - `Fixtures/docs/json_showcase.json`
   - `Fixtures/docs/jsonc_showcase.jsonc`
   - `Fixtures/docs/events.ndjson`
   - `Fixtures/docs/events.jsonl`
   - `Fixtures/docs/markdown_json_showcase.md`
   These should cover minified one-line JSON, deeply nested objects, arrays of objects, scalar arrays, sparse arrays, long string wrapping, JSONC comments and trailing commas, malformed records, blank NDJSON lines, sticky ancestor scrolling, and fenced JSON-family blocks in Markdown.

20. Add focused tests in `Quick_Markdown_ViewerTests.swift` or split test files if the suite becomes too large:
   - file-kind and supported-extension mapping
   - Launch Services/drop normalization for JSON-family files opening parent folders
   - JSON/JSONC/NDJSON parsing and recovery
   - source line preservation for pretty rows, collapsed rows, comments, and NDJSON records
   - Markdown fenced JSON-family line offsets
   - visible row building after expand/collapse
   - indexed object-array and scalar-array rendering
   - print composition for standalone and fenced JSON-family content
   - Quick Look content type declarations and runtime viewer/source switching

21. Add UI coverage where stable automation exists. At minimum, add macOS UI tests for opening a JSON fixture, toggling source/viewer, collapsing a nested section, verifying gutter line labels stay tied to original lines, and confirming the sticky ancestor header appears after scrolling a long nested fixture. Add iPhone/iPad smoke coverage through the existing harness if simulator state allows it.

## Validation and Acceptance

Acceptance requires:

- `.json`, `.jsonc`, `.ndjson`, and `.jsonl` files appear in local and GitHub workspaces, can be selected from the sidebar, and can be dragged or Launch Services-opened on macOS to open the parent folder with the dropped file selected.
- Standalone JSON-family documents default to viewer mode with a visible `Viewer` / `Source` toggle.
- Markdown fenced blocks declared as `json`, `jsonc`, `ndjson`, or `jsonl` render with the same viewer/source behavior inside Markdown documents.
- Viewer mode supports collapsing and expanding object, array, and record sections without losing stable row IDs or incorrect line gutters.
- Source mode shows syntax-highlighted original source with line numbers.
- Viewer mode shows syntax-highlighted structured rows with compact indentation and original source line numbers, including pretty-rendered rows that span multiple visual rows from one original source line.
- Long nested JSON views keep active ancestor headers visible while scrolling.
- JSONC comments and trailing commas render intentionally in JSONC mode and produce diagnostics in strict JSON mode.
- NDJSON/JSONL preserve physical record line numbers, recover from malformed records, and continue rendering later valid records.
- Printing produces readable JSON-family output with line gutters and no blank pages in the exported PDF path.
- Quick Look supports JSON-family viewer/source switching and native collapsible viewer behavior without `WKWebView`, JavaScript, HTML/CSS rendering, or external subprocesses.
- Existing Markdown, Mermaid, CSV, TSV, code highlighting, search, outline, drag/drop, Quick Look, and print behavior does not regress.

Validation commands from `/Users/matthewmoore/Projects/free-markdown-viewer`:

- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`
- `plutil -lint "Quick Markdown Viewer/Info-macOS.plist" "Quick Markdown Viewer/QuickLookPreview-Info.plist"`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-json-viewer-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testJSONDocumentKindMappingIncludesJSONFamilyExtensions" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testJSONViewerRowsPreserveOriginalLineNumbersAfterPrettyPrinting" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testJSONViewerRowsPreserveLineNumbersAfterCollapse" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownJSONFenceUsesMarkdownSourceLineNumbers" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testNDJSONParserRecoversAfterMalformedRecord" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionDeclaresJSONFamilySupport" test`
- `./scripts/test-unit`
- `./scripts/build --platform all`
- `./scripts/capture-checkpoint --fixture json_showcase.json --platform-target macos --checkpoint json-viewer-macos`
- `./scripts/capture-checkpoint --fixture markdown_json_showcase.md --platform-target macos --checkpoint markdown-json-viewer-macos`
- `./scripts/test-ui-macos --smoke`
- `./scripts/test-ui-ios --device both --smoke`

Validation run in this implementation:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-json-viewer-build -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-json-viewer-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testWorkspaceDocumentKindMappingIncludesJSONFamilyExtensions" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExternalWorkspaceOpenCoordinatorNormalizesJSONFileToWorkspaceAndSelection" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testJSONViewerRowsPreserveOriginalLineNumbersAfterPrettyPrinting" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testJSONViewerRowsPreserveLineNumbersAfterCollapse" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownJSONFenceUsesMarkdownSourceLineNumbers" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testNDJSONParserRecoversAfterMalformedRecord" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionDeclaresMarkdownSupport" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionRendersJSONWithLineNumbers" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testCodeBlockSyntaxHighlighterCachesByLanguageContentHashAndTheme" test`
- `plutil -lint "Quick Markdown Viewer/Info-macOS.plist" "Quick Markdown Viewer/QuickLookPreview-Info.plist"`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`
- `./scripts/test-unit`
- `./scripts/build --platform all`
- `./scripts/test-unit --only-testing Quick_Markdown_ViewerTests/Quick_Markdown_ViewerTests/testJSONViewerRowsRenderObjectArraysAsIndexedItems --only-testing Quick_Markdown_ViewerTests/Quick_Markdown_ViewerTests/testJSONViewerRowsRenderScalarArraysAsIndexedItems --only-testing Quick_Markdown_ViewerTests/Quick_Markdown_ViewerTests/testJSONStickyHeaderFixtureProvidesDeepScrollableAncestorRows --only-testing Quick_Markdown_ViewerTests/Quick_Markdown_ViewerTests/testJSONParserPublishesSourceTokensForHighlighting --only-testing Quick_Markdown_ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionCollapsesJSONContainers`
- `./scripts/test-unit --only-testing Quick_Markdown_ViewerTests/Quick_Markdown_ViewerTests/testPrintSelectedNDJSONDocumentUsesStructuredRows --only-testing Quick_Markdown_ViewerTests/Quick_Markdown_ViewerTests/testExportPrintedNDJSONDocumentHarnessCommandWritesPDF --only-testing Quick_Markdown_ViewerTests/Quick_Markdown_ViewerTests/testMacPrintOperationPDFOutputRendersNDJSONDocument --only-testing Quick_Markdown_ViewerTests/Quick_Markdown_ViewerTests/testExportPrintedDocumentHarnessCommandWritesPDF --only-testing Quick_Markdown_ViewerTests/Quick_Markdown_ViewerTests/testMacPrintOperationPDFOutputIsNotBlank`
- `xcodebuild -project 'Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj' -scheme 'Quick Markdown Viewer' -configuration Debug -derivedDataPath /tmp/qmv-json-sticky-ui -destination 'platform=macOS,arch=arm64' DEVELOPMENT_TEAM=GG34PA8F4A -only-testing:'Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testJSONViewerShowsStickyAncestorHeaderAfterScrollingDeepNestedRows' test` (build succeeded; UI runner failed before test body with `Timed out while enabling automation mode`)
- `xcodebuild -quiet -project 'Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj' -scheme 'Quick Markdown Viewer' -configuration Debug -derivedDataPath /tmp/qmv-json-sticky-ui-retry4 -resultBundlePath /tmp/qmv-json-sticky-ui-retry4.xcresult -destination 'platform=macOS,arch=arm64' DEVELOPMENT_TEAM=GG34PA8F4A -only-testing:'Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testJSONViewerShowsStickyAncestorHeaderAfterScrollingDeepNestedRows' test` (passed)

## Idempotence and Recovery

JSON parse output, visible rows, token styles, diagnostics, collapsed state, and sticky ancestor state are derived from the current document text and in-memory view state. No migration or persisted workspace format change is required. If a parser change regresses, the app can fall back to source mode for JSON-family content while preserving file recognition and document opening.

The smallest rollback for the implementation is to remove the new JSON shared files, remove JSON cases from `WorkspaceDocumentKind` and `SupportedDocumentExtensions`, remove JSON document/Quick Look type declarations, and route JSON-family fences back through the existing code-block source renderer.

Malformed JSON-family files must not crash the app, Quick Look extension, or print path. Parser diagnostics should be visible in viewer mode and source mode should always remain available as the recovery path.

## Artifacts and Notes

Expected fixture and artifact additions:

- `Fixtures/docs/json_showcase.json`
- `Fixtures/docs/jsonc_showcase.jsonc`
- `Fixtures/docs/events.ndjson`
- `Fixtures/docs/events.jsonl`
- `Fixtures/docs/markdown_json_showcase.md`
- `artifacts/checkpoints/json-viewer-macos/`
- `artifacts/checkpoints/markdown-json-viewer-macos/`
- print PDF exports under `artifacts/checkpoints/` or `artifacts/test-results/` when validating printable output

Design notes:

- Use compact indentation. Start with 14 to 16 points per nesting level in viewer mode, then adjust only if visual validation shows crowding.
- Keep gutter width stable with monospaced digits based on the largest original source line in the rendered source, not the number of visible rows.
- Collapsed containers should display a short summary such as object property count, array item count, NDJSON record number, and any diagnostic count.
- Arrays render as indexed rows rather than tables so users can collapse the array section and inspect individual nested values consistently.
- Do not add sorting, filtering, editing, schema validation, JSONPath search, or persisted collapse state in this milestone.

## Interfaces and Dependencies

New shared interfaces:

- `JSONFamilyDocumentKind`
- `JSONSourceLocation`
- `JSONSourceRange`
- `JSONToken`
- `JSONDiagnostic`
- `JSONValueNode`
- `JSONDocumentModel`
- `JSONFamilyLexer`
- `JSONFamilyParser`
- `JSONPresentationMode`
- `JSONPresentationBuilder`
- `JSONViewerRow`
- `MarkdownJSONDocument` or equivalent block payload type

Existing interfaces to update:

- `WorkspaceDocumentKind`
- `SupportedDocumentExtensions`
- `MarkdownCodeBlock`
- `MarkdownBlockKind` and/or `MarkdownBlock`
- `AppModel.blocks(for:kind:path:)`
- `DocumentPrintSection`
- `DocumentPrintComposition`
- `MarkdownBlockView`
- `PrintableDocumentCompositionView`
- `PreviewViewController`
- `Info-macOS.plist`
- `QuickLookPreview-Info.plist`

Dependencies:

- No network dependency.
- No database or migration dependency.
- No `WKWebView`, HTML/CSS/JavaScript renderer, external formatter, or subprocess.
- Reuse existing Tree-sitter JSON syntax highlighting where it fits source mode, but keep JSONC and NDJSON parsing/line mapping in repo-owned Swift code.
