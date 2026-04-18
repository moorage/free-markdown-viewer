# Print Single File or All Files

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Add first-class printing for the viewer on macOS, iPhone, and iPad. A user should be able to print the currently selected file or print all openable files in the current workspace, regardless of whether that workspace came from a local folder or a cached GitHub repository snapshot.

For this milestone:

- `Print` means print the currently selected document.
- `Print All` means print every openable document in the current workspace, in the same stable order the sidebar presents them, not just the currently filtered subset.
- Batch printing should produce one print job, not a separate print panel or printer submission per file.
- GitHub-backed workspaces should print through the same flow because their cached snapshots already behave like local files.

This milestone is about printing, not exporting standalone PDFs as a separate user-facing feature, not adding per-page layout editors, and not inventing a browser-style print pipeline. The renderer remains native.

## Progress

- [x] (2026-04-17T06:36Z) Audited the current app shell and confirmed there is no existing print path, print adapter, or PDF-generation test seam in either shared code or platform shells.
- [x] (2026-04-17T06:36Z) Confirmed the app already has a focused-scene command pattern on macOS and top-bar controls on iPhone and iPad, which gives this feature clear insertion points for `Print` and `Print All`.
- [x] (2026-04-17T06:36Z) Confirmed all-files printing has to be tied to the workspace file list abstraction so local folders and GitHub workspaces stay behaviorally identical.
- [x] (2026-04-17T06:36Z) Drafted the implementation plan below, including shared print composition, platform adapters, batch job semantics, testability, and current/future compatibility with widened document types.
- [x] (2026-04-17T07:20Z) Added a shared print-composition path in `AppModel` plus platform-native macOS and iOS print presenters.
- [x] (2026-04-17T07:20Z) Wired `Print…` and `Print All…` into the focused macOS command surface and added compact print menus to the iPhone and iPad top bars.
- [x] (2026-04-17T07:20Z) Added deterministic harness commands that export print composition to a requested artifact path without invoking native print UI.

## Surprises & Discoveries

- Observation: there is currently no print-specific infrastructure to reuse, so this feature needs both platform adapters and a shared print composition model.
  Evidence: a repo-wide search for `print`, `UIPrint`, `NSPrint`, `PDF`, `UIActivity`, and `NSSharingService` found no existing app-side print or print-preview code under `Quick Markdown Viewer/Quick Markdown Viewer/`.

