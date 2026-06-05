# App Store 1.6 Build 14 Submission

This ExecPlan is a living document. Keep `Progress`, `Surprises & Discoveries`,
`Decision Log`, and `Outcomes & Retrospective` current as the release proceeds.

## Purpose / Big Picture

Submit Quick Markdown Viewer `1.6 (14)` to App Store Connect for iOS/iPadOS and
macOS. The current live App Store versions are `1.5`, so this work creates fresh
`1.6` version lines, archives signed build `14` artifacts, uploads them, attaches
the valid builds, and submits both platforms for review.

This release includes the macOS Quick Look rendering fixes, Finder dropped-file
selection fixes, local image Quick Look attachments, inline Mermaid Quick Look
rendering, and removal of app-managed update checks.

## Progress

- [x] (2026-06-05T19:50Z) Confirmed `1.5` is `READY_FOR_SALE` for both platforms and there are no existing `1.6` App Store versions.
- [x] (2026-06-05T19:50Z) Bumped checked-in metadata to `MARKETING_VERSION = 1.6` and `CURRENT_PROJECT_VERSION = 14`.
- [x] (2026-06-05T19:50Z) Updated App Store metadata and App Review notes for the Quick Look and self-update removal release.

## Surprises & Discoveries

- Observation: App Store Connect already has a valid macOS build `13` uploaded on 2026-06-03 and attached to the live `1.5` version.
  Evidence: `/v1/builds?filter[app]=6761271951&sort=-uploadedDate` reports macOS build `a2d3517b-d8b4-4fcb-a859-7e2e3149459b` as build `13`, while both `1.5` app-store-version records are `READY_FOR_SALE`.

## Decision Log

- Decision: Use App Store version `1.6` and build number `14`.
  Rationale: `1.5` is already live and build `13` has already been uploaded, so the Quick Look fix needs a fresh marketing version and build number.
  Date/Author: 2026-06-05 / Codex

## Outcomes & Retrospective

Pending.

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
- current live iOS `1.5` app-store-version id: `a87dc731-e48e-4f4e-9669-fe81c8130de1`
- current live macOS `1.5` app-store-version id: `63537360-b39f-4168-87ad-57816bc4e355`

## Plan of Work

1. Commit and push local release metadata for `1.6 (14)`.
2. Run release validation.
3. Archive and export signed App Store artifacts for iOS and macOS.
4. Upload both artifacts and query App Store Connect until build `14` records are valid.
5. Create `1.6` App Store versions, patch metadata/review notes, attach the valid builds, and submit review submissions sequentially.
6. Record App Store Connect IDs and validation evidence.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Run:
   - `./scripts/test-unit`
   - `python3 scripts/check_execplan.py docs/exec-plans/active/2026-06-05-app-store-1-6-build-14-submission.md`
   - `python3 scripts/knowledge/check_docs.py`
   - `git diff --check`
2. Archive and export:
   - `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform ios --allow-provisioning-updates`
   - `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
   - `./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
   - `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
3. Upload:
   - `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
   - `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
4. Use `scripts/app-store-connect request` to create or update `1.6` versions, attach build `14`, patch release notes and review notes, and submit fresh review submissions.

## Validation and Acceptance

Acceptance requires:

- checked-in project metadata reports `MARKETING_VERSION = 1.6` and `CURRENT_PROJECT_VERSION = 14`
- local release validation passes
- App Store Connect reports valid iOS and macOS build `14` records
- App Store Connect reports iOS `1.6` and macOS `1.6` review submissions in `WAITING_FOR_REVIEW`

## Idempotence and Recovery

Archive/export steps overwrite release artifacts under `artifacts/`. If upload
succeeds but `altool` exits unclearly, query App Store Connect for build `14`
before retrying.

If one platform submits and the other blocks, leave the submitted platform
untouched and continue only from the failed platform's version/build/submission
calls.

## Artifacts and Notes

- iOS archive: `artifacts/archives/Quick Markdown Viewer-ios.xcarchive`
- macOS archive: `artifacts/archives/Quick Markdown Viewer-macos.xcarchive`
- iOS export: `artifacts/exports/ios/Quick Markdown Viewer.ipa`
- macOS export: `artifacts/exports/macos/Quick Markdown Viewer.pkg`

## Interfaces and Dependencies

This work depends on:

- local Xcode archive/export tooling
- Apple signing team `GG34PA8F4A`
- App Store Connect API credentials loaded from the repo-local environment
- App Store Connect review submission APIs
- Apple's Transporter/altool upload service
