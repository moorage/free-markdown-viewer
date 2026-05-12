# App Store 1.4 Submission

This ExecPlan is a living document. Keep `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` current as the release proceeds.

## Purpose / Big Picture

Submit the current tree to App Store Connect so the outline inspector, large CSV performance path, and App Store update-checking work reach users on both iOS/iPadOS and macOS. The existing App Store state already has iOS `1.3` live and macOS `1.3 (9)` waiting for review from the prior ignore-pattern release, so this release uses a fresh `1.4 (10)` line for the current feature set.

## Progress

- [x] (2026-05-12T23:24Z) Inspected local signing/export setup and confirmed App Store Connect API credentials are available through the repo environment; `APPLE_DEVELOPMENT_TEAM` is not exported but the project/export options use team `GG34PA8F4A`.
- [x] (2026-05-12T23:24Z) Queried App Store Connect and confirmed app `6761271951` exists for bundle ID `com.souschefstudio.Free-Markdown-Viewer`.
- [x] (2026-05-12T23:24Z) Confirmed iOS `1.3` is already `READY_FOR_SALE` with build `9`, while macOS `1.3` is `WAITING_FOR_REVIEW` with build `9`.
- [x] (2026-05-12T23:24Z) Bumped checked-in project metadata from `1.3 (9)` to `1.4 (10)` and updated release notes/review notes for outline, CSV performance, and update checks.
- [x] (2026-05-12T23:29Z) Ran release validation: `./scripts/test-unit`, `python3 scripts/check_execplan.py docs/exec-plans/active/2026-05-12-app-store-1-4-submission.md`, `python3 scripts/knowledge/check_docs.py`, and `git diff --check` all passed.
- [x] (2026-05-12T23:41Z) Archived, exported, and uploaded valid `1.4 (10)` iOS and macOS App Store builds.
- [x] (2026-05-12T23:46Z) Submitted iOS and macOS `1.4 (10)` review submissions. Both platform versions now report `WAITING_FOR_REVIEW`.

## Surprises & Discoveries

- Observation: the active App Store state is split by platform before this submission.
  Evidence: App Store Connect reports iOS `1.3` version `8bd70b08-cd79-43e8-9676-86ad768cd0df` as `READY_FOR_SALE`, but macOS `1.3` version `9a04ddf5-0e75-48fb-9262-29b83d34aed4` as `WAITING_FOR_REVIEW`.
- Observation: both existing `1.3` platform builds use build number `9`, so this release needs a higher `CFBundleVersion`.
  Evidence: App Store Connect build queries report iOS build `44cc4949-6f6f-401c-ba7a-bb72a0b7ed2a` and macOS build `27561f24-2a27-472b-8d4c-12ee995d8e00` with version `9`.
- Observation: the release scripts already auto-load App Store Connect API credentials from the repo environment.
  Evidence: sourcing `scripts/lib/xcode-env.sh` reports all `ASC_*` values present and the private key path exists, without printing secret values.
- Observation: the macOS package upload is valid but still emits Apple's existing document-type warning.
  Evidence: `altool` reported `UPLOAD SUCCEEDED` and `BUILD-STATUS: VALID`, plus warning `90788` that the `Folder` document type should include `LSHandlerRank`.
- Observation: App Store Review Notes are capped at 4000 characters.
  Evidence: the first review-note patch returned `ENTITY_ERROR.ATTRIBUTE.INVALID.TOO_LONG`; the shorter note patch succeeded.

## Decision Log

- Decision: use App Store version `1.4` and build number `10` for the current submission.
  Rationale: iOS `1.3` is already live and cannot receive another app-store-version submission under the same version string; macOS also needs a replacement for the waiting `1.3 (9)` submission that predates the current work.
- Decision: keep the release automated through the existing `archive-release`, `export-app-store`, `altool`, and App Store Connect helper scripts.
  Rationale: these scripts have already produced accepted iOS and macOS submissions for this app and encapsulate the project path, export options, and credential loading.
- Decision: update App Review notes to mention update checks explicitly.
  Rationale: the app now contacts Apple's App Store lookup endpoint, so the reviewer-facing network-client explanation should match the shipped behavior.