- Observation: the app already uses focused-scene actions plus a single macOS `Commands` surface, which is the right place to wire print commands instead of inventing a second command-routing system.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift` defines `OpenFolderAction`, `OpenGitHubURLAction`, `RevealInFinderAction`, and font-size actions, then exposes them through `WindowOpenFolderCommands`.

- Observation: all-files printing must operate on the workspace file list rather than the current document blocks, because the selected document is loaded lazily and only one file is materialized at a time today.
  Evidence: `AppModel` only stores one loaded `documentText` plus `documentBlocks`, while the full workspace is represented separately by `files` and `workspaceProvider`.

- Observation: deterministic print validation cannot rely on native print panels because macOS and iOS system print UI is outside the normal harness control surface.
  Evidence: `docs/debug-contracts.md` and `docs/harness.md` currently define launch arguments, command directories, screenshots, state dumps, and GitHub fixtures, but no print artifact export or print command hook.

- Observation: the current structured and selectable document views already provide two useful composition inputs for a print pipeline, but neither is currently packaged as a printer-ready abstraction.
  Evidence: `ViewerShellView` renders rich block content through `DocumentBlockScrollView`, while `SelectableDocumentTextView` produces attributed text from the same `MarkdownBlock` model for text-oriented documents.

- Observation: once the CSV and TSV plan lands, batch printing should naturally widen with it if the print feature depends on the shared workspace document list rather than hard-coding Markdown assumptions.
  Evidence: the new CSV/TSV ExecPlan already widens file discovery away from Markdown-only assumptions, and `Print All` is fundamentally a workspace-document concern rather than a Markdown-render concern.

- Observation: a plain-text shared print composition was the smallest cross-platform representation that stayed native and testable without introducing HTML or a new PDF layout engine.
  Evidence: `DocumentPrintComposer` now emits shared plain-text sections, the harness exports that artifact directly, and each platform’s print presenter submits native text-based print content.

## Decision Log

- Decision: define `Print` as the currently selected file and `Print All` as every openable document in sidebar order.
  Rationale: this is the most predictable mapping for users and preserves a stable cross-platform contract regardless of local folders, GitHub caches, or future file-type widening.
  Date/Author: 2026-04-17 / Codex

- Decision: implement batch printing as one composed print job rather than one print interaction per file.
  Rationale: repeated system print dialogs would be hostile UX on both macOS and iOS and would be difficult to reason about in automation. One composed print artifact matches the user’s “all files” request more cleanly.
  Date/Author: 2026-04-17 / Codex

- Decision: build a shared print composition layer that converts loaded documents into printer-oriented sections, then let macOS and iOS supply the final platform print interaction adapters.
  Rationale: the product supports both platforms and already keeps shared rendering logic platform-neutral. The print layout model should follow the same boundary, with AppKit and UIKit only at the last mile.
  Date/Author: 2026-04-17 / Codex

- Decision: keep the print pipeline compatible with local and GitHub workspaces by reading through `WorkspaceProvider` rather than reaching around it to the filesystem directly.
  Rationale: GitHub workspaces are already presented through cached local mirrors with the same provider abstraction, and batch printing should not fork by workspace source.
  Date/Author: 2026-04-17 / Codex

- Decision: add a deterministic debug-only export seam for print artifacts, likely PDF output to a harness-owned path, so tests can validate composition without invoking the native print panel.
  Rationale: system print UI is not stable automation territory, but the repo requires tests and harness-visible evidence for user-facing features.
  Date/Author: 2026-04-17 / Codex

- Decision: make the single-file and all-files commands conditional on current state.
  Rationale: `Print` should be disabled when no file is selected, and `Print All` should be disabled when the workspace has no openable files, avoiding no-op or error-shaped UX.
  Date/Author: 2026-04-17 / Codex

## Outcomes & Retrospective

Implemented.

- `AppModel.makePrintComposition(scope:)` now composes selected-file or all-files print content in sidebar order through `WorkspaceProvider`, so local and GitHub workspaces use the same read path.
- `WindowSceneRootView` now exposes focused print actions for macOS commands and top-bar print actions for iPhone and iPad.
- `PlatformPrintPresenter` keeps AppKit and UIKit confined to platform adapters while the shared print composition remains platform-neutral.
- Harness command handling now supports `printSelectedDocument` and `printAllDocuments` artifact export, and focused unit coverage exercises selected-file, all-files, and GitHub-compatible print behavior.

## Context and Orientation

Relevant code and docs:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/GitHubWorkspace.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/SelectableDocumentTextView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/HarnessLaunchOptions.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`
- `docs/debug-contracts.md`
- `docs/harness.md`
- `docs/exec-plans/active/2026-04-16-github-url-workspaces.md`
- `docs/exec-plans/completed/2026-04-16-csv-tsv-tabular-documents.md`
- `.agents/DOCUMENTATION.md`

Current architectural facts that matter:

- `AppModel` owns the selected file, loaded document blocks, and workspace provider, so printing orchestration belongs there or in a closely related shared helper instead of directly inside a view.
- macOS commands are already routed through focused-scene actions from `WindowSceneRootView`, making print command insertion low risk.
- iPhone and iPad already have top navigation bars with compact icon-only controls, so print affordances should likely live in a menu or compact control rather than a large new standalone button cluster.
- Local and GitHub workspaces already converge at the `WorkspaceProvider` boundary, which is the correct place to read document contents during single-file or batch print composition.

## Plan of Work

1. Add a shared print-composition model that can turn one or many workspace documents into a printable representation.
2. Add `AppModel` orchestration for print-current and print-all flows, including state, errors, and background loading for batch jobs.
3. Add platform-specific print adapters for macOS and iOS/iPadOS.
4. Expose print controls in the macOS command/menu surface and the iOS/iPad top bar.
5. Add a deterministic harness seam for print artifact generation and tests.
6. Update docs and control-plane files in the same milestone.

## Concrete Steps

1. Introduce a shared print domain.

   - Add shared types for concepts such as:
     - print scope: `.selectedFile` or `.allFiles`
     - printable document sections
     - print composition result
     - user-facing print errors
   - Keep these types platform-neutral and independent of AppKit or UIKit.
   - Design them around workspace paths plus loaded document content so local folders and GitHub caches use the same path.

2. Add a shared print-composition pipeline.

   - Teach the shared layer how to compose one selected document or multiple workspace documents into a single printable representation.
   - Preserve stable file order for `Print All` by using the same order as `files` in `AppModel`, not an ad hoc filesystem re-enumeration.
   - Add explicit section breaks between files in batch prints, including document titles or path headings so the output is legible as one job.
   - Reuse existing document parsing and formatting rather than reparsing files through a second unrelated path.

