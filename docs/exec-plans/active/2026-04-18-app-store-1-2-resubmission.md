# App Store 1.2 Resubmission

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Submit fresh iOS and macOS App Store builds that include the latest shipped feature set, move both platforms onto a new `1.2` release line, and update App Review-facing notes so the macOS command-line installer entitlement is explained clearly in the resubmission package. The user explicitly wants both platforms resubmitted, not just the rejected macOS binary.

## Progress

- [x] (2026-04-18T09:05Z) Audited the current App Store Connect state and confirmed the relevant version topology: macOS `1.1` is `REJECTED`, iOS `1.1` is already `READY_FOR_SALE`, so a clean dual-platform resubmission requires new `1.2` versions rather than another `1.1` build.
- [x] (2026-04-18T09:05Z) Confirmed the current macOS target still ships `com.apple.security.files.user-selected.executable`, and the in-app `qmv` installer explicitly depends on that entitlement to write a runnable launcher to `~/.local/bin/qmv`.
- [x] (2026-04-18T09:24Z) Bump the checked-in release metadata to `1.2 (6)` and update the review/metadata docs to describe the current feature set plus the entitlement rationale.
- [x] (2026-04-18T10:36Z) Archive, export, and upload fresh iOS and macOS App Store builds from the current tree, plus a second macOS archive override for `1.1 (6)` after ASC blocked creation of a new macOS `1.2` version while the rejected `1.1` version still existed.
- [x] (2026-04-18T10:40Z) Submit iOS as a new `1.2` review and resubmit macOS on the existing `1.1` version after canceling the stale unresolved-issues review submission, patching the review notes/localizations, and attaching the replacement build.

## Surprises & Discoveries

- Observation: iOS `1.1` is already live, so there is no path to “submit a new iOS 1.1 binary” for review.
  Evidence: `/v1/apps/6761271951/appStoreVersions` currently reports iOS version `b46569e4-9c84-47b9-b0ec-9a4280e49117` as `READY_FOR_SALE`.

- Observation: macOS `1.1` is rejected but still has an attached `appStoreReviewDetail`, so the existing review-note text can be used as the baseline for the new `1.2` submission.
  Evidence: `/v1/apps/6761271951/appStoreVersions?include=appStoreReviewDetail,build` reports macOS version `cd38e88b-3917-4760-9733-d71fdf7d18f2` as `REJECTED` with review detail `1a725985-cca0-41b2-9e3e-4d29bd2f6a76`.

- Observation: the repository’s App Store Connect helper supports patching review notes and localizations, but not a dedicated reviewer-thread reply endpoint.
  Evidence: `scripts/lib/app_store_connect.py` exposes `patch-review-detail` and raw `request`, but no specialized resolution-center reply command.

- Observation: the release docs still described the previous GitHub and remote-media release line, so the `1.2` metadata needed to call out CSV/TSV and print support before the new submissions.
  Evidence: `docs/release/app-store-metadata.md` initially listed only GitHub, remote media, and the macOS CLI installer in `What's New`.

- Observation: App Store Connect currently refuses creation of a fresh macOS `1.2` app-store-version resource while the rejected macOS `1.1` version is still the active editable line.
  Evidence: `POST /v1/appStoreVersions` with `platform=MAC_OS` and `versionString=1.2` returned `409 STATE_ERROR.ENTITY_STATE_INVALID` with `detail: "You cannot create a new version of the App in the current state."`

- Observation: once the replacement build was attached, the rejected macOS version could not be added to a new review submission until the old unresolved-issues submission was explicitly canceled.
  Evidence: `POST /v1/reviewSubmissionItems` first failed with `STATE_ERROR.ITEM_PART_OF_ANOTHER_SUBMISSION`, naming stale review submission `061681d3-4563-4ca4-9a35-9edde6082a67`; after `PATCH /v1/reviewSubmissions/061681d3-4563-4ca4-9a35-9edde6082a67` with `canceled: true` reached `COMPLETE`, the existing draft submission `2e862a82-ffd5-4ea2-92cd-7120abcf2d5e` accepted the version and moved to `WAITING_FOR_REVIEW`.

## Decision Log

- Decision: submit both platforms as version `1.2` instead of trying to keep macOS on `1.1`.
  Rationale: iOS `1.1` is already live, and the user explicitly wants both platforms resubmitted with the newer feature set.

- Decision: keep the macOS entitlement unchanged for this submission and explain its purpose clearly in the macOS review notes.
  Rationale: the shipped `qmv` installer feature depends on `com.apple.security.files.user-selected.executable`, and the user wants that rationale carried forward rather than removing the feature for this cycle.

