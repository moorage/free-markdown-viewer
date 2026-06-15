# App Store Build 16 Resubmission

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Submit the current Quick Markdown Viewer tree after the nested header breadcrumb and sticky sidebar ancestor fixes. The release should put build `16` in front of App Review while preserving current App Store state: iOS `1.7` is still waiting for review and can be replaced, while macOS `1.7` is already live and needs a new `1.8` App Store version.

## Progress

- [x] (2026-06-15T07:24Z) Committed and pushed the nested header and sticky sidebar fixes to `main` as `9e4f38d`.
- [x] (2026-06-15T07:24Z) Inspected App Store Connect state: iOS `1.7` is `WAITING_FOR_REVIEW` on build `15`; macOS `1.7` is `READY_FOR_SALE` on build `15`.
- [x] (2026-06-15T07:24Z) Bumped checked-in build number to `16` and updated App Store metadata/review notes for nested file path and sticky sidebar ancestor behavior.
- [x] (2026-06-15T07:32Z) Validated release-prep changes with `./scripts/test-unit`, `python3 scripts/check_execplan.py docs/exec-plans/active/2026-06-15-app-store-build-16-resubmission.md`, `python3 scripts/knowledge/check_docs.py`, `plutil -lint`, and `git diff --check`.
- [x] (2026-06-15T07:33Z) Committed and pushed release-prep changes to `main` as `12fe726`.
- [x] (2026-06-15T07:42Z) Archived, exported, uploaded, and validated iOS `1.7 (16)` and macOS `1.8 (16)`.
- [x] (2026-06-15T07:46Z) Replaced the pending iOS `1.7` review package with build `16` and submitted new macOS `1.8` build `16`; both submissions are `WAITING_FOR_REVIEW`.

## Surprises & Discoveries

- Observation: macOS `1.7` completed review and is already ready for sale, while iOS `1.7` remains waiting for review.
  Evidence: App Store Connect returned iOS app-store-version `a28ca430-a671-4bbc-b5f0-917099cd3f76` as `WAITING_FOR_REVIEW` and macOS app-store-version `d53c7a88-53e5-4e84-b9c4-a171bb09e658` as `READY_FOR_SALE`.
- Observation: New macOS versions copy the existing localization, review detail, and screenshot set forward.
  Evidence: macOS `1.8` created localization `871d0080-e615-4931-bece-dd534e167e7e`, review detail `b226d0cd-b3b4-4d1f-a5cc-df6397426f35`, and desktop screenshot set `d663c5ff-43c2-44db-a0a1-abbc4b610722` with nine complete screenshots.

## Decision Log

- Decision: Replace the pending iOS `1.7` submission with build `16`, and submit macOS as version `1.8` build `16`.
  Rationale: iOS already has an editable `1.7` review package, but macOS cannot attach a replacement build to a ready-for-sale version.
  Date/Author: 2026-06-15 / Codex

## Outcomes & Retrospective

iOS `1.7 (16)` and macOS `1.8 (16)` are both in `WAITING_FOR_REVIEW` with build `16` attached, updated `What's New` text, and review notes describing full nested header paths plus sticky sidebar ancestor folders.

Final App Store Connect resources:

- iOS app-store-version: `a28ca430-a671-4bbc-b5f0-917099cd3f76`
- iOS build: `95341617-a44e-4407-a5b4-4ab728306eb1`
- iOS review submission: `a206008a-181a-4007-9b2e-a089cdbe8c02`
- macOS app-store-version: `772f1e8e-310e-49cb-8761-8b7f777c04a7`
- macOS build: `b10fa1d8-0278-40c1-bd97-fe1c3e96ddb8`
- macOS review submission: `ffdfa1d2-6232-405e-9293-ef0786194ff1`

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
- iOS build `16` id: `95341617-a44e-4407-a5b4-4ab728306eb1`
- active iOS review submission id: `a206008a-181a-4007-9b2e-a089cdbe8c02`
- macOS live `1.7` version id: `d53c7a88-53e5-4e84-b9c4-a171bb09e658`
- macOS `1.8` version id: `772f1e8e-310e-49cb-8761-8b7f777c04a7`
- macOS build `16` id: `b10fa1d8-0278-40c1-bd97-fe1c3e96ddb8`
- active macOS review submission id: `ffdfa1d2-6232-405e-9293-ef0786194ff1`

## Plan of Work

1. Commit and push release metadata for build `16`. Done.
2. Archive/export/upload iOS `1.7 (16)` and macOS `1.8 (16)`. Done.
3. Poll App Store Connect until both build `16` records are valid and App Store eligible. Done.
4. Cancel the active iOS build `15` review submission, attach iOS build `16`, update notes/localization, and resubmit. Done.
5. Create macOS `1.8`, copy/update localization/review notes, attach macOS build `16`, and submit. Done.
6. Verify final App Store Connect states and update `.agents/DOCUMENTATION.md` plus this plan. Done.

## Concrete Steps

1. Ran `./scripts/test-unit`, plan/docs checks, and `git diff --check` after metadata edits.
2. Committed and pushed build `16` metadata as `12fe726`.
3. Ran `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.7 APP_BUILD_NUMBER=16 ./scripts/archive-release --platform ios --allow-provisioning-updates`.
4. Ran `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.8 APP_BUILD_NUMBER=16 ./scripts/archive-release --platform macos --allow-provisioning-updates`.
5. Exported and uploaded both artifacts.
6. Used `scripts/app-store-connect request` to attach builds and submit review submissions.

## Validation and Acceptance

Acceptance requires:

- build `16` is uploaded, valid, and App Store eligible for both iOS and macOS. Met.
- iOS `1.7` is resubmitted or otherwise Apple-reviewable with build `16`. Met.
- macOS `1.8` is submitted or otherwise Apple-reviewable with build `16`. Met.
- release notes and review notes mention nested header paths and sticky sidebar ancestors. Met.
- `python3 scripts/check_execplan.py`, `python3 scripts/knowledge/check_docs.py`, and `git diff --check` pass before each commit. Met before the release-prep commit; final documentation checks pass after this completion update.

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
