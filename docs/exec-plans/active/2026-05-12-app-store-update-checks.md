# App Store Update Checks

## Purpose / Big Picture

The app should check the applicable App Store listing for a newer released version, encourage users to download it when available, let them skip the prompt once, and let them skip prompts until the next released version. On macOS, users should also be able to run a manual update check from the menu bar.

## Progress

- [x] (2026-05-12T00:00Z) Confirmed the product bundle identifier is `com.souschefstudio.Free-Markdown-Viewer` and the live App Store app ID is tracked in repo notes as `6761271951`.
- [x] (2026-05-12T19:22Z) Added an App Store lookup/update-checking service with injectable fetching and version comparison.
- [x] (2026-05-12T19:22Z) Added automatic non-blocking update checks and prompt state with skip and skip-until-next-version behavior.
- [x] (2026-05-12T19:22Z) Added macOS menu command for manual checks.
- [x] (2026-05-12T19:22Z) Added focused tests and validation evidence.

## Surprises & Discoveries

- Observation: the macOS app already has `com.apple.security.network.client` for remote media and GitHub workspaces.
  Evidence: `Quick_Markdown_Viewer.entitlements` includes `com.apple.security.network.client`.
- Observation: the app has no existing update-checking service or menu command.
  Evidence: searches for `AppStore`, `StoreKit`, and `Check for Updates` found no app code.
- Observation: the local Xcode install reports an out-of-date CoreSimulator framework, but macOS-hosted unit tests still run.
  Evidence: focused `xcodebuild ... test` emitted `CoreSimulator is out of date` and then completed the selected macOS tests successfully.
- Observation: after installing the iOS simulator runtime, iOS build and smoke validation now pass on healthy simulator devices.
  Evidence: `./scripts/build --platform ios` succeeded against the iOS 26.5 iPhone simulator, `./scripts/test-ui-ios --device both --smoke` passed the iPhone checkpoint and built iPad, and a manual iPad smoke run passed on the iOS 26.5 `iPad (A16)` simulator; the preferred `iPad Pro 11-inch (M5)` simulator hung in `simctl install`/`simctl launch`.

## Decision Log

- Decision: use a small App Store lookup client rather than StoreKit purchase APIs.
  Rationale: this app only needs to compare the released App Store version with the installed marketing version and open the store listing; it does not need purchase state.
- Decision: store only the skipped App Store version in `UserDefaults`.
  Rationale: "skip until next version" is naturally keyed by the version the user skipped, while one-time skip should only dismiss the current prompt in memory.
- Decision: perform automatic checks asynchronously on app launch/active and surface results through SwiftUI alerts.
  Rationale: update checks should never block document loading or rendering.

## Outcomes & Retrospective

The app now owns `AppUpdateChecker`, an injectable service that queries Apple's lookup endpoint, compares the released App Store version against the installed marketing version, and publishes SwiftUI alert state. Automatic checks run asynchronously and silently ignore lookup failures. Manual checks, exposed on macOS through `Check for Updates…`, show update, up-to-date, or error alerts. Users can dismiss a prompt once or skip prompts until the App Store reports a later version.

## Context and Orientation

Relevant code:

- `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift` owns app scene and macOS commands.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift` owns scene lifecycle and alert presentation.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift` owns app chrome but should not perform network work directly.
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift` owns focused shared-service tests.

## Plan of Work

1. Add a shared `AppUpdateChecker` service that builds App Store lookup URLs, decodes lookup responses, compares dotted versions, and tracks prompt state.
2. Inject the service into the app root and scene root.
3. Trigger one automatic check per launch/active session without blocking document loading.
4. Present update, up-to-date, and error alerts with actions to download, skip, or skip until the next version.
5. Add a macOS `Check for Updates…` command that invokes a manual check.
6. Add focused tests for version comparison, lookup URL construction, skip-until-next-version, and manual/automatic result behavior.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Add `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppUpdateChecker.swift`.
2. Edit `Quick_Markdown_ViewerApp.swift` and `WindowSceneRootView.swift`.
3. Add tests in `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`.
4. Run `python3 scripts/check_execplan.py`.
5. Run focused unit tests for update checking.
6. Run the repository's narrow build/test validation for touched app code.

Validation completed from `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-outline-csv-update-unit -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownOutlineItemsUseHeadingBlocksInDocumentOrder" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppModelPublishesOutlineItemsForLoadedMarkdownDocument" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testDelimitedTextParserUsesPlainTextTableCellsForLargeCSV" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppStoreLookupConfigurationBuildsPlatformLookupURL" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppUpdateVersionComparisonUsesNumericSegments" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppUpdateCheckerManualCheckPromptsWhenAppStoreVersionIsNewer" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppUpdateCheckerSkipsAutomaticPromptUntilNextVersion" test`
2. `python3 scripts/check_execplan.py`
3. `python3 scripts/knowledge/check_docs.py`
4. `./scripts/test-unit`
5. `./scripts/build --platform all` (macOS build succeeded; iOS builds were skipped by the script because simulator platform discovery is unavailable)
6. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -sdk iphonesimulator -configuration Debug -derivedDataPath /tmp/qmv-outline-csv-update-ios-build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` (blocked by missing simulator runtime for asset catalog compilation)
7. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -sdk iphoneos -destination "generic/platform=iOS" -configuration Debug -derivedDataPath /tmp/qmv-outline-csv-update-ios-device-build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build` (blocked by missing iOS 26.5 platform)
8. `./scripts/build --platform ios`
9. `./scripts/test-ui-ios --device both --smoke` (iPhone smoke passed; iPad build passed, then the preferred `iPad Pro 11-inch (M5)` simulator hung in `simctl launch`)
10. Manual iPad smoke on `iPad (A16)` simulator `C1DAE170-A0B7-44F1-A23E-B0697677435A` passed and wrote `artifacts/checkpoints/shell-smoke-ipad-manual/`

## Validation and Acceptance

Acceptance:

- Automatic update checks do not block app launch, workspace loading, or document rendering.
- When the App Store version is newer, the app presents a download prompt.
- Users can dismiss the prompt for now.
- Users can skip the prompt until a later App Store version appears.
- macOS exposes a menu-bar item to check for updates manually.
- Manual checks report up-to-date and error states instead of silently doing nothing.

## Idempotence and Recovery

The update checker only reads App Store metadata and writes a skipped version string to `UserDefaults`. If the lookup endpoint is unavailable, manual checks should show a clear error and automatic checks should avoid interrupting the user.

## Artifacts and Notes

No generated artifacts are expected. Runtime build/test outputs remain under `artifacts/` or the selected Xcode derived-data path.

## Interfaces and Dependencies

- Network dependency: Apple App Store lookup endpoint over HTTPS.
- Opens the App Store listing URL through the platform URL-opening APIs.
- No database or migration work.
