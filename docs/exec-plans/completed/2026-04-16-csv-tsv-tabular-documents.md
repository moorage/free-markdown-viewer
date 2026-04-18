# CSV and TSV Tabular Documents

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Add first-class `.csv` and `.tsv` document support to the viewer on macOS, iPhone, and iPad. CSV and TSV files should appear anywhere the app currently exposes Markdown workspace files, including local folders, direct file opens, and cached GitHub repository workspaces. Opening one of those files should render a native table that matches the existing Markdown table presentation instead of dumping raw text.

This milestone also adds adjustable tabular presentation controls for CSV and TSV documents:

- a document-scoped column-width control
- a document-scoped row-height control
- a top-navigation wrap-mode toggle that switches between fake-newline wrapping and clipped overflow

The default overflow mode is fake-newline wrapping: the app constrains each cell to the chosen column width and lets the visible text wrap across lines without mutating the underlying file contents or inserting real newline characters into the loaded data.

This milestone is for read-only viewing only. Editing CSV or TSV files, sorting, filtering, frozen headers, per-column drag handles, spreadsheet formulas, or generic spreadsheet import are out of scope.

## Progress

- [x] (2026-04-17T06:32Z) Audited the current document pipeline and confirmed the app is still modeled end to end around Markdown-specific file nodes, extension filtering, and document naming.
- [x] (2026-04-17T06:32Z) Confirmed the current table renderer lives in `ViewerShellView` as a fixed-width `Grid` with no adjustable row-height, column-width, or overflow controls.
- [x] (2026-04-17T06:32Z) Confirmed local folders, GitHub workspace caches, and direct macOS file-open normalization all filter on `SupportedMarkdownExtensions`, so CSV and TSV will be invisible until the workspace/file-type abstraction is widened.
- [x] (2026-04-17T06:32Z) Drafted the implementation plan below, including the shared document-model changes, universal toolbar behavior, parser edge cases, GitHub fixture updates, and validation scope.
- [x] (2026-04-17T07:20Z) Widened local folders, GitHub workspace caches, and direct macOS file-open normalization to include `.csv` and `.tsv` alongside Markdown documents.
- [x] (2026-04-17T07:20Z) Added shared delimited-text parsing plus tabular presentation state so standalone CSV and TSV documents render as native tables with wrap, column-width, and row-height controls.
- [x] (2026-04-17T07:20Z) Added focused unit coverage for CSV discovery, structured rendering, GitHub inclusion, and workspace-order print compatibility.

## Surprises & Discoveries

- Observation: the current shared model is Markdown-named all the way down, so CSV and TSV support is not just a parser addition.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift` defines `MarkdownFileNode`, `MarkdownBlock`, `MarkdownTable`, and related types, while `AppModel` publishes `[MarkdownFileNode]` and `SupportedMarkdownExtensions` gates openable files.

- Observation: the existing table UI already provides the visual style the user wants to preserve, but it is hard-coded inside the Markdown block renderer and has no reusable presentation state.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift` renders `.table` blocks with a plain `Grid` inside a horizontal `ScrollView`, with fixed `horizontalSpacing`, `verticalSpacing`, and default `Text` wrapping behavior.