- Decision: treat updated macOS App Review notes as the actionable reply path available from the repository automation.
  Rationale: the checked-in tooling can patch the review detail attached to the submission package, while direct resolution-center thread reply is not exposed by the existing helper.

- Decision: resubmit macOS on the existing `1.1` version with replacement build `6` instead of blocking on a fresh macOS `1.2` version resource.
  Rationale: ASC accepted a fresh iOS `1.2` line, but it rejected creation of a new macOS `1.2` version while the editable rejected `1.1` line still existed. Shipping the newer macOS binary back through the existing `1.1` submission path is the only working API route available from the current state.

## Outcomes & Retrospective

The checked-in project and release docs now describe the newer feature set under `1.2 (6)`, including GitHub workspaces, remote media, CSV/TSV rendering, printing, and the macOS `qmv` launcher entitlement rationale.

App Store Connect accepted fresh build `6` uploads on both platforms. iOS now uses app-store-version `bbac75b7-831b-429f-aa05-de03b30017e3` (`1.2`) attached to build `4b837e1c-5eab-4f5f-8e48-bdb02ac56916` and review submission `1c8f23d4-f745-4fa1-b963-00eff15250c9`, which is `WAITING_FOR_REVIEW`.

macOS could not open a new `1.2` version line from the current ASC state, so the resubmission shipped through the existing app-store-version `cd38e88b-3917-4760-9733-d71fdf7d18f2` (`1.1`) with replacement build `f96577d1-da44-470b-9c60-5349121d13b7`. After canceling stale review submission `061681d3-4563-4ca4-9a35-9edde6082a67`, the existing draft submission `2e862a82-ffd5-4ea2-92cd-7120abcf2d5e` accepted the version and is now `WAITING_FOR_REVIEW`.

The repository automation still cannot post a literal Resolution Center thread reply. The actionable equivalent available from the repo was completed: the macOS review detail attached to the resubmitted binary now explicitly explains why `com.apple.security.files.user-selected.executable` exists and that it is only used for the explicit user-driven `Install Command Line Tool…` flow that writes `~/.local/bin/qmv`.

## Context and Orientation

Relevant surfaces:

- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`
- `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_Viewer.entitlements`
- `docs/release/app-review-notes.md`
- `docs/release/app-store-metadata.md`
- `scripts/archive-release`
- `scripts/export-app-store`
- `scripts/app-store-connect`
- `scripts/lib/app_store_connect.py`
- `.agents/DOCUMENTATION.md`

Known App Store Connect resources at the start of this work:

- app id: `6761271951`
- macOS rejected `1.1` version id: `cd38e88b-3917-4760-9733-d71fdf7d18f2`
- macOS rejected `1.1` review detail id: `1a725985-cca0-41b2-9e3e-4d29bd2f6a76`
- iOS live `1.1` version id: `b46569e4-9c84-47b9-b0ec-9a4280e49117`
- iOS live `1.1` review detail id: `b4a8281f-f449-46da-ae75-52200578b4e5`

## Plan of Work

1. Update the checked-in version/build metadata and release docs to the new `1.2 (6)` release line.
2. Validate the repository enough to avoid shipping a broken resubmission package.
3. Archive and export fresh signed iOS and macOS App Store artifacts from the current tree.
4. Create the `1.2` App Store versions, attach the uploaded builds, patch the review details/localized release notes, and submit both platforms.

## Concrete Steps

1. Patch `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj` from `1.1 (5)` to `1.2 (6)`.
2. Update `docs/release/app-store-metadata.md` so `What's New` describes the now-shipping GitHub, remote media, CSV/TSV, and print work under the `1.2` release line.
3. Update `docs/release/app-review-notes.md` so the macOS review explanation clearly states why `com.apple.security.files.user-selected.executable` exists and that it is only used for the explicit `Install Command Line Tool…` flow.
4. Run the narrow release validation loop:
   - `./scripts/test-unit`
   - `python3 scripts/check_execplan.py docs/exec-plans/active/2026-04-18-app-store-1-2-resubmission.md`
   - `python3 scripts/knowledge/check_docs.py`
5. Archive and export signed release artifacts:
   - `APPLE_DEVELOPMENT_TEAM=<TEAM_ID> ./scripts/archive-release --platform ios --allow-provisioning-updates`
   - `APPLE_DEVELOPMENT_TEAM=<TEAM_ID> ./scripts/archive-release --platform macos --allow-provisioning-updates`
   - `./scripts/export-app-store --platform ios ...`
   - `./scripts/export-app-store --platform macos ...`