- Decision: keep the macOS upload despite warning `90788` instead of rebuilding this release.
  Rationale: App Store Connect accepted the package as valid and review-submission eligible; the warning is pre-existing document-type metadata polish, not a blocker for this requested submission.
- Decision: change the canceled macOS `1.3` version shell in place to `1.4`.
  Rationale: after canceling the stale macOS `1.3` review, App Store Connect still refused creating a separate macOS `1.4` version, but it accepted patching the existing editable macOS version's `versionString` to `1.4`.

## Outcomes & Retrospective

The current tree is submitted to App Store Connect as `1.4 (10)` on both platforms. iOS app-store-version `1e0a074d-26a6-4f33-a8f5-a70b7897f301` has valid build `ce76a788-67f1-4fa6-88d3-b565b272ffef` attached and review submission `ac0460de-ca95-4a4b-b25c-d4f35df77f5d` is `WAITING_FOR_REVIEW`. macOS app-store-version `9a04ddf5-0e75-48fb-9262-29b83d34aed4` was changed from `1.3` to `1.4`, has valid build `c5261c5a-4507-4ccd-95af-2cad72e5cd36` attached, and review submission `5afb0138-487c-4ca6-9e1a-acb912e6180c` is `WAITING_FOR_REVIEW`.

The previous macOS `1.3` review submission `af1ed877-498c-4808-b9ed-11d7e9aa40cf` was canceled because it predated the outline/CSV/update-checking work and blocked a clean macOS `1.4` submission path.

## Context and Orientation

Relevant files:

- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`
- `docs/release/app-store-metadata.md`
- `docs/release/app-review-notes.md`
- `scripts/archive-release`
- `scripts/export-app-store`
- `scripts/app-store-connect`
- `scripts/lib/app_store_connect.py`
- `.agents/DOCUMENTATION.md`

Relevant App Store Connect resources:

- app id: `6761271951`
- bundle id: `com.souschefstudio.Free-Markdown-Viewer`
- current iOS `1.3` app-store-version id: `8bd70b08-cd79-43e8-9676-86ad768cd0df`
- current macOS `1.3` app-store-version id: `9a04ddf5-0e75-48fb-9262-29b83d34aed4`
- current macOS `1.3` review submission id: `af1ed877-498c-4808-b9ed-11d7e9aa40cf`
- submitted iOS `1.4` app-store-version id: `1e0a074d-26a6-4f33-a8f5-a70b7897f301`
- submitted iOS `1.4` build id: `ce76a788-67f1-4fa6-88d3-b565b272ffef`
- submitted iOS `1.4` review submission id: `ac0460de-ca95-4a4b-b25c-d4f35df77f5d`
- submitted macOS `1.4` app-store-version id: `9a04ddf5-0e75-48fb-9262-29b83d34aed4`
- submitted macOS `1.4` build id: `c5261c5a-4507-4ccd-95af-2cad72e5cd36`
- submitted macOS `1.4` review submission id: `5afb0138-487c-4ca6-9e1a-acb912e6180c`

## Plan of Work

1. Update checked-in release metadata and release-facing docs to `1.4 (10)`.
2. Run the narrow validation loop for the current tree.
3. Archive and export signed iOS and macOS App Store artifacts.
4. Upload the `.ipa` and `.pkg` to App Store Connect and poll for valid build records.
5. Create or prepare `1.4` app-store-version resources, patch release notes and review notes, attach the new builds, and submit review submissions.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Patch `project.pbxproj` to `MARKETING_VERSION = 1.4` and `CURRENT_PROJECT_VERSION = 10`.
2. Patch `docs/release/app-store-metadata.md` and `docs/release/app-review-notes.md`.
3. Run:
   - `./scripts/test-unit`
   - `python3 scripts/check_execplan.py docs/exec-plans/active/2026-05-12-app-store-1-4-submission.md`
   - `python3 scripts/knowledge/check_docs.py`
4. Archive and export:
   - `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform ios --allow-provisioning-updates`
   - `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
   - `./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
   - `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
