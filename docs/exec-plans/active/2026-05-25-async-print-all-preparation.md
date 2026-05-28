# Async Print All Preparation

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

`Print All` should not make the app beach-ball while a large workspace is being prepared. The user should get immediate feedback that a print job is being prepared, the main SwiftUI/AppKit surface should stay responsive during document loading and parsing, and the final print interaction should open only after the composed job is ready.

The implementation must preserve the existing semantics: `Print All` still prints every openable document in sidebar order as one print job, harness commands still export deterministic print artifacts, and platform-specific print UI remains confined to platform adapters.

## Progress

- [x] (2026-05-25T03:15Z) Audited the current print path and confirmed that `AppModel.makePrintComposition(scope:)` is main-actor isolated and macOS `PlatformPrintPresenter.present` synchronously rasterizes the whole print composition to PDF before the print panel opens.
- [x] (2026-05-25T03:15Z) Created this active follow-up plan for async Print All preparation and macOS print presentation responsiveness.
- [x] (2026-05-25T03:19Z) Implemented async print composition input snapshotting, nonisolated print section building, a visible preparing overlay/status, and direct macOS `NSPrintOperation(view:printInfo:)` presentation for interactive printing. Focused print composition tests, focused PDF export tests, signed focused macOS print UI test, `./scripts/build --platform macos`, and `./scripts/test-unit` pass.
- [x] (2026-05-25T21:40-07:00) Added cancellable print-preparation task ownership in the window scene, a Cancel affordance in the preparing overlay, cancellation status/error clearing, and PDF export guards that fail/fallback instead of returning blank white output. Focused print cancellation and PDF ink tests pass.
- [x] (2026-05-25T23:51-07:00) Added an AppKit `NSPrintOperation` save-to-PDF regression test for print-preview content and fixed native macOS printing to draw cached page slices explicitly. Focused native print/export tests pass.

## Surprises & Discoveries

- Observation: document parsing already uses a detached task per document, but the composition loop and print state live on the main-actor `AppModel`.
  Evidence: `AppModel.makePrintComposition(scope:)` sets `isPreparingPrint`, loops over `targetFiles`, and awaits `Self.loadDocument(provider:path:)` from a `@MainActor` method.

- Observation: macOS interactive print does more work than export callers need before the system print UI appears.
  Evidence: `PlatformPrintPresenter.present` calls `pdfData(for:layout:)`, which lays out a SwiftUI print view, rasterizes every page into bitmaps, builds a `PDFDocument`, and only then creates the `NSPrintOperation`.

- Observation: PDF export can silently look successful even when the rendered page has no meaningful ink if the hosted SwiftUI print view is captured before it has a valid printable layout.
  Evidence: the focused PDF export test now rasterizes the first exported page and checks for non-white pixels, which catches completely blank output.

- Observation: the direct AppKit print path can still produce blank output when the printable content is an off-window SwiftUI hosting subview.
  Evidence: `testMacPrintOperationPDFOutputIsNotBlank` failed with one quantized page color before the print view started drawing cached page slices directly.

## Decision Log

- Decision: snapshot print inputs on the main actor, then build the `DocumentPrintComposition` from a nonisolated background path.
  Rationale: the app model owns workspace state and must publish state changes on the main actor, but file reads, Markdown parsing, table parsing, Mermaid compilation, and media URL hydration can run outside the UI actor once the provider and file list are captured.
  Date/Author: 2026-05-25 / Codex

- Decision: keep deterministic PDF export behavior, but make interactive macOS printing submit a paginated print view directly instead of pre-rasterizing the full job to PDF.
  Rationale: tests and harness exports still need exact PDF artifacts, while the user-facing print path should avoid a synchronous all-pages PDF render before the print panel.
  Date/Author: 2026-05-25 / Codex

- Decision: own the cancellable print-preparation task at `WindowSceneRootView` and expose cancellation through the existing preparing overlay.
  Rationale: the scene already serializes print presentation and can cancel the active `Task` without pushing UI task ownership into `AppModel`; the model only needs to record cancelled/error/presented state consistently.
  Date/Author: 2026-05-25 / Codex

- Decision: keep interactive macOS printing on `NSPrintOperation(view:printInfo:)`, but make that view draw lazy cached bitmap slices itself instead of relying on printing the hosted SwiftUI subview hierarchy.
  Rationale: this preserves the non-blocking print-panel path while avoiding blank AppKit print-preview pages.
  Date/Author: 2026-05-25 / Codex

## Outcomes & Retrospective

Implemented. `Print All` now snapshots the workspace state on the main actor, publishes a `preparing` status plus visible overlay, and builds the composed print sections through a nonisolated async path. The active print-preparation task can be cancelled from the overlay, cancellation clears preparation state, and cancellation is recorded for UI-test/harness status. Interactive macOS printing now submits the paginated print view directly to `NSPrintOperation` instead of generating a full PDF before the print operation, and that print view explicitly draws cached page slices so print preview is not blank. Harness PDF export still uses the deterministic PDF path and now guards against zero-page or effectively blank PDF output.