6. Upload the exported `.ipa` and `.pkg` to App Store Connect.
7. Create new `1.2` app-store-version resources for iOS and macOS if they do not already exist, patch their localizations/review notes, attach the new builds, and submit both versions for review.

## Validation and Acceptance

Acceptance requires:

- the checked-in project reports `MARKETING_VERSION = 1.2` and `CURRENT_PROJECT_VERSION = 6`
- unit tests and docs/plan checks pass
- fresh App Store-eligible iOS and macOS builds upload successfully
- App Store Connect shows the new iOS `1.2` version and the resubmitted macOS version with the new builds attached
- the macOS `1.2` review note explicitly explains the `com.apple.security.files.user-selected.executable` entitlement
- both platforms enter review submission state successfully

## Idempotence and Recovery

If upload or submission fails mid-flight:

- reuse the same `1.2 (6)` binaries if they are already valid in App Store Connect
- rerun only the failed App Store Connect relationship/submission calls rather than rebuilding immediately
- if a partial iOS `1.2` version already exists, patch that version in place instead of creating another
- if macOS is still stuck on a rejected version, attach the replacement build there and cancel the stale unresolved-issues review submission before creating or reusing a fresh draft review submission

If Apple rejects the entitlement explanation again, the recovery path is a follow-up release that gates or removes the in-app `qmv` installer for the Mac App Store build.

## Artifacts and Notes

Commands run:

- `./scripts/test-unit`
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-04-18-app-store-1-2-resubmission.md`
- `python3 scripts/knowledge/check_docs.py`
- `APP_MARKETING_VERSION=1.2 APP_BUILD_NUMBER=6 APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform ios --allow-provisioning-updates`
- `APP_MARKETING_VERSION=1.2 APP_BUILD_NUMBER=6 APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `APP_MARKETING_VERSION=1.2 APP_BUILD_NUMBER=6 ./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
- `APP_MARKETING_VERSION=1.2 APP_BUILD_NUMBER=6 ./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' --api-key \"$ASC_KEY_ID\" --api-issuer \"$ASC_ISSUER_ID\" --p8-file-path \"$ASC_KEY_PATH\" --api-key-subject user --wait --output-format json`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key \"$ASC_KEY_ID\" --api-issuer \"$ASC_ISSUER_ID\" --p8-file-path \"$ASC_KEY_PATH\" --api-key-subject user --wait --output-format json`
- `APP_MARKETING_VERSION=1.1 APP_BUILD_NUMBER=6 APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `APP_MARKETING_VERSION=1.1 APP_BUILD_NUMBER=6 ./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key \"$ASC_KEY_ID\" --api-issuer \"$ASC_ISSUER_ID\" --p8-file-path \"$ASC_KEY_PATH\" --api-key-subject user --wait --output-format json`
- `./scripts/app-store-connect patch-version-localization --id b200996b-669e-4e87-9392-7c77a684e7ff ...`
- `./scripts/app-store-connect patch-review-detail --id 30596403-6539-4356-8ce5-2296b2f0ec10 ...`
- `./scripts/app-store-connect patch-version-localization --id df3a8fc3-c14e-496c-8b41-28464e23d326 ...`
- `./scripts/app-store-connect patch-review-detail --id 1a725985-cca0-41b2-9e3e-4d29bd2f6a76 ...`
- `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/061681d3-4563-4ca4-9a35-9edde6082a67 --body '{\"data\":{\"type\":\"reviewSubmissions\",\"id\":\"061681d3-4563-4ca4-9a35-9edde6082a67\",\"attributes\":{\"canceled\":true}}}'`
- `./scripts/app-store-connect request POST /v1/reviewSubmissionItems --body '{...2e862a82-ffd5-4ea2-92cd-7120abcf2d5e...cd38e88b-3917-4760-9733-d71fdf7d18f2...}'`
- `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/2e862a82-ffd5-4ea2-92cd-7120abcf2d5e --body '{\"data\":{\"type\":\"reviewSubmissions\",\"id\":\"2e862a82-ffd5-4ea2-92cd-7120abcf2d5e\",\"attributes\":{\"submitted\":true}}}'`

## Interfaces and Dependencies

This work depends on:

- local signing credentials via `APPLE_DEVELOPMENT_TEAM`
- App Store Connect API credentials via `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_PATH`
- the repo release scripts and raw App Store Connect helper
- the existing app review detail/localization records as source copy for the new `1.2` versions
