# Window Ignore Patterns

## Purpose / Big Picture

Each app window should own its own comma-separated workspace ignore pattern list. New windows default to hiding common dependency and vendored directories (`node_modules`, `venv`, `.venv`, and `vendor`), and users can change the patterns from an eye button in that window's chrome. Applying changes reloads that window's file list without changing other windows.

## Progress

- [x] (2026-05-11T17:00Z) Confirmed local workspace enumeration is centralized in `LocalWorkspaceProvider`, while each window already owns its own `AppModel` and restoration session.
- [x] (2026-05-11T17:00Z) Implemented shared ignore-pattern parsing, default values, and directory pruning during local and cached GitHub workspace enumeration.
- [x] (2026-05-11T17:00Z) Persisted ignore patterns in `WorkspaceWindowSession` so restored windows keep their own setting.
- [x] (2026-05-11T17:00Z) Added the eye-button UI and native sheet/modal editor on macOS, iPhone, and iPad.
- [x] (2026-05-11T18:39Z) Added targeted unit tests and validated with docs checks, macOS unit tests, and all-platform builds.

## Surprises & Discoveries

- The working tree already had unrelated changes in `.agents/DOCUMENTATION.md`, `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`, and an app-store resubmission ExecPlan move before this work began. This plan and implementation will not modify those files.

## Decision Log

- Decision: Keep ignore settings on `AppModel`, not in global preferences.
  Rationale: The user requested per-window behavior, and this repository already scopes workspace state per window.
- Decision: Treat comma entries as path-component/path patterns, with exact matching for normal names and simple `*`/`?` wildcard support.
  Rationale: Defaults like `node_modules` should hide directories anywhere in the tree, while wildcard support preserves the user's "pattern" expectation without introducing a larger rules engine.

## Outcomes & Retrospective

The feature is implemented as window-scoped state on `AppModel`. Local and cached GitHub workspace providers share the same ignore matcher, default to ignoring `node_modules`, `venv`, `.venv`, and `vendor`, and prune matching directories during enumeration. The eye button opens a native SwiftUI sheet on macOS, iPhone, and iPad where users can apply or reset comma-separated patterns. Applying changes reloads only the active window and session restoration preserves the selected ignore list.

## Context and Orientation

Relevant code:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift` owns local and cached GitHub file enumeration.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift` owns per-window workspace state and reloads.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceWindowSessionStore.swift` persists window sessions.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift` renders toolbar and mobile top-bar controls.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift` owns sheets and modal presentation.

## Plan of Work

1. Add a small shared value type for parsing, display, and matching ignore patterns.
2. Pass the ignore settings into local and GitHub workspace providers and prune ignored directories during enumeration.
3. Expose model methods for updating the comma-separated list and reloading the active workspace.
4. Persist ignore patterns through `WorkspaceWindowSession`.
5. Add a sheet opened by an eye toolbar/top-bar button using existing SwiftUI presentation patterns.
6. Add unit tests for default ignores, custom ignores, and session restoration.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Edit shared app model/provider/session files.
2. Edit shell views and accessibility IDs.
3. Add tests in `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`.
4. Run `python3 scripts/check_execplan.py`.
5. Run targeted unit tests for workspace provider and app model ignore behavior.

Validation completed from `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. `python3 scripts/check_execplan.py`
2. `python3 scripts/knowledge/check_docs.py`
3. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath artifacts/DerivedData -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testNestedFixtureDocumentResolvesInlineImageRelativeToDocumentDirectory" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testWorkspaceProviderIgnoresDefaultDependencyDirectories" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testWorkspaceProviderUsesCustomIgnorePatterns" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppModelReloadsCurrentWindowWhenIgnorePatternsChange" test`
4. `./scripts/test-unit`
5. `./scripts/build --platform all`

## Validation and Acceptance

Acceptance:

- New local workspaces hide Markdown/CSV/TSV documents under `node_modules`, `venv`, `.venv`, and `vendor` by default.
- Users can open an ignore-pattern sheet/modal from an eye button in each window.
- Applying a comma-separated pattern list reloads only that window.
- Restored windows preserve their own ignore pattern list.
- Targeted unit tests pass.

## Idempotence and Recovery

The default ignore list is code-owned and deterministic. If a custom list removes all visible files, the existing empty-workspace state is shown. Reopening the sheet and clearing patterns restores full enumeration after applying.

## Artifacts and Notes

No generated artifacts are expected. Runtime build/test outputs remain under `artifacts/` or Xcode derived data paths.

## Interfaces and Dependencies

- No network dependencies.
- No database or migration work.
- No renderer changes and no `WKWebView`, HTML, CSS, or JavaScript renderer.
