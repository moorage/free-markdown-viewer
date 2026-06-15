# Nested Header Breadcrumbs

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

The viewer header and macOS window title should show the selected document's full workspace-relative path. A file at `docs/tutorials/getting-started.md` should render as `Root Folder > docs > tutorials > getting-started.md`, not just `Root Folder > getting-started.md`.

The change should preserve the existing root-folder title when no file is selected, keep filename-only labels where the app uses them for search and print sections, and work for both local folders and cached GitHub workspaces.

## Progress

- [x] (2026-06-15T06:55Z) Created this focused ExecPlan after confirming `AppModel.windowTitle` was collapsing selected paths to the filename.
- [x] (2026-06-15T06:55Z) Updated `AppModel.windowTitle` to format all selected `WorkspacePath` components as header breadcrumbs.
- [x] (2026-06-15T06:55Z) Added regression coverage for local nested files and restored GitHub repo-root files.
- [x] (2026-06-15T07:15Z) Ran focused macOS unit tests for root-level titles, nested local titles, restored GitHub titles, and nested GitHub titles; all passed.
- [x] (2026-06-15T07:16Z) Ran full unit wrapper plus ExecPlan/docs/whitespace checks; all passed.

## Surprises & Discoveries

- Observation: the existing `selectedFileDisplayName` helper is still correct for search result labels and should not become a breadcrumb formatter.
  Evidence: `AppModel.performSearch()` passes `selectedFileDisplayName` to `DocumentSearchEngine.results(...)` as the display file name.

## Decision Log

- Decision: Format the full header path directly in `windowTitle` by splitting the canonical `WorkspacePath.rawValue` on `/`.
  Rationale: workspace providers already normalize local and GitHub file identities as slash-separated relative paths, so no filesystem or URL work is needed for this UI label.
  Date/Author: 2026-06-15 / Codex

## Outcomes & Retrospective

Implemented. The header and macOS window title now include every selected workspace-relative path component while leaving sidebar, search, print, and workspace enumeration behavior unchanged. Focused unit coverage verifies root-level titles still render as before, and nested local plus GitHub paths render as breadcrumbs.

## Context and Orientation

Relevant files:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/AppRootView.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`

Current behavior:

- `ViewerShellView` and `AppRootView` read `model.windowTitle`.
- `AppModel.windowTitle` previously returned `workspaceRootDisplay > selectedFileDisplayName`.
- `selectedFileDisplayName` intentionally keeps only the last path component.

## Plan of Work

1. Keep `selectedFileDisplayName` filename-only.
2. Change `windowTitle` to derive a breadcrumb from `selectedPath.rawValue`.
3. Add local workspace coverage for a nested selected file.
4. Add GitHub workspace coverage for a restored nested selected file.
5. Run focused unit tests plus ExecPlan/docs validation.

## Concrete Steps

1. Update `AppModel.windowTitle`.
2. Extend `Quick_Markdown_ViewerTests` with nested local and GitHub title assertions.
3. Update `.agents/DOCUMENTATION.md`.
4. Run focused `xcodebuild` tests for the added and adjacent title cases.
5. Run `python3 scripts/check_execplan.py docs/exec-plans/active/2026-06-15-nested-header-breadcrumbs.md` and `python3 scripts/knowledge/check_docs.py`.

## Validation and Acceptance

Acceptance requires:

- Root-level selected files still render as `Root Folder > filename`.
- Nested local selected files render every component as `Root Folder > subfolder > filename`.
- Nested GitHub selected files render every workspace-relative component after the GitHub display root.
- No file loading, sidebar ordering, print composition, or search label behavior changes.
- Focused unit tests and docs validation pass.

## Idempotence and Recovery

The change is a pure display transformation over `selectedPath.rawValue`. Rollback can restore the previous `workspaceRootDisplay > selectedFileDisplayName` expression without affecting persisted workspace state, cached GitHub content, or user files.

## Artifacts and Notes

Commands planned:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-nested-title-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testWindowTitleUsesWorkspaceFolderAndFilename" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testWindowTitleIncludesNestedFolderPath" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testRestoredGitHubWorkspaceSessionUsesCachedSnapshot" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testRestoredGitHubWorkspaceTitleIncludesNestedFolderPath" test`
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-06-15-nested-header-breadcrumbs.md`
- `python3 scripts/knowledge/check_docs.py`

Commands run:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-nested-title-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testWindowTitleUsesWorkspaceFolderAndFilename" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testWindowTitleIncludesNestedFolderPath" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testRestoredGitHubWorkspaceSessionUsesCachedSnapshot" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testRestoredGitHubWorkspaceTitleIncludesNestedFolderPath" test`
  Result: passed; Xcode emitted existing macOS 13.0 deployment target warnings while linking XCTest libraries built for macOS 14.0.
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-06-15-nested-header-breadcrumbs.md`
  Result: passed.
- `python3 scripts/knowledge/check_docs.py`
  Result: passed.
- `git diff --check`
  Result: passed.
- `./scripts/test-unit`
  Result: passed; result bundle written to `artifacts/xcodebuild/test-unit.xcresult`.

## Interfaces and Dependencies

- `WorkspacePath.rawValue` remains the canonical workspace-relative document identity.
- `AppModel.windowTitle` remains the single title source for visible header text, `nav.title`, and the macOS window title.
- `selectedFileDisplayName` remains filename-only for contexts that need a compact file label.
