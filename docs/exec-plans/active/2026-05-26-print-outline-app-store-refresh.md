# Print, Outline Performance, and App Store Refresh

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

The current user-visible polish issues are all in high-traffic surfaces: printing, outline navigation while reading long documents, and App Store presentation. Printing should reliably reach the native print panel, print controls should use compact icon chrome instead of duplicated text buttons, outline mode should stay responsive while fast-scrolling documents with many headings, and App Store Connect screenshots/copy should showcase the current feature set.

This work should preserve platform boundaries, keep print presentation in platform adapters, keep outline tracking native SwiftUI-only, and avoid broad refactors.

## Progress

- [x] (2026-05-26 06:02Z) Created this coordinating ExecPlan before changing print, outline performance, or App Store Connect state.
- [x] (2026-05-26 06:10Z) Fixed macOS modal print presentation by retaining `NSPrintOperation` until the AppKit callback fires.
- [x] (2026-05-26 06:15Z) Replaced macOS print toolbar chrome with icon-only `ControlGroup` buttons and hid the UI-test print action overlay from screenshots.
- [x] (2026-05-26 06:18Z) Debounced outline active-heading updates so fast scrolls coalesce to the latest observed heading offsets instead of updating state for every scroll preference frame.
- [x] (2026-05-26 06:36Z) Added UI-test launch flags and capture-script wiring for deterministic Files/Search/Outline screenshot states.
- [x] (2026-05-26 06:43Z) Rebuilt the App Store fixture set around folders, outline, search, Mermaid, CSV, media, code, print, and Quick Look features.
- [x] (2026-05-26 06:51Z) Regenerated all App Store screenshot artifacts: 7 iPhone, 7 iPad, and 7 macOS PNGs under `artifacts/app-store-screenshots/`.
- [x] (2026-05-26 07:03Z) Updated release metadata and review-note source docs for the refreshed feature set.
- [x] (2026-05-26 07:10Z) Applied live App Store Connect promotional text for the latest iOS and macOS localizations; description, keywords, URLs, subtitle, What's New, and screenshots are blocked until a new editable app version exists.
- [x] (2026-05-26 06:51Z) Reproduced blank native AppKit print-operation output with a focused regression test, then fixed the macOS print view to draw cached page slices explicitly. Focused print regression/export/retainer tests pass.

## Surprises & Discoveries

- The print sheet path was launching a modal `NSPrintOperation` from a local variable with a nil delegate; retaining the operation through a delegate callback is the narrowest fix for the sheet not reliably reaching the native print UI.
- The App Store screenshot harness needed app-level launch state, not just fixture files, to reliably show Search, Files, and Outline panes.
- App Store Connect allows live promotional-text changes on `READY_FOR_SALE` versions, but rejects description, keywords, marketing/support URLs, What's New, app-info subtitle, and screenshot uploads in that state.
- Existing latest versions are live, not editable: iOS `1.4` (`1e0a074d-26a6-4f33-a8f5-a70b7897f301`) and macOS `1.4` (`9a04ddf5-0e75-48fb-9262-29b83d34aed4`) are both `READY_FOR_SALE`.
- Native AppKit printing of an off-window SwiftUI hosting subview can emit blank pages even when the harness PDF export path renders ink. Saving an `NSPrintOperation` directly to PDF is the closest stable automated check for print-preview content.

## Decision Log

- Use an AppKit-side retainer for modal print operations rather than changing shared print composition code.
- Keep UI-test print action buttons available to accessibility while rendering them with `.opacity(0)` so screenshot captures show only the real icon toolbar controls.
- Debounce active outline updates by 80 ms. This is short enough to settle quickly after fast scrolling and long enough to skip highlight churn while headers stream past.
- Add harness-only screenshot flags: `--ui-test-show-sidebar`, `--ui-test-show-outline`, `--ui-test-search-query`, and `--ui-test-search-scope`.
- Do not create a new App Store Connect version implicitly. Live metadata/screenshot writes that require an editable version are documented as blocked instead.
- Draw cached page slices inside the AppKit print view instead of relying on `NSHostingView` subview printing. The cache is intentionally small so preview redraws are stable without retaining every page of a large print job.

## Outcomes & Retrospective

- Print and Print All now reach the native macOS print sheet in manual verification.
- Print toolbar chrome is icon-only; duplicate visible text print buttons no longer appear in screenshots.
- Outline active-section tracking remains functional but avoids per-frame state churn during fast scrolls.
- App Store screenshots and fixture inputs now showcase current features across iPhone, iPad, and macOS.
- Live App Store Connect promotional text was updated for both latest platform localizations.
- Full App Store Connect screenshot replacement and locked listing fields remain pending a new editable app-store version.
- Native macOS print-operation PDF output now contains rendered page content rather than blank white pages.

## Context and Orientation

