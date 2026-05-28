# macOS Markdown File Drop New Window

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Dragging a Markdown file from Finder onto Quick Markdown Viewer should open the file's parent folder in a new workspace window, select the dropped file in the sidebar, and render that file immediately. The behavior should use the app's existing workspace model so relative links, sibling media, restore state, and sidebar highlighting behave the same as an explicit folder open.

## Progress

- [x] (2026-05-27T18:45Z) Confirmed Launch Services file opens already normalize supported files to the parent folder plus selected filename.
- [x] (2026-05-27T18:45Z) Confirmed the SwiftUI window surface does not currently accept Finder file drops.
- [x] (2026-05-27T18:58Z) Added a macOS drop handler for Finder file URLs.
- [x] (2026-05-27T18:58Z) Routed dropped supported files through an explicit new-window request while preserving empty-window reuse for normal external opens.
- [x] (2026-05-27T18:58Z) Added focused unit coverage for forced-new-window requests and dropped file-url decoding.
- [x] (2026-05-27T19:37Z) Ran focused unit coverage, `./scripts/test-unit`, ExecPlan/docs checks, and whitespace validation successfully.

## Surprises & Discoveries

- Observation: external app/document opens currently reuse an empty first window.
  Evidence: `WindowSceneRootView.shouldReuseCurrentWindowForExternalOpen` returns true when no workspace or file is selected.
- Observation: the existing external-open normalizer already handles Markdown, Mermaid, CSV, and TSV files as workspace selections.
  Evidence: `ExternalWorkspaceOpenCoordinator.normalizedRequest(for:)` returns a parent `rootURL` and `selectedPath` for supported file extensions.

## Decision Log

- Decision: keep cold-start external opens able to reuse the initial empty window.
  Rationale: forcing every Launch Services file-open event into a new window would leave a blank startup window behind.
- Decision: make in-window Finder drops request a new window explicitly.
  Rationale: the user is dropping onto an already-visible app window and asked for the parent folder to open in a new window without replacing the current workspace.
- Decision: keep the drop handler generic for all supported workspace inputs, not only `.md`.
  Rationale: the same parent-folder selection behavior is already supported for Markdown-family files plus CSV/TSV, and folders are already valid workspaces.

## Outcomes & Retrospective

Finder file drops now enter the same external workspace-open pipeline as Launch Services file opens, but with an explicit `newWindow` presentation. A dropped supported document file is decoded from the pasteboard file URL, normalized to its parent folder plus selected filename, and scheduled as a new `WorkspaceWindowSession`; the new window then opens through the existing session bootstrap path, so sidebar selection and document rendering come from normal workspace state.

Cold-start external file opens still use `reuseEmptyWindow`, so opening a Markdown file from Finder or the `qmv` launcher does not leave an unused blank startup window behind.

## Context and Orientation

Relevant code:

- `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift` owns `ExternalWorkspaceOpenCoordinator` and macOS app delegate file-open normalization.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift` owns per-window external-open handling and has access to `openWindow`.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceWindowSessionStore.swift` schedules additional workspace windows.
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift` contains the existing external-open regression tests.

## Plan of Work

1. Add an external-open presentation mode so requests can either reuse an empty window or force a new window.
2. Add a macOS-only Finder file drop handler to the root window view.
3. Convert dropped file-url items into normalized workspace-open requests with the force-new-window mode.
4. Extend focused tests around request normalization and app delegate defaults.
5. Run focused macOS tests, docs/plan checks, and whitespace validation.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Edit `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift`.
2. Edit `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`.
3. Edit `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`.
4. Run focused `xcodebuild` unit tests for the external-open path.
5. Run `python3 scripts/check_execplan.py`, `python3 scripts/knowledge/check_docs.py`, and `git diff --check`.

## Validation and Acceptance

Acceptance:

- Dropping a supported Markdown file on an existing macOS app window opens a separate workspace window.
- The new workspace root is the dropped file's parent folder.
- The selected file is the dropped Markdown file, so the sidebar highlights it and the document view renders it.
- Cold-start external file opens do not strand an unused empty window.
- Unsupported dropped files are ignored.

## Idempotence and Recovery

The change is limited to macOS external file ingestion. If the drop handler causes problems, remove the `.onDrop` modifier and the explicit presentation mode while leaving existing Launch Services file-open behavior intact.

## Artifacts and Notes

Expected validation commands:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-file-drop-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExternalWorkspaceOpenCoordinatorNormalizesMarkdownFileToWorkspaceAndSelection" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExternalWorkspaceOpenCoordinatorCanForceNewWindowForDroppedMarkdownFile" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExternalWorkspaceOpenCoordinatorReadsDroppedFileURLData" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppDelegateOpenFilesEnqueuesMarkdownWorkspace" test`
- `./scripts/test-unit`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`

## Interfaces and Dependencies

No new dependencies are required. The macOS drop handler uses SwiftUI `onDrop`, `UniformTypeIdentifiers`, and existing workspace/session APIs.
