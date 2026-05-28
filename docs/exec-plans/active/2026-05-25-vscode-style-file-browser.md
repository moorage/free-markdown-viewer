# VSCode-Style File Browser

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

The left drawer should behave like a compact code-editor file explorer instead of a flat list. Folders can expand and collapse, keyboard users can navigate with arrow keys, and path chains that only contain empty/intermediate folders collapse into one visible row such as `emptyfolder / fullfolder`. Empty folders should not appear as standalone rows because they do not open anything and add noise.

The result should preserve the current quick filter, selected-file opening, accessibility identifiers, and sidebar ordering while making hierarchy discoverable for large workspaces.

## Progress

- [x] (2026-05-26 02:55Z) Created this dedicated ExecPlan before implementing the drawer changes.
- [x] (2026-05-26 04:40Z) Implemented a reusable file tree model with collapsed single-child directory chains.
- [x] (2026-05-26 04:40Z) Replaced the flat sidebar list with expandable folder/file rows while preserving file selection and quick filtering.
- [x] (2026-05-26 04:40Z) Added macOS arrow-key expand/collapse/navigation behavior scoped to the Files sidebar.
- [x] (2026-05-26 04:40Z) Added focused unit coverage and macOS UI verification; validation is green.
- [x] (2026-05-26 05:11Z) Replaced per-render tree reconstruction with a cached sidebar tree snapshot and row-ID cache for large workspaces.
- [x] (2026-05-26 05:13Z) Reran focused sidebar/search checks, macOS UI checks, macOS debug build, and the full unit wrapper.
- [x] (2026-05-26 05:16Z) Split folder focus styling from viewed-document selection styling so folder navigation no longer creates two identical selected rows.
- [x] (2026-05-26 05:22Z) Removed the visible `Sidebar` picker label and added icons to the Files/Search tabs.
- [x] (2026-05-26 05:51Z) Replaced the sidebar mode segmented picker with custom icon button tabs and removed the tab strip's opaque system-background fill.

## Surprises & Discoveries

- SwiftUI focus handling on macOS can let a sidebar-local key bridge steal typing from the AppKit-backed search field if the bridge remains enabled outside the Files pane.
  Evidence: the search UI test initially typed into the app without updating the search model until the key bridge was gated by active pane/focus state.

- Switching back from Search to Files could beachball on large workspaces because `visibleSidebarRows` rebuilt and sorted the full tree, and selection checks scanned the visible rows during SwiftUI rendering.
  Evidence: the shell now keeps a `SidebarFileTree.Snapshot` plus a visible row-ID set, and a 5,000-file focused unit test expands a large folder using the cached structure.

- Folder rows and document rows need different selected affordances because only document rows correspond to content displayed in the detail pane.
  Evidence: the viewed file row keeps the filled accent selection, while a focused folder now renders as a gray outlined navigation cursor with accent text/icon.

- SwiftUI's segmented `Picker` flattened the `Label` icon content in the sidebar mode tabs, and the explicit `windowBackgroundColor`/`systemBackground` fill behind it created an unintended white strip in the side pane.
  Evidence: the Files/Search switcher now uses explicit `Button` labels with visible SF Symbols and no pane-wide background fill.

## Decision Log

- Decision: Keep the source `AppModel.files` flat and derive the visible tree in the shell/model layer.
  Rationale: file loading, print ordering, and harness snapshots already rely on the flat list; the drawer only needs a presentation tree.
  Date/Author: 2026-05-25 / Codex

- Decision: Collapse single-child folder chains in `SidebarFileTree` rather than mutating workspace paths.
  Rationale: the UI can render `emptyfolder / fullfolder` as a compact row while opening, printing, search, and harness behavior continue to use the original `WorkspacePath`.
  Date/Author: 2026-05-25 / Codex

- Decision: Scope arrow-key interception to the Files pane.
  Rationale: the left drawer now has both file and search modes; search text input must not be affected by folder navigation key handling.
  Date/Author: 2026-05-25 / Codex

- Decision: Cache the derived sidebar tree independently from the visible expanded rows.
  Rationale: file changes and quick-filter changes require rebuilding the tree, but expand/collapse and Files/Search pane switching only need to walk the existing immutable snapshot.
  Date/Author: 2026-05-25 / Codex

- Decision: Treat folder rows as focus/navigation targets, not document selections.
  Rationale: macOS/iOS source-list convention reserves the strong selected fill for the item driving the detail pane; folders that only expand/collapse should use a lighter focus treatment to avoid implying two active documents.
  Date/Author: 2026-05-25 / Codex

- Decision: Use a small custom two-button tab strip for Files/Search instead of a segmented `Picker`.
  Rationale: the segmented picker was not reliably rendering icons on macOS and required an opaque backing. The custom buttons keep the tab behavior, expose stable accessibility IDs, and render the icons directly.
  Date/Author: 2026-05-26 / Codex

## Outcomes & Retrospective

Implemented. The left drawer now has an icon-labeled Files/Search switcher without a redundant visible picker label or opaque white backing, and the Files pane renders a derived tree with disclosure rows, compacted folder chains, hidden empty-only folders, selected file highlighting, lighter focused-folder styling, and keyboard navigation. Right arrow expands a collapsed folder, left arrow collapses an expanded folder or walks back to its parent, and up/down moves through visible rows and opens files consistently. Large-workspace switching and expansion now reuse a cached tree snapshot instead of reparsing and sorting every path during view rendering.

