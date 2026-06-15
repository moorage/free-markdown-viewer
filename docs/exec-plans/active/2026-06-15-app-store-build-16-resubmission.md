# App Store Build 16 Resubmission

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Submit the current Quick Markdown Viewer tree after the nested header breadcrumb and sticky sidebar ancestor fixes. The release should put build `16` in front of App Review while preserving current App Store state: iOS `1.7` is still waiting for review and can be replaced, while macOS `1.7` is already live and needs a new `1.8` App Store version.

## Progress

- [x] (2026-06-15T07:24Z) Committed and pushed the nested header and sticky sidebar fixes to `main` as `9e4f38d`.
- [x] (2026-06-15T07:24Z) Inspected App Store Connect state: iOS `1.7` is `WAITING_FOR_REVIEW` on build `15`; macOS `1.7` is `READY_FOR_SALE` on build `15`.
- [x] (2026-06-15T07:24Z) Bumped checked-in build number to `16` and updated App Store metadata/review notes for nested file path and sticky sidebar ancestor behavior.

## Surprises & Discoveries

- Observation: macOS `1.7` completed review and is already ready for sale, while iOS `1.7` remains waiting for review.
  Evidence: App Store Connect returned iOS app-store-version `a28ca430-a671-4bbc-b5f0-917099cd3f76` as `WAITING_FOR_REVIEW` and macOS app-store-version `d53c7a88-53e5-4e84-b9c4-a171bb09e658` as `READY_FOR_SALE`.

## Decision Log

- Decision: Replace the pending iOS `1.7` submission with build `16`, and submit macOS as version `1.8` build `16`.
  Rationale: iOS already has an editable `1.7` review package, but macOS cannot attach a replacement build to a ready-for-sale version.
  Date/Author: 2026-06-15 / Codex

## Outcomes & Retrospective

In progress. The intended outcome is that iOS `1.7 (16)` and macOS `1.8 (16)` are both in an Apple-reviewable state with review notes that describe the nested header and sticky sidebar ancestor fixes.

## Context and Orientation

Relevant local surfaces:

- `scripts/archive-release`
- `scripts/export-app-store`
- `scripts/app-store-connect`
- `docs/release/app-store-metadata.md`
- `docs/release/app-review-notes.md`
- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`

Live App Store Connect app:

- App id: `6761271951`
- Bundle id: `com.souschefstudio.Free-Markdown-Viewer`
- iOS `1.7` version id: `a28ca430-a671-4bbc-b5f0-917099cd3f76`
- active iOS review submission id: `7f00482b-a753-45d2-993c-c8c6a6a36e73`
- macOS live `1.7` version id: `d53c7a88-53e5-4e84-b9c4-a171bb09e658`

## Plan of Work

1. Commit and push release metadata for build `16`.
2. Archive/export/upload iOS `1.7 (16)` and macOS `1.8 (16)`.
3. Poll App Store Connect until both build `16` records are valid and App Store eligible.
4. Cancel the active iOS build `15` review submission, attach iOS build `16`, update notes/localization, and resubmit.
5. Create macOS `1.8`, copy/update localization/review notes, attach macOS build `16`, and submit.
6. Verify final App Store Connect states and update `.agents/DOCUMENTATION.md` plus this plan.

## Concrete Steps

1. Run `./scripts/test-unit`, plan/docs checks, and `git diff --check` after metadata edits.
2. Commit and push build `16` metadata.
3. Run `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.7 APP_BUILD_NUMBER=16 ./scripts/archive-release --platform ios --allow-provisioning-updates`.
4. Run `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.8 APP_BUILD_NUMBER=16 ./scripts/archive-release --platform macos --allow-provisioning-updates`.
5. Export and upload both artifacts.
6. Use `scripts/app-store-connect request` to attach builds and submit review submissions.

## Validation and Acceptance

Acceptance requires:

- build `16` is uploaded, valid, and App Store eligible for both iOS and macOS
- iOS `1.7` is resubmitted or otherwise Apple-reviewable with build `16`
- macOS `1.8` is submitted or otherwise Apple-reviewable with build `16`
- release notes and review notes mention nested header paths and sticky sidebar ancestors
- `python3 scripts/check_execplan.py`, `python3 scripts/knowledge/check_docs.py`, and `git diff --check` pass before each commit

## Idempotence and Recovery

All App Store Connect writes must read current state before changing relationships or submissions. If a build upload succeeds but the command exits unclearly, query builds for `version=16` before retrying. If one platform submits and the other blocks, leave the submitted platform untouched and continue only from the failed platform's version/build/submission calls.

## Artifacts and Notes

Commands planned:

- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.7 APP_BUILD_NUMBER=16 ./scripts/archive-release --platform ios --allow-provisioning-updates`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.8 APP_BUILD_NUMBER=16 ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
- `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-06-15-app-store-build-16-resubmission.md`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`

## Interfaces and Dependencies

This work depends on local Apple signing credentials for team `GG34PA8F4A`, App Store Connect API credentials loaded by `scripts/lib/xcode-env.sh`, and Xcode Transporter/altool.
