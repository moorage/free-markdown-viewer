# App Store 1.7 Build 15 Submission

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Submit the current Quick Markdown Viewer tree to App Store Review for both iOS and macOS. The release should ship the structured JSON-family viewer, JSON/JSONC/NDJSON/JSONL Quick Look improvements, and the corrected cold-start `qmv /path/to/file` behavior. The App Store listing should include screenshots for features not covered by the current seven-shot set, specifically structured JSON viewing and the command-line launcher workflow.

## Progress

- [x] (2026-06-14T18:44Z) Inspected App Store Connect and confirmed both iOS and macOS `1.6` are already `READY_FOR_SALE` with build `14`, so the current submission needs fresh editable `1.7` platform versions and build `15`.
- [x] (2026-06-14T18:44Z) Audited the current screenshot set and found it covers folders, outline, search, Mermaid, CSV, media, code/print/Quick Look, but not the structured JSON viewer or `qmv` launcher workflow.
- [x] (2026-06-14T18:59Z) Added App Store screenshot fixtures for structured JSON and `qmv`, expanded the capture set to nine shots, and regenerated complete iPhone, iPad, and macOS screenshot artifacts.
- [x] (2026-06-14T18:59Z) Archived, exported, uploaded, and validated iOS and macOS `1.7 (15)` builds through Transporter.
- [x] (2026-06-14T18:59Z) Created iOS and macOS App Store version `1.7` records, patched metadata/review details, uploaded nine complete screenshots for iPhone/iPad/macOS, attached build `15`, and submitted both review submissions.

## Surprises & Discoveries

- Observation: App Store Connect has no existing `1.7` platform version.
  Evidence: `./scripts/app-store-connect request GET /v1/apps/6761271951/appStoreVersions --query 'filter[versionString]=1.7' ...` returned an empty `data` array.

- Observation: the checked-in project still carries `MARKETING_VERSION = 1.6` and `CURRENT_PROJECT_VERSION = 14`.
  Evidence: `rg -n "MARKETING_VERSION|CURRENT_PROJECT_VERSION" "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj"` reports `1.6` and `14` across the app, Quick Look extension, and test targets.

- Observation: macOS screenshot capture fails when launched with the current all-documents search harness arguments, even though the same fixture captures with the sidebar open.
  Evidence: `./scripts/capture-checkpoint --fixture 'Full Text Search.md' ... --ui-test-search-query lifecycle --ui-test-search-scope allDocuments` ended with `state.json missing`, while the same fixture without the search arguments captured successfully.

- Observation: App Store Connect enforces a 170-character promotional text limit.
  Evidence: the first `patch-version-localization` call returned `ENTITY_ERROR.ATTRIBUTE.INVALID.TOO_LONG` for `/data/attributes/promotionalText`; shortening the checked-in promotional text to 147 characters allowed both localization patches to pass.

## Decision Log

- Decision: use App Store version `1.7` and build number `15` for both iOS and macOS.
  Rationale: `1.6 (14)` is already live on both platforms. A new editable App Store version is required for updated screenshots, metadata, and binaries.
  Date/Author: 2026-06-14 / Codex

- Decision: expand the screenshot set from seven to nine shots per platform.
  Rationale: Apple allows up to ten screenshots per device family, and the current set omits the structured JSON viewer and `qmv` launcher workflow introduced after the last screenshot refresh.
  Date/Author: 2026-06-14 / Codex

## Outcomes & Retrospective

Submitted Quick Markdown Viewer `1.7 (15)` to App Store Review for both platforms.

- iOS version `a28ca430-a671-4bbc-b5f0-917099cd3f76` is `WAITING_FOR_REVIEW`, attached to valid App Store eligible build `cf2ffc96-5646-4730-8b2a-1e62fcd45e2b`, and submitted through review submission `7f00482b-a753-45d2-993c-c8c6a6a36e73`.
- macOS version `d53c7a88-53e5-4e84-b9c4-a171bb09e658` is `WAITING_FOR_REVIEW`, attached to valid App Store eligible build `37dab215-3773-4947-a51b-bd01e951ee81`, and submitted through review submission `b629cd2e-71de-4713-b283-48b33fa2e7fd`.
- Screenshot sets are complete: iPhone set `3169bfe0-5211-4c14-bfc4-bc198f990d80`, iPad set `cf2d8245-60b9-4834-8a60-3ce9309adaaa`, and macOS set `6ebfd4e1-bb83-4830-b106-43ad29a94dde` each contain nine `COMPLETE` screenshot assets, including structured JSON and `qmv` launcher shots.
- The macOS App Store screenshot capture now uses the search fixture with the sidebar open but omits the macOS-only failing search launch arguments; iPhone and iPad still capture with populated search arguments.