5. Upload:
   - `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
   - `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait`
6. Use `scripts/app-store-connect request` to attach builds and submit review submissions. If macOS `1.4` creation is blocked by the waiting `1.3` submission, cancel the waiting macOS `1.3` review submission only after the replacement macOS `1.4 (10)` build is valid.

Completed App Store Connect steps:

1. Created iOS `1.4` version `1e0a074d-26a6-4f33-a8f5-a70b7897f301`.
2. Canceled stale macOS review submission `af1ed877-498c-4808-b9ed-11d7e9aa40cf`.
3. Patched macOS app-store-version `9a04ddf5-0e75-48fb-9262-29b83d34aed4` from `1.3` to `1.4` after separate macOS `1.4` creation remained blocked.
4. Patched iOS localization `c5b87990-6dc4-46ef-988f-40106acce062` and macOS localization `f2b07a8b-58bb-4841-a78b-cb41b320ab67`.
5. Patched iOS review detail `17f47c8e-9eb0-480b-a054-ed3dfd8df8b0` and macOS review detail `a31399a8-7431-40c6-a363-d94b34dbc985`.
6. Attached iOS build `ce76a788-67f1-4fa6-88d3-b565b272ffef` and macOS build `c5261c5a-4507-4ccd-95af-2cad72e5cd36`.
7. Created and submitted iOS review submission `ac0460de-ca95-4a4b-b25c-d4f35df77f5d`.
8. Created and submitted macOS review submission `5afb0138-487c-4ca6-9e1a-acb912e6180c`.

## Validation and Acceptance

Acceptance requires:

- the checked-in project reports `MARKETING_VERSION = 1.4` and `CURRENT_PROJECT_VERSION = 10`
- unit tests pass for the current tree
- docs and ExecPlans validate
- App Store Connect reports valid iOS and macOS build `10` records for version `1.4`
- App Store Connect has review submissions for the current `1.4` iOS and macOS versions, or an explicit API blocker is recorded with the exact failing request and response

Final acceptance evidence:

- iOS `1.4`: version `1e0a074d-26a6-4f33-a8f5-a70b7897f301`, build `ce76a788-67f1-4fa6-88d3-b565b272ffef`, build state `VALID`, version state `WAITING_FOR_REVIEW`
- macOS `1.4`: version `9a04ddf5-0e75-48fb-9262-29b83d34aed4`, build `c5261c5a-4507-4ccd-95af-2cad72e5cd36`, build state `VALID`, version state `WAITING_FOR_REVIEW`
- iOS review submission `ac0460de-ca95-4a4b-b25c-d4f35df77f5d` is `WAITING_FOR_REVIEW`
- macOS review submission `5afb0138-487c-4ca6-9e1a-acb912e6180c` is `WAITING_FOR_REVIEW`

## Idempotence and Recovery

Archive/export steps delete and recreate only release artifacts under `artifacts/`. If upload succeeds but `altool` exits unclearly, query App Store Connect for build `10` before retrying. If one platform submits and the other blocks, leave the submitted platform untouched and continue only from the failed platform's App Store Connect relationship/submission calls.

If App Store Connect refuses a new macOS version because `1.3` is still waiting, cancel the existing `af1ed877-498c-4808-b9ed-11d7e9aa40cf` submission only after a valid replacement upload exists.

## Artifacts and Notes

Expected local artifacts:

- `artifacts/archives/Quick Markdown Viewer-ios.xcarchive`
- `artifacts/archives/Quick Markdown Viewer-macos.xcarchive`
- `artifacts/exports/ios/Quick Markdown Viewer.ipa`
- `artifacts/exports/macos/Quick Markdown Viewer.pkg`

Commands and App Store Connect IDs will be appended as the submission proceeds.

Notable commands run:

- `./scripts/test-unit`
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-05-12-app-store-1-4-submission.md`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform ios --allow-provisioning-updates`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
- `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' ...`
- `xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' ...`

## Interfaces and Dependencies

This work depends on:

- local Xcode archive/export tooling
- Apple signing team `GG34PA8F4A`
- App Store Connect API credentials loaded from the repo-local environment
- App Store Connect review submission APIs
- Apple's Transporter/altool upload service
