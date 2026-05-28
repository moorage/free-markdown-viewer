# macOS File Drop Prompt Suppression

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

After dropping a Markdown file from Finder, Quick Markdown Viewer should open the file's parent folder in a separate window with the file selected, and it should not also show the automatic Open Folder dialog. A programmatic workspace open should cancel any pending automatic prompt from the source window.

## Progress

- [x] (2026-05-27T19:52Z) Confirmed dropped files now schedule a new workspace window correctly.
- [x] (2026-05-27T19:52Z) Identified the likely race: an empty source window can schedule its automatic folder prompt before the asynchronous drop item resolves.
- [x] (2026-05-27T20:00Z) Added explicit prompt suppression for scenes handling programmatic external/drop opens.
- [x] (2026-05-27T20:00Z) Added focused regression coverage for programmatic suppression and cancelling a prompt after it was initially allowed.
- [x] (2026-05-27T20:49Z) Ran focused tests and `./scripts/test-unit` successfully.
- [x] (2026-05-27T20:50Z) Ran repository checks and macOS build successfully.

## Surprises & Discoveries

- Observation: scheduled workspace windows already suppress the prompt via `hasRestoredSession`.
  Evidence: `WorkspaceWindowSessionStore.claimLaunchSession(for:)` records claimed sessions, and `AutomaticFolderPromptPolicy.shouldSuppressAutomaticFolderPrompt` suppresses when `hasRestoredSession` is true.
- Observation: the source window still needs cancellation because `requestInitialFolderPromptIfNeeded` schedules `openFolder()` asynchronously.
  Evidence: `WindowSceneRootView.requestInitialFolderPromptIfNeeded` uses `DispatchQueue.main.async`.

## Decision Log

- Decision: add an explicit per-scene automatic-prompt suppression path to the existing prompt policy.
  Rationale: this handles both prompt requests that have not run yet and normal external-open requests without changing workspace/session restoration behavior.
- Decision: re-check prompt suppression inside the deferred main-queue prompt closure.
  Rationale: the source window can accept a drop after the prompt decision was made but before `NSOpenPanel` is presented.

## Outcomes & Retrospective

The source window now records explicit prompt suppression as soon as it accepts a file drop, before the asynchronous pasteboard item has to resolve. The deferred automatic prompt closure re-checks the policy immediately before opening `NSOpenPanel`, so a drop that arrives after the initial prompt decision still cancels the panel. External workspace requests also suppress the current scene's prompt before either reusing the empty window or scheduling a new workspace window.

The new workspace window still opens from the scheduled `WorkspaceWindowSession`, so the dropped file remains selected and rendered through normal workspace loading.

## Context and Orientation

Relevant code:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceWindowSessionStore.swift` owns automatic folder prompt policy.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift` owns drop handling, external-open handling, and prompt scheduling.
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift` contains existing automatic prompt and external-open tests.

## Plan of Work

1. Extend `AutomaticFolderPromptPolicy` with explicit scene suppression.
2. Have the source window suppress its automatic prompt immediately when a file drop is accepted.
3. Re-check suppression immediately before showing the deferred `NSOpenPanel`.
4. Add focused tests for explicit suppression before and after an allowed prompt decision.
5. Run focused tests, full unit wrapper, and repository checks.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Edit `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceWindowSessionStore.swift`.
2. Edit `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`.
3. Edit `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`.
4. Run focused macOS unit tests.
5. Run `./scripts/test-unit`, `python3 scripts/check_execplan.py`, `python3 scripts/knowledge/check_docs.py`, and `git diff --check`.

## Validation and Acceptance

Acceptance:

- Dropping a supported local file opens the requested workspace window without showing the automatic Open Folder dialog in the source window.
- Scheduled/restored workspace windows continue to suppress the prompt.
- Explicit empty new windows can still show the automatic prompt.
- Cold-start external file opens still avoid stranding a blank empty window.

## Idempotence and Recovery

The change is limited to prompt policy and the source-window drop/external-open hooks. If behavior regresses, remove the explicit scene suppression and keep the earlier file-drop new-window routing intact.

## Artifacts and Notes

Expected validation commands:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-file-drop-prompt-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAutomaticFolderPromptPolicySuppressesProgrammaticOpenScene" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAutomaticFolderPromptPolicyCanCancelAlreadyAllowedPrompt" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExternalWorkspaceOpenCoordinatorCanForceNewWindowForDroppedMarkdownFile" test`
- `./scripts/test-unit`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`

## Interfaces and Dependencies

No new dependencies are required.
