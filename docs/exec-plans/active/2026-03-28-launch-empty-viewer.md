# Launch into an Empty Viewer When No Workspace Is Open

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

After this change, launching the app without any restored windows or explicit harness workspace should open a blank viewer state instead of loading the embedded default markdown fixtures. The first window should prompt the user in-app to choose a folder of markdown files, while restored sessions, explicit fixture launches, and later folder selections keep their existing behavior.

## Progress

- [x] (2026-03-28T17:57Z) Confirmed the current cold-start behavior: `AppModel` loads `LocalWorkspaceProvider(rootURL: nil, embeddedDocs: EmbeddedFixtures.docs)` when no restored session or fixture root exists, which surfaces the default embedded markdown set in the first window.
- [x] (2026-03-28T18:03Z) Replaced the nil-root bootstrap fallback with a dedicated no-workspace state in `AppModel` and updated `ViewerShellView` to render a centered open-folder prompt instead of the embedded fixture list.
- [x] (2026-03-28T18:04Z) Added focused unit and UI regression coverage for cold launch without a workspace, plus unit assertions that distinguish the blank launch state from the existing empty-folder state.
- [x] (2026-03-28T18:05Z) Ran the targeted macOS unit slice successfully, attempted the matching macOS UI slice, and confirmed the run is still blocked locally by the existing `Free Markdown ViewerUITests-Runner` bootstrap crash before XCTest establishes a connection.

## Surprises & Discoveries

- Observation: the first launch scene is already prevented from auto-opening the folder chooser.
  Evidence: `WorkspaceWindowSessionStore.AutomaticFolderPromptPolicy` suppresses the initial launch scene, so the user-visible default fixture list comes from the model bootstrap path rather than from macOS prompt policy.

## Decision Log

- Decision: preserve the existing explicit new-window prompt behavior and change only the "no workspace selected" bootstrap path for the initial empty scene.
  Rationale: the user request targets the default markdown bootstrap, and replacing that fallback is the smallest product-safe change that keeps session restore and harness behavior intact.

## Outcomes & Retrospective

The app now launches into a true empty viewer when there is no restored window session and no explicit fixture root. Instead of creating a `LocalWorkspaceProvider` over the embedded sample markdown set, `AppModel` now enters a dedicated no-workspace state and the shell renders a centered prompt that tells the user to open a folder of markdown files. Opening an actual empty folder still shows the prior "No markdown files found." recovery state, so the product now distinguishes "no folder chosen yet" from "chosen folder has no markdown."

The smallest safe change was to leave session restoration and explicit new-window prompting untouched. The first launch scene was already suppressing the automatic macOS folder chooser, so the unwanted startup behavior came entirely from the nil-root fixture fallback. Removing only that fallback kept harnessed fixture launches and restored workspaces stable while changing the default interactive startup semantics.

Validation is mixed. The focused macOS unit slice passed, covering the new no-workspace state, the existing empty-folder state, and restored-session behavior. The targeted macOS UI slice compiled and launched but failed in the same repo-known way as earlier runs: `Free Markdown ViewerUITests-Runner` exited before establishing the XCTest connection. That leaves a residual environment-specific UI-validation gap rather than a known product failure in the app code.

## Context and Orientation

Relevant files:

- `Free Markdown Viewer/Free Markdown Viewer/App/Shared/AppModel.swift`
- `Free Markdown Viewer/Free Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Free Markdown Viewer/Free Markdown Viewer/App/Shell/WindowSceneRootView.swift`
- `Free Markdown Viewer/Free Markdown ViewerTests/Free_Markdown_ViewerTests.swift`
- `Free Markdown Viewer/Free Markdown ViewerUITests/Free_Markdown_ViewerUITests.swift`

## Plan of Work

1. Add a dedicated app-model state for "no workspace selected" during bootstrap.
2. Render that state as a blank viewer with an in-app open-folder call to action instead of showing the sidebar/split-view workspace browser.
3. Add focused unit and UI regression coverage for blank launch and keep the existing empty-folder behavior intact.
4. Run targeted tests plus `python3 scripts/check_execplan.py` and `python3 scripts/knowledge/check_docs.py`.

## Concrete Steps

1. Update `AppModel.loadWorkspace()` to short-circuit into a no-workspace state when there is no restored session and no fixture root.
2. Expose lightweight view-state properties so `ViewerShellView` can distinguish "no folder open" from "folder open but empty."
3. Add a macOS/UI-testable launch case with no fixture root that asserts the centered open-folder prompt appears.
4. Record validation evidence and doc updates once the change passes.

## Validation and Acceptance

Acceptance requires:

- a cold launch with no restored windows and no fixture root shows a blank viewer prompt instead of embedded markdown fixtures
- the prompt offers an in-app open-folder action
- opening an empty folder still shows the existing "No markdown files found." recovery state
- restored sessions and explicit fixture-driven launches keep their current behavior
- targeted unit and UI tests pass
- `python3 scripts/check_execplan.py` and `python3 scripts/knowledge/check_docs.py` pass

## Idempotence and Recovery

This change is limited to startup/view state. If the blank launch behavior regresses harness flows, recovery is to restore the previous nil-root bootstrap path in `AppModel` while keeping the new tests to isolate the desired launch semantics.

## Artifacts and Notes

Validation commands run:

- `xcodebuild -quiet -project "Free Markdown Viewer/Free Markdown Viewer.xcodeproj" -scheme "Free Markdown Viewer" -configuration Debug -derivedDataPath /tmp/free-markdown-viewer-empty-launch-unit -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Free Markdown ViewerTests/Free_Markdown_ViewerTests/testAppModelWithoutInitialWorkspaceShowsOpenFolderPromptState" "-only-testing:Free Markdown ViewerTests/Free_Markdown_ViewerTests/testEmptyWorkspaceShowsNoMarkdownFilesMessage" "-only-testing:Free Markdown ViewerTests/Free_Markdown_ViewerTests/testAppModelRestoresInitialWorkspaceSession" test`
- `xcodebuild -quiet -project "Free Markdown Viewer/Free Markdown Viewer.xcodeproj" -scheme "Free Markdown Viewer" -configuration Debug -derivedDataPath /tmp/free-markdown-viewer-empty-launch-ui -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Free Markdown ViewerUITests/Free_Markdown_ViewerUITests/testColdLaunchWithoutWorkspaceShowsOpenFolderPrompt" "-only-testing:Free Markdown ViewerUITests/Free_Markdown_ViewerUITests/testEmptyWorkspaceShowsCenteredOpenFolderCallToAction" test`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`

## Interfaces and Dependencies

No new dependencies are required. The change stays inside the existing SwiftUI app shell, `AppModel` bootstrap flow, and the current XCTest/XCUITest harness surfaces.