Relevant files and scripts:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/PlatformPrintPresenter.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/DocumentPrinting.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`
- `scripts/capture-app-store-screenshots`
- `scripts/app-store-connect`
- `docs/release/`

Known starting points:

- `docs/exec-plans/active/2026-05-25-async-print-all-preparation.md` owns the async print-preparation behavior.
- `docs/exec-plans/active/2026-05-12-markdown-outline-inspector.md` owns outline generation and active-heading tracking.
- App Store Connect app state has previously been managed through `scripts/app-store-connect`.

## Plan of Work

See `Concrete Steps` for the ordered implementation sequence.

## Concrete Steps

1. Reproduce or inspect the current print-panel path, including toolbar/menu actions and `PlatformPrintPresenter`.
2. Fix print presentation so selected-document and all-documents printing reach the native print UI instead of only recording a success state.
3. Replace duplicated text print controls with the existing icon-style controls, keeping accessible labels and menu commands intact.
4. Optimize outline active-heading tracking so fast scrolls can skip intermediate highlights rather than causing per-frame heavy state updates.
5. Update focused tests for print routing, print chrome, and outline tracking/performance behavior.
6. Regenerate App Store screenshots with current features visible, then update App Store Connect metadata/copy through repo scripts when credentials and editable version state permit it.
7. Run focused tests/builds plus `python3 scripts/check_execplan.py`, `python3 scripts/knowledge/check_docs.py`, and `git diff --check`.

## Validation and Acceptance

Acceptance requires:

- `Print...` and `Print All...` reach the native print panel or the closest automatable proof that `NSPrintOperation` is presented.
- Toolbar print controls use compact icon controls, not duplicated text buttons.
- Outline active-heading tracking avoids excessive state churn while fast-scrolling through many headings.
- Existing heading jump behavior still works.
- New or updated tests cover the changed print/outline behavior.
- Fresh App Store screenshot artifacts are generated for iPhone, iPad, and macOS where the local simulator/runtime environment allows it.
- App Store Connect text and screenshot updates are applied, or blockers are documented with exact missing credentials/API/version-state details.
- Focused validations and repo doc validators pass.

## Idempotence and Recovery

Printing and outline changes should be reversible by restoring the previous presenter/chrome/tracking code. App Store Connect updates should be made through the repo-owned API helpers so live state can be inspected before and after each mutation. If App Store Connect is not editable or credentials are unavailable, stop before making partial live-state changes and record the blocker.

## Artifacts and Notes

- Focused tests:
  - `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-print-outline-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMacPrintPresenterRetainsModalPrintOperationUntilCallback" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMacPrintToolbarUsesIconOnlyControls" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testDocumentOutlineTrackingDebouncesFastScrollUpdates" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testDocumentOutlineActiveRowUsesNavigationFocusStyle" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testActiveOutlineBlockIDTracksLastHeadingAtViewportTop" test`
  - `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-appstore-harness-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testLaunchOptionsParsePlatformAndPaths" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMacPrintToolbarUsesIconOnlyControls" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppStoreScreenshotHarnessCanOpenOutlineAndSearchStates" test`
  - `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-print-regression-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMacPrintOperationPDFOutputIsNotBlank" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExportPrintedDocumentHarnessCommandWritesPDF" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testExportPrintedMarkdownDocumentWithRichFeaturesWritesExpectedPDFContent" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMacPrintPresenterRetainsModalPrintOperationUntilCallback" test`
- Build and scripts:
  - `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-print-outline-build -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build`
  - `zsh -n scripts/capture-checkpoint && zsh -n scripts/capture-app-store-screenshots`
  - `./scripts/capture-app-store-screenshots --platform all`
- Manual print verification:
  - Launched `/tmp/qmv-print-outline-build/Build/Products/Debug/Quick Markdown Viewer.app` without `--ui-test-mode`, sent Command-P, and verified the native print sheet appeared.
  - Invoked `File > Print All...` with AppleScript and verified the native print sheet appeared.
- App Store Connect:
  - `./scripts/app-store-connect inspect-app`
  - `./scripts/app-store-connect request GET '/v1/apps/6761271951/appStoreVersions?fields[appStoreVersions]=platform,versionString,appStoreState,appVersionState,createdDate&limit=20'`
  - `./scripts/app-store-connect patch-version-localization --id c5b87990-6dc4-46ef-988f-40106acce062 --promotional-text ...`
  - `./scripts/app-store-connect patch-version-localization --id f2b07a8b-58bb-4841-a78b-cb41b320ab67 --promotional-text ...`
  - Attempted full localization patch and screenshot upload; both returned App Store Connect `409` state errors for locked live resources.

## Interfaces and Dependencies

- macOS print UI belongs in AppKit-backed `PlatformPrintPresenter`.
- iOS print UI belongs in the UIKit branch of `PlatformPrintPresenter`.
- Outline tracking uses SwiftUI preferences and `AppModel.activeOutlineBlockID`.
- App Store Connect writes depend on the local ASC key configuration consumed by `scripts/app-store-connect`.
