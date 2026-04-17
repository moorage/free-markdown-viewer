# App Store 1.1 Update

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Ship a fresh App Store update for both iOS and macOS now that GitHub-backed workspaces, remote inline media, and the macOS `qmv` command-line installer are implemented. The outcome should create new `1.1` App Store versions for both platforms, upload fresh build `5` binaries, update release-facing metadata to describe the shipped behavior accurately, attach the new builds, and return both platforms to a reviewable state.

## Progress

- [x] (2026-04-16T22:26Z) Audited the live App Store Connect state and confirmed both iOS and macOS are currently `READY_FOR_SALE` on version `1.0`, attached to builds `3` and `4` respectively.
- [x] (2026-04-16T22:31Z) Bumped the checked-in project marketing version to `1.1`, set the shared build number to `5`, and updated the repo-owned App Store metadata/review-note drafts for GitHub URL loading, remote media, and the macOS `qmv` installer.
- [x] (2026-04-16T22:29Z) Created live `1.1` App Store versions for iOS and macOS and patched their localized description, promotional text, `What's New`, and review-detail notes for the shipped GitHub/remote-media/CLI behavior.
- [x] (2026-04-16T22:38Z) Archived and exported signed `1.1 (5)` App Store artifacts for iOS and macOS, then uploaded the `.ipa` and `.pkg`; App Store Connect accepted iOS build `40dff4f5-c635-4e5c-ae3a-010ac4a9b709` and macOS build `10dc28e1-e0f1-4887-8d7f-f82d28040519`.
- [x] (2026-04-16T22:40Z) Attached the accepted build `5` records to the new `1.1` versions, created fresh review submissions for both platforms, and confirmed iOS and macOS are both `WAITING_FOR_REVIEW`.

## Surprises & Discoveries

- Observation: the live app is already fully released on both platforms, not just waiting for review.
  Evidence: `GET /v1/apps/6761271951/appStoreVersions` shows both the `IOS` and `MAC_OS` versions at `READY_FOR_SALE` / `READY_FOR_DISTRIBUTION`.

- Observation: the current released builds are split across platforms, with iOS still on build `3` and macOS on build `4`.
  Evidence: the live `IOS` version points to build resource `6206b37b-bed1-46bb-a89d-1c927bbf61fc` (`version: 3`), while the live `MAC_OS` version points to build resource `0b6dcdce-5342-4c40-90dc-2948d8e11634` (`version: 4`).

- Observation: the checked-in Xcode project had not been advanced after the prior Apple-side release work.
  Evidence: `Quick Markdown Viewer.xcodeproj/project.pbxproj` still carried `MARKETING_VERSION = 1.0` and `CURRENT_PROJECT_VERSION = 3` before this update work started.

- Observation: App Store package upload can succeed even when `altool --output-format json` crashes while serializing the macOS warning payload.
  Evidence: the macOS `xcrun altool --upload-package ... --output-format json` process terminated with `NSInvalidArgumentException: Invalid type in JSON write (NSError)` immediately after Transporter reported `UPLOAD SUCCEEDED with no errors, 1 warning`, and `GET /v1/builds?filter[preReleaseVersion.platform]=MAC_OS&filter[version]=5` showed accepted build `10dc28e1-e0f1-4887-8d7f-f82d28040519` in `VALID` state.

## Decision Log

- Decision: use App Store version `1.1` with shared build number `5` for both platforms.
  Rationale: both platforms are already live on `1.0`, and build `5` is the smallest single build number that cleanly exceeds both currently attached release builds.
  Date/Author: 2026-04-16 / Codex

- Decision: keep the release on the existing app record and existing live support/marketing URL slug.
  Rationale: the app record `6761271951` and the `free-markdown-viewer` website URLs are already live; this work is a feature update, not an identity migration.
  Date/Author: 2026-04-16 / Codex

## Outcomes & Retrospective

The `1.1` App Store update is now live in App Store Connect for both platforms and waiting on Apple review. The checked-in project advertises `1.1 (5)`, the version localizations describe GitHub snapshot loading, remote media, and the macOS `qmv` installer, and both fresh build records are attached to the prepared `1.1` versions.

The release pipeline remains reproducible from the repo, with one caveat: `altool` JSON output is not reliable for macOS uploads when Apple includes warning payloads. Future release runs should either omit `--output-format json` for macOS package uploads or treat ASC build discovery as the source of truth after Transporter reports a successful delivery UUID.

## Context and Orientation

Relevant resources:

- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`
- `docs/release/app-store-metadata.md`
- `docs/release/app-review-notes.md`
- `scripts/archive-release`
- `scripts/export-app-store`
- `scripts/app-store-connect`

Live App Store Connect resources already in use:

- app: `6761271951`
- app info localization: `9d483cad-13d7-445e-8869-cd6d548cfc23`
- current iOS version: `ad142231-153d-4b40-b149-bb55cd70b73e`
- current macOS version: `90e1bb1e-5a62-4623-a866-08b2b16262e2`

## Plan of Work

1. Advance the local release metadata to `1.1 (5)` and refresh the repo-owned listing/review text for the shipped feature set.
2. Create new App Store Connect `1.1` versions for both platforms and patch their localization/review-detail fields.
3. Archive, export, and upload fresh iOS and macOS App Store binaries as build `5`.
4. Attach the uploaded builds to the new versions, submit both platforms, and verify the resulting Apple-side state.

## Concrete Steps

1. Patch the checked-in Xcode version/build values and release docs.
2. `POST /v1/appStoreVersions` for `IOS` and `MAC_OS` with `versionString = 1.1`.
3. Read back the generated localization and review-detail resources for the new versions; create or patch them with the repo-owned text.
4. Run `./scripts/test-unit`.
5. Archive and export both platforms with `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_BUILD_NUMBER=5 APP_MARKETING_VERSION=1.1`.
6. Upload the exported `.ipa` and `.pkg` through `xcrun altool`.
7. Poll App Store Connect for the resulting build resources, attach them to the new `1.1` versions, and create/submit review submissions if required.
8. Re-run ExecPlan/docs validation after the control-plane docs are current.

## Validation and Acceptance

Acceptance requires:

- the checked-in project advertises `1.1 (5)`
- App Store Connect has fresh `1.1` iOS and macOS versions on app `6761271951`
- the new version-localization records carry `What's New` text for the GitHub/remote-media/CLI update
- build `5` is accepted for both iOS and macOS and attached to the new `1.1` versions
- both platforms are back in a reviewable or processing state appropriate for a fresh update
- `./scripts/test-unit`, `python3 scripts/check_execplan.py`, and `python3 scripts/knowledge/check_docs.py` pass

## Idempotence and Recovery

The local metadata patches are idempotent. Apple-side recovery should prefer read-before-write checks and attaching replacement builds to the newly created `1.1` versions rather than mutating or deleting the already released `1.0` versions.

## Artifacts and Notes

Planned release commands:

- `./scripts/test-unit`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.1 APP_BUILD_NUMBER=5 ./scripts/archive-release --platform ios --allow-provisioning-updates`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.1 APP_BUILD_NUMBER=5 ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `APP_MARKETING_VERSION=1.1 APP_BUILD_NUMBER=5 ./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
- `APP_MARKETING_VERSION=1.1 APP_BUILD_NUMBER=5 ./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`

## Interfaces and Dependencies

This release update depends on:

- the existing Xcode signing configuration for team `GG34PA8F4A`
- the repo-owned App Store Connect helper and API credentials in the local environment
- Apple archive/export tooling via `xcodebuild`
- Apple package upload via `xcrun altool`