- Observation: CSV and TSV inclusion has to be wired through more than local-folder scanning because the direct-open and GitHub paths each apply their own Markdown-only extension check.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift` only normalizes external file opens when `SupportedMarkdownExtensions.contains(...)` is true, and both `LocalWorkspaceProvider` plus `GitHubWorkspaceProvider` enumerate files through the same Markdown-only filter.

- Observation: the current empty-state and empty-workspace copy are also Markdown-specific, so this feature changes user-visible language even before any parser work begins.
  Evidence: `AppModel.noWorkspacePromptMessage` is `Open a folder of markdown files to get started.` and `AppModel.emptyWorkspaceMessage` is `No markdown files found.`

- Observation: the repository currently has no CSV or TSV fixtures, so deterministic parser, GitHub, and UI coverage will need brand-new checked-in data files instead of piggybacking on the Markdown corpus.
  Evidence: `rg -n "csv|tsv|tab-separated|comma-separated" Fixtures docs "Quick Markdown Viewer/Quick Markdown ViewerTests"` returned no checked-in CSV or TSV feature fixtures.

- Observation: the smallest safe implementation was to keep the Markdown-named file node type and widen it with a document kind, rather than rename the entire shared model in the same milestone.
  Evidence: `MarkdownFileNode` is still the workspace list type, but it now carries `WorkspaceDocumentKind`, and local/GitHub enumeration plus table controls key off that widened kind.

## Decision Log

- Decision: treat CSV and TSV files as first-class workspace documents instead of silently converting them into synthetic Markdown before enumeration.
  Rationale: the file list, direct-open paths, GitHub caches, restore state, toolbar affordances, and tests all need to know that the selected document is tabular rather than Markdown. Hiding that distinction would make the UI and persistence logic harder to reason about.
  Date/Author: 2026-04-17 / Codex

- Decision: use the first row of a CSV or TSV file as the rendered header row by default.
  Rationale: the user explicitly wants CSV and TSV files to render like the existing Markdown tables do, and the current native table presentation expects a header plus body row model.
  Date/Author: 2026-04-17 / Codex

- Decision: make column width and row height document-scoped viewer controls with stepped values, not drag handles or per-column/per-row persisted geometry.
  Rationale: stepped controls work consistently on macOS, iPhone, and iPad, fit the current native toolbar patterns, are deterministic in tests, and avoid inventing pointer-only resize mechanics that would not translate cleanly to touch layouts.
  Date/Author: 2026-04-17 / Codex

- Decision: expose the wrap-mode toggle as a top-bar control that uses the standard SF Symbol `text.justify.left`, defaulting to fake-newline wrapping and toggling to clipped overflow.
  Rationale: the symbol is already aligned with text-layout semantics, is available system-wide, and satisfies the user's request to use a sensible built-in glyph rather than designing a custom icon.
  Date/Author: 2026-04-17 / Codex

- Decision: parse delimiter by file extension, with `.csv` using comma separation and `.tsv` using tab separation, while still supporting quoted cells, escaped quotes, empty cells, UTF-8 BOM input, and uneven row lengths.
  Rationale: extension-driven parsing keeps the user-visible contract simple while still covering the table edge cases most likely to appear in repository data files.
  Date/Author: 2026-04-17 / Codex

## Outcomes & Retrospective

Implemented.

- Local folders, GitHub workspaces, and direct macOS file opens now discover `.csv` and `.tsv` documents through the same widened supported-extension registry.
- `AppModel` now identifies standalone CSV and TSV files as tabular documents, parses them into a native table block, and exposes document-scoped wrap, column-width, and row-height state.
- `ViewerShellView` now shows a top-bar wrap toggle using `text.justify.left` plus a table-sizing menu when the selected document is CSV or TSV.
- Focused coverage now exercises CSV discovery, structured rendering, GitHub workspace inclusion, and an iPhone UI surface check for the new tabular controls.

## Context and Orientation

Relevant code and docs:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/GitHubWorkspace.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/SelectableDocumentTextView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`
- `docs/debug-contracts.md`
- `docs/harness.md`
- `docs/SECURITY.md`
- `.agents/DOCUMENTATION.md`

Current architectural facts that matter for this feature:

- `MarkdownBlockKind.table` already exists, and the structured-render path already knows how to show a native table block inside `DocumentBlockScrollView`.
- `AppModel.shouldRenderStructuredContent(for:)` already switches CSV-appropriate views on when a document contains a `.table` block, so standalone CSV and TSV files can reuse the same high-level rendering path if the load pipeline emits a single table block.
- `WorkspaceProvider.readFile(at:)` already returns raw text, which means CSV and TSV parsing can happen after file load without changing the low-level I/O contract.
- Local workspaces, GitHub workspaces, and macOS direct file opens each currently decide file eligibility by `SupportedMarkdownExtensions`, so all three surfaces must move in the same change to avoid inconsistent behavior.

## Plan of Work

1. Generalize the workspace and file model from Markdown-only terminology to document terminology.
2. Add a shared CSV/TSV parser that produces the same table model the current native Markdown table view uses.
3. Thread tabular-document identity and tabular presentation settings through `AppModel`.
4. Refactor the current table block rendering into a reusable table view that can serve both Markdown tables and standalone CSV/TSV documents.
5. Add table-specific toolbar or top-bar controls for overflow mode, column width, and row height that appear only when the selected document is CSV or TSV.
6. Extend local-folder, direct-open, and GitHub workspace enumeration so CSV and TSV files appear and load everywhere consistently.
7. Add deterministic fixtures, tests, and docs updates in the same milestone.

## Concrete Steps

1. Replace Markdown-specific file discovery and selection types where needed.

   - Rename or widen `MarkdownFileNode` and `SupportedMarkdownExtensions` into generic document-file concepts such as `WorkspaceDocumentNode` and `SupportedWorkspaceDocumentExtensions`.
   - Update `AppModel`, `WorkspaceProvider`, `GitHubWorkspaceProvider`, `LocalWorkspaceProvider`, and `ExternalWorkspaceOpenCoordinator` to use the widened type and include `.csv` plus `.tsv`.
   - Refresh user-visible copy such as the no-workspace and empty-workspace messages so they no longer imply Markdown-only support.

