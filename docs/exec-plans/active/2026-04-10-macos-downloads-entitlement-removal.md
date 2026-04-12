# macOS Downloads Entitlement Removal

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Resolve the April 10, 2026 macOS App Review blocker for Quick Markdown Viewer by removing the unused Downloads-folder read entitlement from the signed app. The shipped macOS experience should continue to work through user-selected folder access only, and the resulting archive should present a smaller sandbox surface that matches the app's actual behavior.

## Progress

- [x] (2026-04-10T22:05Z) Audited the macOS target, runtime folder-open flow, and latest archived entitlements to confirm the review issue and identify the entitlement source.
- [x] (2026-04-10T22:11Z) Removed the macOS Downloads-folder sandbox capability from the Xcode target, updated the App Review notes draft, and recorded the submission fix in the control-plane docs.
- [x] (2026-04-10T22:11Z) Re-archived the macOS app, verified the signed entitlements now contain only app sandbox plus user-selected read-only file access, and updated the live macOS App Review note in App Store Connect.
- [x] (2026-04-10T17:24Z) Archived and exported a replacement macOS App Store build as version `1.0 (4)`, uploaded package `Quick Markdown Viewer.pkg`, and confirmed App Store Connect accepted build `0b6dcdce-5342-4c40-90dc-2948d8e11634`.
- [x] (2026-04-10T17:30Z) Reattached macOS version `90e1bb1e-5a62-4623-a866-08b2b16262e2` to build `4`, canceled stale review submission `10966674-994a-4ade-9028-f9030ca5d711`, created fresh review submission `bf2a205e-cf59-44a5-9478-3dce13037126`, and returned macOS to `WAITING_FOR_REVIEW`.
- [x] (2026-04-11T09:55Z) Confirmed the April 11, 2026 rejection is not a binary regression, but a follow-up request for a clearer justification of `com.apple.security.files.user-selected.read-only`; updated the local review-note draft and prepared a more explicit App Review explanation tied to the macOS `Open Folder` flow.
- [x] (2026-04-11T10:08Z) Patched the live macOS `appStoreReviewDetail` note with explicit first-launch and `File > Open Folder…` reviewer steps, then re-ran ExecPlan and docs validation successfully.

## Surprises & Discoveries

- Observation: the macOS archive currently carries the exact extra entitlement Apple flagged in review.
  Evidence: `codesign -d --entitlements :- 'artifacts/archives/Free Markdown Viewer-macos.xcarchive/Products/Applications/Free Markdown Viewer.app'` prints `com.apple.security.files.downloads.read-only` alongside `com.apple.security.files.user-selected.read-only`.

- Observation: the app code only opens folders the user chooses and persists those permissions through security-scoped bookmarks; it does not contain a direct Downloads-folder access path.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift` uses `NSOpenPanel` on macOS and `.fileImporter` on iOS, while `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceSecurityScope.swift` handles security-scoped bookmarks.

- Observation: the unwanted entitlement is generated directly from the Xcode target build settings rather than from a checked-in `.entitlements` file.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj` sets `ENABLE_FILE_ACCESS_DOWNLOADS_FOLDER = readonly` in both app-target configurations, and the repository has no checked-in app entitlements file.

- Observation: the macOS App Store version is already rejected in App Store Connect, so a manual "Developer Reject" action is no longer needed before attaching a replacement build.
  Evidence: `./scripts/app-store-connect request GET /v1/apps/6761271951/appStoreVersions --query include=build,appStoreVersionLocalizations,appStoreReviewDetail` returns the `MAC_OS` version with `appStoreState` and `appVersionState` both set to `REJECTED`.

- Observation: after attaching the replacement build, App Store Connect still considered the macOS version part of the old unresolved-issues review submission until that submission was explicitly canceled.
  Evidence: the first `POST /v1/reviewSubmissionItems` attempt for the fresh draft submission failed with `STATE_ERROR.ITEM_PART_OF_ANOTHER_SUBMISSION`, naming stale review submission `10966674-994a-4ade-9028-f9030ca5d711`; after `PATCH /v1/reviewSubmissions/10966674-994a-4ade-9028-f9030ca5d711` with `canceled: true` reached `COMPLETE`, the same item-create call succeeded.