3. Decide and implement the shared printable representation.

   - Prefer one shared representation that can drive both platforms and harness validation, for example:
     - a platform-neutral print section model that each platform adapter renders into native print formatters
     - or a shared PDF-generation pipeline backed by Core Graphics that both platforms can submit to native print UI
   - The implementation must support:
     - headings, paragraphs, lists, code blocks, and tables
     - images and media placeholders or fallbacks that degrade clearly when direct printing of live playback is not appropriate
     - multi-document composition for `Print All`
   - If the chosen path does not yet support remote media or video faithfully, surface a clear fallback in print output rather than silently dropping content.

4. Add `AppModel` print orchestration.

   - Add commands such as `printSelectedDocument()` and `printAllDocuments()` to `AppModel` or a closely related shared controller.
   - Single-file print should require a selected file.
   - Batch print should iterate the current workspace document list and load each file through `WorkspaceProvider`.
   - Track print state so the UI can disable duplicate submissions and surface errors consistently.
   - Keep printing read-only; it must not mutate workspace files or cached GitHub snapshots.

5. Add platform-specific print adapters.

   - macOS:
     - use an AppKit print path such as `NSPrintOperation` from a printable view, attributed text stack, or PDF data
     - add `Print…` and `Print All…` commands to the existing `Commands` surface
     - wire them through new focused-scene values in `WindowSceneRootView`
   - iOS and iPadOS:
     - use `UIPrintInteractionController`
     - expose print actions in the existing top navigation area, likely through a compact `Menu` or overflow affordance
   - Both platforms should present one print interaction per user action, even for `Print All`.

6. Define user-visible UX for print actions.

   - macOS:
     - `File > Print…` for the selected file
     - `File > Print All…` for the current workspace
     - optional toolbar or context-menu access only if it fits the existing shell cleanly
   - iPhone and iPad:
     - add a compact print menu in the top bar with actions for `Print` and `Print All`
   - Disable actions when they are not applicable.
   - Surface progress or a loading state if batch composition takes noticeable time.

7. Add a deterministic harness validation seam.

   - Add a debug or test-only path that exports the exact print composition artifact to a file path under `artifacts/` without invoking the native print panel.
   - This could be:
     - a launch argument for a print-output path
     - a harness command for `printSelectedDocument` or `printAllDocuments`
     - or both
   - Update `docs/debug-contracts.md` and `docs/harness.md` with the new contract.
   - Ensure the exported artifact is stable enough for tests, likely PDF or structured metadata plus PDF.

8. Add tests and fixtures.

   - Unit tests:
     - single-file print composition from the selected Markdown document
     - all-files composition preserving workspace order
     - GitHub-backed workspace print composition using cached fixture content
     - disabled or error states when there is no selected file or no workspace files
   - UI tests:
     - macOS command/menu exposure for `Print…` and `Print All…`
     - iPhone or iPad top-bar print menu exposure
     - harness-driven artifact generation instead of system-panel interaction
   - Add any print-specific fixtures needed for multi-file composition expectations.

9. Keep the design compatible with the CSV/TSV plan.

   - The printing feature should be built against the workspace-document abstraction rather than a hard-coded Markdown-only file list.
   - If the CSV/TSV plan lands first or concurrently, `Print All` should naturally include those files in workspace order.
   - If CSV/TSV support has not landed yet, do not block this print feature on it; just avoid entrenching new Markdown-only assumptions.

10. Update docs and control-plane state.

   - Update `docs/debug-contracts.md` with any new accessibility identifiers and print artifact hooks.
   - Update `docs/harness.md` with the print validation workflow.
   - Update `.agents/DOCUMENTATION.md` and keep this ExecPlan current during implementation.

## Validation and Acceptance

Acceptance requires all of the following:

- On macOS, the app exposes `Print…` and `Print All…` for the focused window.
- On iPhone and iPad, the app exposes print actions in the top navigation area.
- `Print…` prints the currently selected file only.
- `Print All…` prints all openable files in the current workspace, in sidebar order, as one print job.
- Local-folder and GitHub-backed workspaces both support single-file and all-files printing.
- Actions are disabled or clearly error when there is no selected file or no printable workspace files.
- Batch printing does not show one native print interaction per file.
- The feature is covered by deterministic tests that validate print composition without depending on native print-panel automation.
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-04-17-print-single-or-all-documents.md` passes.
- `python3 scripts/knowledge/check_docs.py` passes after the related docs updates.

## Idempotence and Recovery

Printing is read-only and should not mutate user content, workspace metadata, or GitHub cache entries. Re-running the same print action should regenerate the same printable artifact from current workspace state without leaving durable side effects beyond temporary system print data or harness-owned test artifacts.

If a batch-print implementation regresses current file navigation or document loading, the smallest rollback is to gate `Print All` while leaving the shared single-file print path intact. If platform print UI becomes unreliable, the harness export seam should remain usable for validation so the shared composition logic can still be tested independently of the system dialog.

## Artifacts and Notes

Planning commands run for this ExecPlan:

- `rg -n "print|UIPrint|PrintInteraction|NSPrint|PDF|export|share sheet|shareSheet|activity view|UIActivity|NSSharingService|printer" README.md ARCHITECTURE.md docs "Quick Markdown Viewer/Quick Markdown Viewer" "Quick Markdown Viewer/Quick Markdown ViewerTests" "Quick Markdown Viewer/Quick Markdown ViewerUITests"`
- `sed -n '1,220p' README.md`
- `sed -n '1,220p' ARCHITECTURE.md`
- `sed -n '1,220p' .agents/PLANS.md`
- `sed -n '1,220p' docs/PLANS.md`
- `sed -n '1,220p' docs/debug-contracts.md`
- `sed -n '1,260p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift"`
- `sed -n '1,260p' "Quick Markdown Viewer/Quick Markdown Viewer/Harness/HarnessCommands.swift"`
- `sed -n '1,260p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift"`
- `sed -n '260,520p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift"`
- `sed -n '520,880p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift"`
- `rg -n "focusedSceneValue|Commands|OpenFolderAction|OpenGitHubURLAction|RevealInFinderAction|IncreaseFontSizeAction|DecreaseFontSizeAction|WindowOpenFolderCommands|CommandMenu|MenuBarExtra" "Quick Markdown Viewer/Quick Markdown Viewer"`
- `sed -n '400,560p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift"`
- `sed -n '760,920p' "Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift"`
- `sed -n '1,260p' "Quick Markdown Viewer/Quick Markdown Viewer/Harness/HarnessLaunchOptions.swift"`
- `sed -n '1,260p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/SelectableDocumentTextView.swift"`
- `date -u +%Y-%m-%dT%H:%MZ`

Expected implementation touch points:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/GitHubWorkspace.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/HarnessLaunchOptions.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`
- `docs/debug-contracts.md`
- `docs/harness.md`
- `.agents/DOCUMENTATION.md`

Expected validation commands after implementation:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-print-unit -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testPrintSelectedDocumentUsesCurrentSelection" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testPrintAllDocumentsUsesWorkspaceOrder" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testGitHubWorkspacePrintAllUsesCachedSnapshot" test`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-print-ui-macos -destination "platform=macOS,arch=arm64" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testMacWindowShowsPrintCommandsForSelectedDocument" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testMacPrintAllExportsSingleBatchArtifactInUITestMode" test`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-print-ui-ios -destination "platform=iOS Simulator,name=iPhone 16" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testiPhoneTopBarShowsPrintMenuForSelectedDocument" test`
- `./scripts/test-unit`
- `./scripts/test-ui-macos --smoke`
- `./scripts/test-ui-ios --device both --smoke`
- `python3 scripts/check_execplan.py docs/exec-plans/completed/2026-04-17-print-single-or-all-documents.md`
- `python3 scripts/knowledge/check_docs.py`

## Interfaces and Dependencies

New or widened interfaces likely required:

- focused-scene actions for `printSelectedFile` and `printAllFiles`
- a shared print composition model
- a platform adapter boundary for macOS printing and iOS printing
- a debug or harness command surface for print artifact export
- stable accessibility identifiers for any new print menu or button surfaces

Dependencies and constraints:

- keep rendering native; no `WKWebView`, HTML, CSS, or JavaScript
- shared print composition must stay platform-neutral
- AppKit belongs only in the macOS print adapter and command wiring
- UIKit belongs only in the iOS or iPad print adapter
- local and GitHub workspaces must share the same print path through `WorkspaceProvider`
- the print plan should avoid entrenching new Markdown-only assumptions so it remains compatible with the active CSV/TSV document plan