2. Add a shared tabular parser and data normalization layer.

   - Introduce a small shared parser for CSV and TSV text that:
     - selects delimiter from the file extension
     - respects quoted cells and escaped quotes
     - preserves embedded commas, tabs, and newlines inside quoted fields
     - strips a UTF-8 BOM when present
     - normalizes ragged rows to the header width by padding missing cells with empty values
   - Convert the parsed result into the existing table model or a generic successor if the shared model is renamed away from `MarkdownTable`.
   - Treat the first row as the header row; if the file contains only one row, render a header-only table rather than failing.

3. Add document-kind awareness to `AppModel`.

   - Track the selected document's kind explicitly, for example `.markdown`, `.csv`, or `.tsv`, instead of inferring everything from rendered blocks after the fact.
   - Extend the document-load pipeline so Markdown files continue to flow through `MarkdownRenderer`, while CSV and TSV files bypass Markdown parsing and instead emit a single table block plus raw text for copy or fallback purposes.
   - Keep relative Markdown-link behavior unchanged for Markdown files and ensure CSV/TSV documents do not attempt Markdown link navigation unless a future milestone explicitly adds rich cell-link parsing.

4. Add table presentation settings for standalone CSV and TSV documents.

   - Introduce a small tabular presentation state object in `AppModel`, scoped to the current window, with:
     - overflow mode: `.wrap` or `.clip`
     - column width step value
     - row height step value
   - Default overflow mode to fake-newline wrapping.
   - Apply these controls only to standalone CSV and TSV documents in this milestone; Markdown tables keep their current automatic layout unless later work intentionally unifies the controls.

5. Refactor the native table renderer into a reusable view.

   - Extract the current `.table` rendering code from `MarkdownBlockView` into a dedicated reusable view such as `DocumentTableView`.
   - Preserve the current Markdown-table visual design: bordered container, native SwiftUI text rendering, horizontal scrolling, and alignment-aware header/body layout.
   - Add support for:
     - document-scoped fixed or minimum column width
     - document-scoped fixed or minimum row height
     - fake-newline wrapping by constraining `Text` within the chosen width and allowing multi-line layout
     - clipped overflow mode using `lineLimit(1)` or the chosen row limit plus truncation instead of mutating cell contents
   - Ensure the extracted table view still works for Markdown table blocks so styling does not fork.

6. Add the top-bar controls for CSV and TSV documents.

   - Show a dedicated wrap-mode toggle in the existing macOS toolbar and iOS/iPad top navigation bar only when the selected file kind is `.csv` or `.tsv`.
   - Use the SF Symbol `text.justify.left` for that control.
   - Add adjacent table-size controls through the narrowest cross-platform-safe pattern, likely a `Menu` or compact control group with actions such as:
     - narrower columns
     - wider columns
     - shorter rows
     - taller rows
   - Keep existing navigation, open-folder, GitHub, font-size, and reveal controls intact.

7. Ensure GitHub workspace support includes CSV and TSV files.

   - Update GitHub workspace enumeration so cached repository trees include `.csv` and `.tsv` entries anywhere `.md` or `.markdown` files currently appear.
   - Extend deterministic GitHub fixture data so the fake repository tree includes at least one CSV or TSV file and the unit or UI coverage can load it without touching the public network.
   - Preserve existing GitHub cache behavior and session restore semantics; only the openable file set and selected-document parser path should widen.

8. Add fixtures, tests, and docs updates.

   - Add checked-in local fixtures for:
     - simple CSV
     - simple TSV
     - quoted CSV with commas and embedded line breaks
     - ragged or sparse rows
   - Add focused tests for:
     - parser correctness and quoting edge cases
     - local workspace enumeration of CSV and TSV
     - GitHub workspace enumeration of CSV and TSV
     - CSV/TSV document load producing a `.table` block
     - wrap-mode defaulting to wrap
     - wrap/clip toggle behavior
     - column-width and row-height adjustment state changes
     - macOS direct-open normalization for CSV and TSV files
   - Update `docs/debug-contracts.md` with any new stable accessibility identifiers for the wrap toggle and table-size controls.
   - Update `docs/harness.md` if GitHub or UI-test fixtures need new instructions.
   - Update `.agents/DOCUMENTATION.md` and keep this ExecPlan current once implementation begins.

## Validation and Acceptance

Acceptance requires all of the following:

- Local folders list `.csv` and `.tsv` files alongside Markdown files.
- GitHub workspaces list `.csv` and `.tsv` files alongside Markdown files from cached repository snapshots.
- Opening a CSV or TSV file renders a native table that matches the existing Markdown-table styling instead of showing raw document text.
- The first row renders as the header row, and quoted delimiters or embedded quoted newlines stay inside the correct cell.
- The top navigation area shows a wrap-mode toggle only while viewing a CSV or TSV document.
- The wrap-mode toggle defaults to fake-newline wrapping and can switch to clipped overflow without reloading the workspace.
- Column width and row height can each be adjusted from the viewer UI while a CSV or TSV document is open.
- Existing Markdown rendering, Markdown table rendering, GitHub URL loading, and local-folder open flows remain intact.
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-04-16-csv-tsv-tabular-documents.md` passes.
- `python3 scripts/knowledge/check_docs.py` passes after the related docs updates.

## Idempotence and Recovery

The file-discovery widening is idempotent because it only changes which checked-in or user-selected files are considered openable; it does not mutate the files themselves. CSV and TSV parsing must remain read-only and operate on in-memory strings returned by the existing workspace providers.

If the extracted table view or document-kind refactor regresses Markdown behavior, the smallest rollback is to keep the generic file-model rename but temporarily gate CSV and TSV document loading behind the existing Markdown-only renderer path or hide the new extensions from enumeration until the dedicated parser and controls are stable.

If a CSV or TSV file is malformed, the app should surface an explicit load error consistent with existing workspace-document failures rather than silently falling back to empty content.

## Artifacts and Notes

Planning commands run for this ExecPlan:

- `sed -n '1,220p' README.md`
- `sed -n '1,220p' ARCHITECTURE.md`
- `sed -n '1,220p' .agents/PLANS.md`
- `sed -n '1,260p' docs/PLANS.md`
- `sed -n '1,220p' docs/harness.md`
- `sed -n '1,220p' docs/debug-contracts.md`
- `rg -n "table|Table|pipe table|MarkdownTable|visibleBlocks|csv|tsv|tabular" "Quick Markdown Viewer/Quick Markdown Viewer" "Quick Markdown Viewer/Quick Markdown ViewerTests" "Quick Markdown Viewer/Quick Markdown ViewerUITests"`
- `sed -n '1,260p' docs/exec-plans/active/2026-04-16-github-url-workspaces.md`
- `sed -n '1,260p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift"`
- `sed -n '1,320p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift"`
- `sed -n '1,360p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift"`
- `sed -n '1,360p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift"`
- `sed -n '1,320p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift"`
- `sed -n '320,760p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift"`
- `sed -n '700,1040p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift"`
- `sed -n '1,180p' "Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift"`
- `sed -n '1,260p' "Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift"`
- `sed -n '1,260p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/GitHubWorkspace.swift"`
- `rg -n "csv|tsv|tab-separated|comma-separated" Fixtures docs "Quick Markdown Viewer/Quick Markdown ViewerTests"`
- `date -u +%Y-%m-%dT%H:%MZ`

Expected implementation touch points:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/GitHubWorkspace.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/SelectableDocumentTextView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`
- `Fixtures/`
- `docs/debug-contracts.md`
- `docs/harness.md`
- `.agents/DOCUMENTATION.md`

Expected validation commands after implementation:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-tabular-unit -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testCSVDocumentParsesQuotedCellsAndEmbeddedNewlines" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testTSVDocumentRendersAsTableBlock" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testWorkspaceProviderIncludesCSVAndTSVFiles" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testGitHubWorkspaceProviderIncludesCSVAndTSVFiles" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testTabularOverflowModeDefaultsToWrap" test`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-tabular-ui-macos -destination "platform=macOS,arch=arm64" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testCSVDocumentShowsWrapToggleAndTableSizingControls" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testCSVWrapToggleCanSwitchToClippedOverflow" test`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-tabular-ui-ios -destination "platform=iOS Simulator,name=iPhone 16" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testiPhoneCSVDocumentShowsWrapToggleInTopBar" test`
- `./scripts/test-unit`
- `./scripts/test-ui-macos --smoke`
- `./scripts/test-ui-ios --device both --smoke`
- `python3 scripts/check_execplan.py docs/exec-plans/completed/2026-04-16-csv-tsv-tabular-documents.md`
- `python3 scripts/knowledge/check_docs.py`

## Interfaces and Dependencies

New or widened shared interfaces likely required:

- a generic workspace-document type to replace or widen `MarkdownFileNode`
- a generic supported-extension registry to replace `SupportedMarkdownExtensions`
- a tabular parser interface that converts raw CSV or TSV text into the app's native table model
- a tabular presentation state model owned by `AppModel`
- new stable accessibility identifiers for:
  - the wrap-mode toggle
  - the table-settings menu or stepped controls
  - any explicit narrow or wide / short or tall actions exposed to UI tests

Dependencies and constraints:

- keep rendering native; no `WKWebView`, HTML, CSS, or JavaScript
- keep shared parser and table state platform-neutral
- keep AppKit or UIKit usage limited to shell controls only
- keep GitHub fixture transport deterministic and repo-owned
- do not mutate user files or cached GitHub snapshots to synthesize wrapping