Validation is green for the affected print surfaces: focused print cancellation and PDF ink tests pass, the new large-workspace preparation-state test passes, focused all-documents PDF export tests pass, signed focused macOS print UI routing passes, and the macOS debug build passes.

## Context and Orientation

Relevant files:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/DocumentPrinting.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/PlatformPrintPresenter.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`
- `.agents/DOCUMENTATION.md`

Current flow:

- `WindowSceneRootView.printAllDocuments()` starts a `Task` and calls `presentPrint(scope: .allFiles)`.
- `presentPrint(scope:)` awaits `model.makePrintComposition(scope:)`, then calls `PlatformPrintPresenter.present`.
- `AppModel.makePrintComposition(scope:)` resolves target files and provider from model state, toggles `isPreparingPrint`, and builds sections in a main-actor method.
- macOS `PlatformPrintPresenter.present` eagerly generates PDF data for the whole composition before opening the print operation.

## Plan of Work

1. Add print-preparation status that can distinguish idle, preparing, presented, and error states without changing existing harness status IDs.
2. Refactor `AppModel.makePrintComposition(scope:)` so main-actor work is limited to state snapshot and published status, while section building happens through a nonisolated async helper.
3. Keep selected-file and all-files ordering and error behavior unchanged.
4. Change macOS interactive print presentation to use the existing paginated print view directly, while leaving PDF export on the current `pdfData` path.
5. Add unit/UI coverage that proves Print All enters a visible preparing state before completion and still reports presented under UI-test mode.
6. Update documentation and run focused print tests plus build/docs validators.

## Concrete Steps

1. Introduce a small sendable print composition request or helper signature containing provider, target files, workspace title, font scale, launch theme, and table presentation.
2. Move section construction into a nonisolated helper that checks cancellation and loads documents away from the main actor.
3. Update `makePrintComposition(scope:)` to set `isPreparingPrint`, clear errors, publish a preparing status, await the nonisolated helper, and clear preparation state in `defer`.
4. Add a user-visible preparing overlay in `ViewerShellView` using the existing loading overlay style.
5. Replace eager PDF construction in macOS `PlatformPrintPresenter.present` with `NSPrintOperation(view:printInfo:)`.
6. Add tests around async status and the existing print UI action.
7. Add cancellation from the preparing overlay and ensure cancelled jobs clear model preparation state.
8. Add PDF export validation/fallback so a single-document print artifact cannot be completely empty white.

## Validation and Acceptance

Acceptance requires all of the following:

- `Print All` sets a visible preparing state immediately after the action starts.
- The print-composition work runs outside the main actor after model state is captured.
- macOS interactive print no longer pre-rasterizes the whole print job into PDF before showing the print operation.
- Existing harness commands `printAllDocuments` and `exportPrintedAllDocuments` keep working.
- Existing selected-file and all-files print composition tests still pass.
- Print preparation can be cancelled without crashing or leaving the app stuck in a preparing state.
- Single-document PDF export produces a page with non-white rendered content.
- Focused macOS UI print test still passes.
- `./scripts/build --platform macos` passes.
- `python3 scripts/check_execplan.py` and `python3 scripts/knowledge/check_docs.py` pass.

## Idempotence and Recovery

The change is read-only with respect to user documents. If async composition introduces a regression, the smallest rollback is to restore the old `makePrintComposition(scope:)` loop while keeping the print UI disabled during preparation. If direct AppKit view printing has a platform issue, PDF export can remain as the fallback because the export path is intentionally left unchanged.

## Artifacts and Notes

Commands used during planning:

- `rg -n "Print All|printAll|exportPrintedAll|PrintAll|print all|DocumentPrint|Print" "Quick Markdown Viewer/Quick Markdown Viewer" "Quick Markdown Viewer/Quick Markdown ViewerTests" "Quick Markdown Viewer/Quick Markdown ViewerUITests" docs scripts .agents -g "!artifacts/**"`
- `nl -ba "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift" | sed -n "1,220p;430,520p;930,1135p"`
- `nl -ba "Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/PlatformPrintPresenter.swift" | sed -n "1,220p;220,340p"`
- `nl -ba "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift" | sed -n "1,290p;540,725p"`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-print-regression-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMacPrintOperationPDFOutputIsNotBlank" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExportPrintedDocumentHarnessCommandWritesPDF" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExportPrintedMarkdownDocumentWithRichFeaturesWritesExpectedPDFContent" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMacPrintPresenterRetainsModalPrintOperationUntilCallback" test`

## Interfaces and Dependencies

- `WorkspaceProvider` is already `Sendable` and exposes nonisolated read APIs, so it can be captured for background composition.
- `DocumentPrintComposition`, `DocumentPrintSection`, `MarkdownBlock`, `MarkdownFileNode`, `WorkspacePath`, and related print payloads are `Sendable`.
- AppKit and UIKit calls remain inside `PlatformPrintPresenter`; only macOS interactive presentation behavior changes.
