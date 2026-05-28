# App Store 1.5 Build 12 Resubmission

This ExecPlan is a living document. Keep `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` current as the release proceeds.

## Purpose / Big Picture

Submit the current tree, including the macOS file-drop fixes and wide Markdown table performance fix, to App Store Connect. iOS and macOS version `1.5` are already `WAITING_FOR_REVIEW` on build `11`, so this work replaces that submitted build with a fresh build `12` on the existing editable `1.5` version lines.

## Progress

- [x] (2026-05-27T18:58Z) Verified App Store Connect app `6761271951` for bundle ID `com.souschefstudio.Free-Markdown-Viewer`.
- [x] (2026-05-27T18:58Z) Verified iOS `1.5` app-store-version `a87dc731-e48e-4f4e-9669-fe81c8130de1` and macOS `1.5` app-store-version `63537360-b39f-4168-87ad-57816bc4e355` are both `WAITING_FOR_REVIEW` on build `11`.
- [x] (2026-05-27T19:02Z) Bumped checked-in build metadata from `1.5 (11)` to `1.5 (12)` and updated release notes/review notes for the build `12` replacement fixes.
- [x] (2026-05-27T19:00Z) Release validation passed: `./scripts/test-unit`, `python3 scripts/check_execplan.py docs/exec-plans/active/2026-05-27-app-store-1-5-build-12-resubmission.md`, `python3 scripts/knowledge/check_docs.py`, and `git diff --check`.
- [x] (2026-05-27T20:01Z) Created signed iOS and macOS `1.5 (12)` archives under `artifacts/archives/`.
- [x] (2026-05-27T20:03Z) Exported signed iOS `.ipa` and macOS `.pkg` App Store artifacts under `artifacts/exports/`.
- [x] (2026-05-27T19:12Z) Uploaded both artifacts and confirmed App Store Connect build `12` records are `VALID`: iOS `70a546ba-8245-47cb-a7d6-7d331100189b`, macOS `c60e4aa9-b737-4088-9fc1-d6686894ed80`.
- [x] (2026-05-27T19:15Z) Canceled the active build `11` review submissions, attached build `12`, updated release notes/review notes, and resubmitted both platform versions.

## Surprises & Discoveries

- Observation: `1.5` is already submitted rather than still in `PREPARE_FOR_SUBMISSION`.
  Evidence: `/v1/apps/6761271951/appStoreVersions` reports both `1.5` platform versions as `WAITING_FOR_REVIEW`, and `/v1/reviewSubmissions` reports active iOS submission `a4b554ad-b16c-4514-9082-59298380acc9` plus macOS submission `6b201f2d-6a07-4abe-8835-325ce1fb22ac`.
- Observation: App Store Connect rejected simultaneous review-submission creation with `STATE_ERROR.CONCURRENT_REVIEW_SUBMISSION_TRY_AGAIN`.
  Evidence: the parallel macOS `POST /v1/reviewSubmissions` failed while the iOS submission was created; retrying macOS after iOS submission completed succeeded.

## Decision Log

- Decision: replace the existing `1.5` submissions with build `12` instead of creating `1.6`.
  Rationale: `1.5` is already the pending App Store version for both platforms, and a new version line is not needed just to include the latest current-tree fix.
- Decision: upload and validate build `12` before canceling active build `11` submissions.
  Rationale: this minimizes time with no submitted review package if archive/export/upload fails.
- Decision: create and submit the two fresh review submissions sequentially.
  Rationale: App Store Connect accepted the sequential path after rejecting concurrent submission creation.

## Outcomes & Retrospective

Completed. App Store Connect reports iOS `1.5` and macOS `1.5` in `WAITING_FOR_REVIEW` on valid build `12` records. The old build `11` review submissions are complete after cancellation.

## Context and Orientation

Relevant files:

- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`
- `docs/release/app-store-metadata.md`
- `docs/release/app-review-notes.md`
- `scripts/archive-release`
- `scripts/export-app-store`
- `scripts/app-store-connect`
- `.agents/DOCUMENTATION.md`

Relevant App Store Connect resources:

- app id: `6761271951`
- iOS `1.5` app-store-version id: `a87dc731-e48e-4f4e-9669-fe81c8130de1`
- iOS build `11` id: `8d4b08d2-846e-4ce5-9021-5966b1bd5d9c`
- iOS active review submission id: `a4b554ad-b16c-4514-9082-59298380acc9`
- iOS build `12` id: `70a546ba-8245-47cb-a7d6-7d331100189b`
- iOS build `12` review submission id: `88bcd955-359b-4fe0-8ad5-6f8b38f01f80`
- macOS `1.5` app-store-version id: `63537360-b39f-4168-87ad-57816bc4e355`
- macOS build `11` id: `107adfec-c796-45e2-b93b-591815a8eb91`
- macOS active review submission id: `6b201f2d-6a07-4abe-8835-325ce1fb22ac`
- macOS build `12` id: `c60e4aa9-b737-4088-9fc1-d6686894ed80`
- macOS build `12` review submission id: `61043c3f-9351-4eab-9377-5938c639a225`

## Plan of Work

1. Update local metadata to build `12` while keeping marketing version `1.5`.
2. Validate the release tree.
3. Archive and export signed App Store artifacts for iOS and macOS.
4. Upload both artifacts and query App Store Connect until build `12` records are valid.
5. Cancel active build `11` review submissions, attach build `12` to each existing `1.5` app-store-version, and create fresh submitted review submissions.
6. Record App Store Connect IDs and validation evidence.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Patch `CURRENT_PROJECT_VERSION = 12` in `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`.
2. Update release docs to mention the build `12` replacement fixes.
3. Run:
   - `./scripts/test-unit`
   - `python3 scripts/check_execplan.py docs/exec-plans/active/2026-05-27-app-store-1-5-build-12-resubmission.md`
   - `python3 scripts/knowledge/check_docs.py`
   - `git diff --check`
4. Archive and export:
   - `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform ios --allow-provisioning-updates`
   - `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
   - `./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
   - `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
5. Upload:
   - `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
   - `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
6. Use `scripts/app-store-connect request` to cancel active submissions, attach valid build `12` records, and submit fresh review submissions.

## Validation and Acceptance

Acceptance requires:

- checked-in project metadata reports `MARKETING_VERSION = 1.5` and `CURRENT_PROJECT_VERSION = 12`
- local release validation passes
- App Store Connect reports valid iOS and macOS build `12` records
- App Store Connect reports iOS `1.5` and macOS `1.5` fresh review submissions in `WAITING_FOR_REVIEW`

## Idempotence and Recovery

Archive/export steps overwrite release artifacts under `artifacts/`. If an upload succeeds but `altool` exits unclearly, query App Store Connect for build `12` before retrying. Do not cancel the active build `11` review submissions until valid build `12` records exist for both platforms.

If one platform submits and the other blocks, leave the submitted platform untouched and continue only from the failed platform's version/build/submission calls.

## Artifacts and Notes

- iOS archive: `artifacts/archives/Quick Markdown Viewer-ios.xcarchive`
- macOS archive: `artifacts/archives/Quick Markdown Viewer-macos.xcarchive`
- iOS export: `artifacts/exports/ios/Quick Markdown Viewer.ipa`
- macOS export: `artifacts/exports/macos/Quick Markdown Viewer.pkg`
- Final App Store Connect verification: iOS `1.5` and macOS `1.5` are `WAITING_FOR_REVIEW`, both attached build records are version `12` with `processingState` `VALID`.

## Interfaces and Dependencies

This work depends on:

- local Xcode archive/export tooling
- Apple signing team `GG34PA8F4A`
- App Store Connect API credentials loaded from the repo-local environment
- App Store Connect review submission APIs
- Apple's Transporter/altool upload service
