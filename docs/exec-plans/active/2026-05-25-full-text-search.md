# Full Text Search

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

The app should support Preview-style text search for the selected document with `Command-F` and across all open workspace documents with `Command-Shift-F`. Search should be responsive for large workspaces, show clickable results in the left sidebar in a dedicated search tab, highlight matches in the main document, scroll to selected matches, and provide next-result navigation.

The implementation must preserve native rendering and avoid web rendering. Search indexing and matching should run off the main actor once the app has captured the workspace/file inputs.

## Progress

- [x] (2026-05-26 02:55Z) Created this dedicated ExecPlan before implementing search changes.
- [x] (2026-05-26 04:40Z) Added a shared search engine and result model with block IDs, snippets, line numbers, and document paths.
- [x] (2026-05-26 04:40Z) Wired `Command-F`, `Command-Shift-F`, and next-result commands through macOS menu/key dispatch and scene handlers.
- [x] (2026-05-26 04:40Z) Rendered clickable results in the left sidebar Search pane.
- [x] (2026-05-26 04:40Z) Added match highlighting, selected-result scroll targets, and next-result cycling.
- [x] (2026-05-26 04:40Z) Added focused unit/UI tests and ran validation.
- [x] (2026-05-26 05:11Z) Fixed result line numbers to use document-relative positions instead of block-local positions.
- [x] (2026-05-26 05:13Z) Reran focused search/sidebar checks, macOS UI checks, macOS debug build, and the full unit wrapper.

## Surprises & Discoveries

- SwiftUI `TextField` updates were not reliable enough under macOS XCTest for this sidebar search flow.
  Evidence: a small AppKit-backed `NSSearchField` bridge updates the SwiftUI binding through delegate, target/action, and key-up paths; the UI tests now observe the model query and result count after typing.

- macOS XCTest exposes SwiftUI list rows inconsistently as `Other` rather than `Button` or child `StaticText`.
  Evidence: the search result rows are now queried by stable accessibility identifiers across all element types in UI tests.

- Result line numbers all appeared as `L1` whenever each matched block had the match on its first internal line.
  Evidence: the original search engine only counted newlines inside the block's plain text; the focused unit now verifies document-relative line numbers `[1, 3, 5]` for matches in separate blocks.

## Decision Log

- Decision: Search results should reference parsed block IDs, not just raw character offsets.
  Rationale: the renderer already scrolls by block ID for outline navigation; reusing that mechanism keeps navigation native and avoids brittle pixel offsets.
  Date/Author: 2026-05-25 / Codex

- Decision: Run all-document searches from captured provider/file snapshots and cancel stale search tasks.
  Rationale: workspace search may read and parse many documents; cancellation prevents older queries from racing newer text input and keeps the main actor limited to state publication.
  Date/Author: 2026-05-25 / Codex

- Decision: Keep command verification split between unit command mapping and UI interaction through the visible Search tab.
  Rationale: macOS menu/keyboard automation is flaky in XCTest, while the command dispatcher is unit-testable and the UI tests can verify the same result rendering, clicking, scrolling, and next-result behavior through stable controls.
  Date/Author: 2026-05-25 / Codex

- Decision: Compute line numbers from the original document text after locating each parsed block's source or plain text.
  Rationale: parsed blocks are the right navigation anchors, but line labels shown to users must be relative to the full document, not the block-local snippet.
  Date/Author: 2026-05-25 / Codex

## Outcomes & Retrospective

Implemented. The sidebar now includes a Search pane with a native macOS search field, current-document/all-documents scope picker, progress state, clickable results, document-relative line labels, and next-result navigation. `Command-F` activates current-document search, `Command-Shift-F` activates all-documents search, and `Command-G` selects the next result. Selecting a result opens the target document when needed, sets the selected result, scrolls to the result block, and highlights matching rendered text in the main document.

Validation is green: unit tests cover block-anchored search results with document-relative lines, all-document search selection/next cycling, and macOS search shortcut command mapping. macOS UI tests cover current-document results excluding other files, all-document result clicking across nested paths, and next-result staying in the selected document. The full unit wrapper also passes.

## Context and Orientation

Relevant files:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`

Current behavior:

- The sidebar only has a quick file filter.
- The document scroll view can already scroll to block IDs via `documentScrollTargetID`.
- Markdown blocks carry `id`, `plainText`, and `children`, which can support match-to-block navigation.
- Command menu actions exist for print/navigation/font controls but not search.

## Plan of Work

1. Add a `DocumentSearchScope`, `DocumentSearchResult`, and nonisolated search engine that searches block text and returns snippets, line/column metadata, file path, and block ID.
2. Add `AppModel` search state: active query, active scope, result list, selected result, search status, and cancellable search task.
3. For `Command-F`, search only the selected document; for `Command-Shift-F`, search all open workspace documents.
4. Run all-document search from a captured provider/file snapshot and cancel stale searches when the query/scope changes.
5. Add a left-sidebar tab switcher for Files and Search; show search results in the Search tab.
6. Make results clickable: selecting a result opens the file if needed, scrolls to the block, and marks that match as selected.
7. Add lightweight highlighting for rendered text blocks based on the current query and selected result.
8. Add next-result navigation that cycles through results and uses the same selection path.

## Concrete Steps

1. Implement search models and block-flattening helpers in the shared app layer.
2. Add focused unit tests for case-insensitive matching, snippets, block IDs, cancellation, and all-document ordering.
3. Extend `ViewerShellView` with a Files/Search sidebar mode, search input, result list, and result selection handling.
4. Add command handlers and focused values for `Command-F`, `Command-Shift-F`, and next result.
5. Pass search query/selection into block rendering and highlight matching text in headings, paragraphs, list items, and table/code fallback text where practical.
6. Reuse the existing scroll-to-block mechanism for selected search results.
7. Add UI or harness verification for search command invocation, result selection, and highlighted/scroll target state.
8. Update docs and run focused tests plus build.

## Validation and Acceptance

Acceptance requires:

- `Command-F` opens the Search tab scoped to the current document.
- `Command-Shift-F` opens the Search tab scoped to all open documents.
- Search remains responsive for large workspaces by cancelling stale background searches.
- Results show file title, line/snippet context, and are clickable.
- Selecting a result opens the correct document, highlights matching text, and scrolls to the match block.
- Next result cycles through matches and scrolls/highlights each selected result.
- No search path uses `WKWebView`, HTML, CSS, or JavaScript.
- Focused unit tests, UI/harness verification, macOS debug build, `python3 scripts/check_execplan.py`, and `python3 scripts/knowledge/check_docs.py` pass.

## Idempotence and Recovery

Search state is transient UI/model state and does not write user files. If the all-document path has a regression, the single-document scope can remain enabled while workspace search is temporarily disabled behind the command handler.

## Artifacts and Notes

Commands planned:

- `xcodebuild -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath artifacts/DerivedData -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' -only-testing:"Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/<new search tests>" test`
- `./scripts/test-ui-macos --smoke`
- `./scripts/build --platform macos`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`

## Interfaces and Dependencies

- `WorkspaceProvider` supplies file reads for workspace search after the main actor captures the provider and file list.
- `MarkdownBlock.id` supplies scroll targets.
- `DocumentBlockScrollView` owns scroll-to-block behavior.
- Search UI stays in SwiftUI; platform-specific command wiring stays at the scene/menu layer.