- Observation: the April 11, 2026 App Review follow-up names only `com.apple.security.files.user-selected.read-only`, while the signed archive still contains exactly the expected minimal entitlement set.
  Evidence: `./scripts/app-store-connect request GET /v1/appStoreVersions/90e1bb1e-5a62-4623-a866-08b2b16262e2 --query include=appStoreReviewDetail,build` shows the rejected macOS version still attached to build `0b6dcdce-5342-4c40-90dc-2948d8e11634`, and `codesign -d --entitlements :- 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive/Products/Applications/Quick Markdown Viewer.app'` prints only `com.apple.security.app-sandbox` plus `com.apple.security.files.user-selected.read-only`.

- Observation: the live App Review note explains user-selected folder access, but it does not explicitly tell the reviewer that macOS first launch auto-presents `Open Folder`, that the same action also exists in the `File` menu as `Open Folder…` with `Command-O`, or that the entitlement exists specifically to read the selected folder and its Markdown/media contents.
  Evidence: the App Store Connect `appStoreReviewDetail` note for resource `d9779019-7bf4-4632-a046-f114d364782a` contains only generic wording about user-selected folders, while `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift` auto-calls `openFolder()` on first appearance, configures `NSOpenPanel`, and exposes `Open Folder…` in `WindowOpenFolderCommands`.

## Decision Log

- Decision: remove the Downloads-folder entitlement instead of replying to App Review with a justification for it.
  Rationale: the app does not need blanket Downloads access because the product flow is based on user-selected folders and security-scoped bookmarks. A narrower sandbox is both correct and lower risk for review.
  Date/Author: 2026-04-10 / Codex

- Decision: keep `com.apple.security.files.user-selected.read-only` and strengthen the App Review explanation instead of removing the entitlement or changing the binary again.
  Rationale: the entitlement matches the real macOS product flow: the app opens a folder chosen by the user via `NSOpenPanel`, reads Markdown and local media from that folder, and persists access with security-scoped bookmarks. The current blocker is reviewer clarity, not an oversized sandbox request.
  Date/Author: 2026-04-11 / Codex

## Outcomes & Retrospective

The repository now requests only the file-access capability that matches the app's documented product behavior: read-only access to user-selected folders. This keeps the macOS sandbox model aligned across code, review notes, signing configuration, and the live App Review note in App Store Connect.

The rebuilt archive validates the fix directly. `codesign -d --entitlements :- 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive/Products/Applications/Quick Markdown Viewer.app'` now reports only `com.apple.security.app-sandbox` and `com.apple.security.files.user-selected.read-only`.

The release path also completed end to end. App Store Connect accepted the replacement macOS build as `1.0 (4)` with build resource `0b6dcdce-5342-4c40-90dc-2948d8e11634`, the macOS app-store version now points at that build, and review submission `bf2a205e-cf59-44a5-9478-3dce13037126` is back in `WAITING_FOR_REVIEW`.

The main lesson is that App Review-facing sandbox issues can hide in Xcode capability build settings even when there is no explicit `.entitlements` file in the repository. Future release checks should inspect the archived entitlements, not just source searches, before upload.

The April 11, 2026 follow-up changes the interpretation of the remaining work. The rejection is no longer about an unnecessary broad entitlement; it is a request for a clearer explanation of why the app still needs the narrower user-selected read-only entitlement. The live App Review note is now updated with exact reviewer steps and entitlement rationale, so the next escalation would be a UI-level reviewer reply or a more explicit in-app affordance only if Apple still does not accept the existing folder-open flow.

## Context and Orientation

Relevant files and artifacts:

- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceSecurityScope.swift`
- `docs/release/app-review-notes.md`
- `artifacts/archives/Free Markdown Viewer-macos.xcarchive/Products/Applications/Free Markdown Viewer.app`

## Plan of Work

1. Confirm the review issue against the archive and trace the entitlement back to the app target configuration.
2. Remove the unused Downloads capability while preserving user-selected-folder access.
3. Re-archive the macOS build and inspect the signed entitlements to verify the sandbox surface is corrected.
4. Update the release-facing notes so the App Review explanation matches the new binary.

## Concrete Steps

1. Inspect the archive with `codesign -d --entitlements :-`.
2. Remove `ENABLE_FILE_ACCESS_DOWNLOADS_FOLDER` from the app target build settings.
3. Re-run `./scripts/archive-release --platform macos --allow-provisioning-updates`.
4. Re-inspect the rebuilt archive entitlements and record the result.
5. Run `python3 scripts/check_execplan.py` and `python3 scripts/knowledge/check_docs.py`.

## Validation and Acceptance

Acceptance requires:

- the app target no longer enables the Downloads-folder sandbox capability
- the rebuilt macOS archive entitlements omit `com.apple.security.files.downloads.read-only`
- the rebuilt macOS archive still includes `com.apple.security.files.user-selected.read-only`
- App Review notes describe user-selected folder access rather than blanket Downloads access
- `python3 scripts/check_execplan.py` and `python3 scripts/knowledge/check_docs.py` pass

## Idempotence and Recovery

Removing the capability is idempotent. If a future product change truly requires Downloads-folder access, recovery is to add the capability back deliberately with matching in-app functionality and updated App Review notes before the next submission.

## Artifacts and Notes

Planned validation commands:

- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `APP_BUILD_NUMBER=4 APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `APP_BUILD_NUMBER=4 ./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key \"$ASC_KEY_ID\" --api-issuer \"$ASC_ISSUER_ID\" --p8-file-path \"$ASC_KEY_PATH\" --api-key-subject user --wait --output-format json`
- `codesign -d --entitlements :- 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive/Products/Applications/Quick Markdown Viewer.app'`
- `./scripts/app-store-connect patch-review-detail --id d9779019-7bf4-4632-a046-f114d364782a ...`
- `./scripts/app-store-connect request PATCH /v1/appStoreVersions/90e1bb1e-5a62-4623-a866-08b2b16262e2/relationships/build --body '{\"data\":{\"type\":\"builds\",\"id\":\"0b6dcdce-5342-4c40-90dc-2948d8e11634\"}}'`
- `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/10966674-994a-4ade-9028-f9030ca5d711 --body '{\"data\":{\"type\":\"reviewSubmissions\",\"id\":\"10966674-994a-4ade-9028-f9030ca5d711\",\"attributes\":{\"canceled\":true}}}'`
- `./scripts/app-store-connect request POST /v1/reviewSubmissions --body '{\"data\":{\"type\":\"reviewSubmissions\",\"attributes\":{\"platform\":\"MAC_OS\"},\"relationships\":{\"app\":{\"data\":{\"type\":\"apps\",\"id\":\"6761271951\"}}}}}'`
- `./scripts/app-store-connect request POST /v1/reviewSubmissionItems --body '{\"data\":{\"type\":\"reviewSubmissionItems\",\"relationships\":{\"reviewSubmission\":{\"data\":{\"type\":\"reviewSubmissions\",\"id\":\"bf2a205e-cf59-44a5-9478-3dce13037126\"}},\"appStoreVersion\":{\"data\":{\"type\":\"appStoreVersions\",\"id\":\"90e1bb1e-5a62-4623-a866-08b2b16262e2\"}}}}}'`
- `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/bf2a205e-cf59-44a5-9478-3dce13037126 --body '{\"data\":{\"type\":\"reviewSubmissions\",\"id\":\"bf2a205e-cf59-44a5-9478-3dce13037126\",\"attributes\":{\"submitted\":true}}}'`
- `./scripts/test-unit`
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-04-10-macos-downloads-entitlement-removal.md`
- `python3 scripts/knowledge/check_docs.py`

## Interfaces and Dependencies

This fix relies on:

- Xcode app-target sandbox capability build settings
- the existing macOS open-folder flow in SwiftUI/AppKit
- the existing release archive helper in `scripts/archive-release`
- Apple code-signing during archive generation
