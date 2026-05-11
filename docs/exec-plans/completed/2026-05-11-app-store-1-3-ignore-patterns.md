# App Store 1.3 Ignore Patterns Submission

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Submit the latest window-scoped ignore-pattern feature to App Store Review for both iOS and macOS. The outcome should publish fresh `1.3` App Store versions for app `6761271951`, upload build `9` for both platforms, attach the accepted builds, and leave both review submissions in an Apple-reviewable state.

## Progress

- [x] (2026-05-11T00:00Z) Confirmed the working tree was clean on `main` after pushing commit `a4c3d7b Add window-scoped ignore patterns`.
- [x] (2026-05-11T00:00Z) Inspected App Store Connect and confirmed iOS and macOS `1.2` are already `READY_FOR_SALE`, so the new code needs a fresh version number rather than another `1.2` submission.
- [x] (2026-05-11T00:00Z) Advanced the checked-in project to `1.3 (9)` and updated repo-owned release metadata/review notes for the ignore-pattern feature.
- [x] (2026-05-11T21:02Z) Uploaded iOS build `44cc4949-6f6f-401c-ba7a-bb72a0b7ed2a` and macOS build `27561f24-2a27-472b-8d4c-12ee995d8e00`; both are App Store eligible and `VALID`.
- [x] (2026-05-11T21:08Z) Created `1.3` App Store versions for iOS and macOS, attached the accepted build `9` binaries, patched localization/review notes, and submitted both review submissions.
- [x] (2026-05-11T21:09Z) Verified both `1.3` platform versions are `WAITING_FOR_REVIEW`.

## Surprises & Discoveries

- Observation: App Store Connect already shows both current `1.2` platform versions as released.
  Evidence: `/v1/apps/6761271951/appStoreVersions?include=appStoreVersionLocalizations,appStoreReviewDetail,build` reports the `IOS` and `MAC_OS` `1.2` versions as `READY_FOR_SALE`.

- Observation: the latest uploaded build remains macOS build `8`; no build `9` exists yet.
  Evidence: `/v1/builds?filter[app]=6761271951&sort=-uploadedDate&include=preReleaseVersion` returns macOS build `e0f52044-0e2e-4e84-a5fe-118550cc39dd` as the newest record, with version `8`.

- Observation: macOS transport completed with Apple's existing document-type warning, but the uploaded build is valid and reviewable.
  Evidence: `xcrun altool --upload-package artifacts/exports/macos/Quick Markdown Viewer.pkg --wait` reported `BUILD-STATUS: VALID` and warning `90788` for missing `LSHandlerRank` on the `Folder` document type.

## Decision Log

- Decision: use App Store version `1.3` with shared build number `9`.
  Rationale: `1.2` is already live on both platforms and build `9` is the next single build number above the current macOS build `8`.
  Date/Author: 2026-05-11 / Codex

## Outcomes & Retrospective

The `1.3 (9)` App Store update is submitted for Apple review on both platforms. iOS version `8bd70b08-cd79-43e8-9676-86ad768cd0df` is attached to build `44cc4949-6f6f-401c-ba7a-bb72a0b7ed2a`; macOS version `9a04ddf5-0e75-48fb-9262-29b83d34aed4` is attached to build `27561f24-2a27-472b-8d4c-12ee995d8e00`. Review submissions `eaf4a1cd-40a8-449c-b76e-13c2434acc96` for iOS and `af1ed877-498c-4808-b9ed-11d7e9aa40cf` for macOS are both `WAITING_FOR_REVIEW`.

## Context and Orientation

Relevant resources:

- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`
- `docs/release/app-store-metadata.md`
- `docs/release/app-review-notes.md`
- `scripts/archive-release`
- `scripts/export-app-store`
- `scripts/app-store-connect`

Live App Store Connect resources:

- app: `6761271951`
- bundle id: `com.souschefstudio.Free-Markdown-Viewer`
- development team: `GG34PA8F4A`
- iOS `1.3` version: `8bd70b08-cd79-43e8-9676-86ad768cd0df`
- macOS `1.3` version: `9a04ddf5-0e75-48fb-9262-29b83d34aed4`
- iOS build `9`: `44cc4949-6f6f-401c-ba7a-bb72a0b7ed2a`
- macOS build `9`: `27561f24-2a27-472b-8d4c-12ee995d8e00`
- iOS review submission: `eaf4a1cd-40a8-449c-b76e-13c2434acc96`
- macOS review submission: `af1ed877-498c-4808-b9ed-11d7e9aa40cf`

## Plan of Work

1. Advance local release metadata to `1.3 (9)` and update release/review text.
2. Validate the checked-in release state with unit tests, docs checks, and all-platform builds.
3. Archive, export, and upload signed App Store artifacts for iOS and macOS.
4. Create or locate `1.3` App Store versions, patch localizations/review details, attach build `9`, and submit review submissions.
5. Commit and push the release-state changes after Apple-side submission is verified.

## Concrete Steps

1. Patch project version/build values and release docs.
2. Run `./scripts/test-unit`, `./scripts/build --platform all`, `python3 scripts/check_execplan.py`, and `python3 scripts/knowledge/check_docs.py`.
3. Archive/export both platforms with `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.3 APP_BUILD_NUMBER=9`.
4. Upload the exported `.ipa` and `.pkg` through `xcrun altool`.
5. Poll App Store Connect for accepted iOS/macOS build `9` records.
6. Create or reuse `1.3` App Store versions, patch metadata, attach builds, and submit review submissions.

## Validation and Acceptance

Acceptance requires:

- the checked-in project advertises `1.3 (9)`
- App Store Connect has `1.3` iOS and macOS versions on app `6761271951`
- build `9` is accepted for both iOS and macOS and attached to those versions
- both platforms are submitted or in an Apple-reviewable processing state
- release metadata mentions the new per-window ignore-pattern behavior
- release validation commands pass or any environment failure is documented

## Idempotence and Recovery

Local edits are idempotent. Apple-side steps should always read current resources before write operations, reuse existing `1.3` draft versions if already present, and attach replacement build `9` records rather than mutating released `1.2` versions.

## Artifacts and Notes

Planned release commands:

- `./scripts/test-unit`
- `./scripts/build --platform all`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.3 APP_BUILD_NUMBER=9 ./scripts/archive-release --platform ios --allow-provisioning-updates`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.3 APP_BUILD_NUMBER=9 ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `APP_MARKETING_VERSION=1.3 APP_BUILD_NUMBER=9 ./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
- `APP_MARKETING_VERSION=1.3 APP_BUILD_NUMBER=9 ./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait`
- `./scripts/app-store-connect request POST /v1/appStoreVersions ... versionString=1.3 platform=IOS`
- `./scripts/app-store-connect request POST /v1/appStoreVersions ... versionString=1.3 platform=MAC_OS`
- `./scripts/app-store-connect request PATCH /v1/appStoreVersions/8bd70b08-cd79-43e8-9676-86ad768cd0df/relationships/build ...`
- `./scripts/app-store-connect request PATCH /v1/appStoreVersions/9a04ddf5-0e75-48fb-9262-29b83d34aed4/relationships/build ...`
- `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/eaf4a1cd-40a8-449c-b76e-13c2434acc96 ... submitted=true`
- `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/af1ed877-498c-4808-b9ed-11d7e9aa40cf ... submitted=true`

## Interfaces and Dependencies

This release depends on:

- App Store Connect API credentials from `scripts/lib/xcode-env.sh`
- Apple signing team `GG34PA8F4A`
- Xcode archive/export tooling
- Apple package upload via `xcrun altool`