Validation is green for the implemented file-browser model and build surfaces: unit tests cover collapsed folder-chain derivation, visible-row navigation, and a 5,000-file large-folder expansion through `SidebarFileTree.Snapshot`; the macOS UI test expands/collapses `emptyfolder / fullfolder` with pointer and arrow keys and verifies the nested file opens. For the tab-strip follow-up, the macOS app build and UI-test build-for-testing pass; the local focused UI-test execution was blocked by `Quick Markdown ViewerUITests-Runner` exiting before bootstrapping, before it connected to the app.

## Context and Orientation

Relevant files:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/MacSidebarKeyEventBridge.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`

Current behavior:

- `ViewerShellView.sidebarContent` renders `List(filteredFiles)`.
- `filteredFiles` calls `AppModel.filteredFiles(from:matching:)`.
- Up/down keyboard movement selects adjacent flat files through `AppModel.adjacentFilePath`.
- The sidebar has no directory rows, no expanded-state model, and no left/right arrow behavior.

## Plan of Work

1. Add a small platform-neutral sidebar tree type that derives visible rows from `[MarkdownFileNode]`, quick-filter text, and a set of expanded folder IDs.
2. Collapse directory chains with no sibling files/folders into one folder row label joined by ` / `.
3. Hide leafless folders by construction because the workspace provider only returns supported file nodes.
4. Keep search/filter behavior pragmatic: when filtering, include matching files and their parent folder chain, auto-expanding matching ancestors.
5. Wire row taps: folders toggle expansion, files open documents.
6. Extend the macOS key bridge or move-command handler so left/right arrows collapse/expand folders and enter selected folders/files consistently.
7. Add unit tests for tree derivation, path collapsing, filtering, visible row ordering, and keyboard target calculations.
8. Add at least one UI/harness verification for expandable drawer behavior.

## Concrete Steps

1. Introduce `SidebarFileTree` with typed row IDs for folder rows and file rows.
2. Add helper methods for visible rows, row after/before current selection, and folder expansion state updates.
3. Replace `List(filteredFiles)` with `List(visibleSidebarRows)`.
4. Update row rendering to show disclosure icons, indentation, collapsed folder-chain names, file names, and selection highlight.
5. Add keyboard handlers for up/down/left/right, including focus preservation.
6. Preserve existing sidebar accessibility IDs and add folder/file row IDs where tests need stable selectors.
7. Update docs and run the focused unit/UI checks plus build.

## Validation and Acceptance

Acceptance requires:

- Top-level and nested folders can expand and collapse with pointer and keyboard.
- Right arrow expands a selected collapsed folder; left arrow collapses an expanded folder or moves focus to its parent.
- Empty/intermediate folder chains render as one row label like `emptyfolder / fullfolder`.
- Standalone empty folders do not appear.
- Quick filter still opens matching documents and does not require manually expanding every ancestor.
- Existing file opening and print ordering remain unchanged.
- Focused unit tests, macOS UI verification, `./scripts/build --platform macos`, `python3 scripts/check_execplan.py`, and `python3 scripts/knowledge/check_docs.py` pass.
- Focused unit tests, macOS UI verification, macOS debug build, `python3 scripts/check_execplan.py`, and `python3 scripts/knowledge/check_docs.py` pass.

## Idempotence and Recovery

The change derives drawer state from the existing flat file list, so rollback can restore the flat `List(filteredFiles)` rendering without changing document loading or workspace providers. Expanded folder IDs are UI state only and do not alter user files.

## Artifacts and Notes

Commands planned:

- `xcodebuild -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath artifacts/DerivedData -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' -only-testing:"Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/<new tree tests>" test`
- `./scripts/test-ui-macos --smoke`
- `./scripts/build --platform macos`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`

Commands run for the tab-strip follow-up:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-sidebar-tabs-build -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build`
- `open -n "/tmp/qmv-sidebar-tabs-build/Build/Products/Debug/Quick Markdown Viewer.app" --args --fixture-root "/Users/matthewmoore/Projects/free-markdown-viewer/Fixtures/docs" --open-file "basic_typography.md" --ui-test-mode "1"`
- `osascript ... tell process "Quick Markdown Viewer" ...`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-sidebar-tabs-bft -destination "platform=macOS,arch=arm64" DEVELOPMENT_TEAM=GG34PA8F4A build-for-testing`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-sidebar-tabs-ui -destination "platform=macOS,arch=arm64" DEVELOPMENT_TEAM=GG34PA8F4A "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testSearchCurrentDocumentFindsMatchesAndNextResultStaysInDocument" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testSearchAllDocumentsFindsMatchesAndOpensClickedResult" test`

## Interfaces and Dependencies

- `MarkdownFileNode` remains the canonical workspace file identity.
- `WorkspacePath` raw values provide slash-separated path segments.
- macOS-specific keyboard event interception stays in `MacSidebarKeyEventBridge`.
- No AppKit code should enter shared model/tree derivation.