## Context and Orientation

Relevant local surfaces:

- `scripts/archive-release`
- `scripts/export-app-store`
- `scripts/app-store-connect`
- `scripts/capture-app-store-screenshots`
- `scripts/lib/app_store_connect.py`
- `docs/release/app-store-metadata.md`
- `docs/release/app-review-notes.md`
- `Fixtures/app-store/`
- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`

Live App Store Connect app:

- App id: `6761271951`
- Bundle id: `com.souschefstudio.Free-Markdown-Viewer`
- Current live iOS version: `1.6`, build `14`
- Current live macOS version: `1.6`, build `14`

## Plan of Work

1. Update the local version/build to `1.7 (15)` and refresh release metadata for JSON-family viewing, Quick Look JSON support, and `qmv` file opens.
2. Add App Store screenshot fixtures and capture-script entries for structured JSON and the `qmv` launcher workflow.
3. Regenerate screenshots for iPhone, iPad, and macOS; verify dimensions and harness state snapshots.
4. Build, archive, export, and upload iOS and macOS App Store artifacts.
5. Create or locate `1.7` iOS and macOS App Store versions, patch localization and review details, upload the nine screenshots per platform, attach build `15`, and submit review submissions.
6. Verify final App Store states and update `.agents/DOCUMENTATION.md` plus this ExecPlan.

## Concrete Steps

1. Patch `project.pbxproj`, release docs, screenshot fixtures, and capture script.
2. Run focused local validation for changed metadata and screenshot fixtures.
3. Run `./scripts/capture-app-store-screenshots --platform all`.
4. Run `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.7 APP_BUILD_NUMBER=15 ./scripts/archive-release --platform ios --allow-provisioning-updates`.
5. Run the matching macOS archive command.
6. Export both archives with the existing export-options plists.
7. Upload the exported `.ipa` and `.pkg` with `xcrun altool --wait`.
8. Poll App Store Connect for valid `1.7` build `15` records.
9. Create/patch `1.7` App Store versions for `IOS` and `MAC_OS`, upload screenshot sets, attach builds, and submit review submissions.

## Validation and Acceptance

Acceptance requires:

- iOS and macOS `1.7` App Store versions exist for app `6761271951`
- build `15` is uploaded, valid, and attached for both platforms
- iPhone, iPad, and macOS screenshot sets include structured JSON and `qmv` workflow shots
- both `1.7` platform versions are submitted or otherwise in an Apple-reviewable state
- `python3 scripts/check_execplan.py`, `python3 scripts/knowledge/check_docs.py`, and `git diff --check` pass before commit

## Idempotence and Recovery

All Apple-side steps must read existing state before writing. If `1.7` versions already exist, reuse them rather than creating duplicates. If a screenshot upload fails after reservation, delete failed screenshot assets and retry the affected screenshot set. If build processing is delayed, leave the plan with exact build ids and polling commands rather than submitting an incomplete version.

## Artifacts and Notes

- `./scripts/capture-app-store-screenshots --platform all`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.7 APP_BUILD_NUMBER=15 ./scripts/archive-release --platform ios --allow-provisioning-updates`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.7 APP_BUILD_NUMBER=15 ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
- `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
- `./scripts/app-store-connect request GET /v1/apps/6761271951/appStoreVersions --query 'filter[versionString]=1.7' ...`
- `./scripts/app-store-connect request GET /v1/reviewSubmissions --query 'filter[app]=6761271951' ...`
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-06-14-app-store-1-7-build-15-submission.md`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`
- `plutil -lint 'Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj'`
- `./scripts/test-unit`

## Interfaces and Dependencies

This work depends on:

- local Apple signing credentials for team `GG34PA8F4A`
- App Store Connect API environment loaded by `scripts/lib/xcode-env.sh`
- Apple Transporter/altool availability through Xcode
- available iPhone and iPad simulators for screenshot capture
