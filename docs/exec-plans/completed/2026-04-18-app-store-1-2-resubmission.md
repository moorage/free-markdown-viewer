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
- [x] (2026-04-26T06:50Z) Diagnosed the repeated macOS rejection after Apple asked to compare Member Center and Xcode capabilities; the archived app carried both `com.apple.security.files.user-selected.read-only` and `com.apple.security.files.user-selected.read-write`, so the Xcode target capability settings are now aligned to read-write user-selected files and outgoing network access.
- [x] (2026-04-26T07:01Z) Re-archived and re-exported the macOS app from the corrected project settings; the final App Store package now signs only app sandbox, user-selected read-write, user-selected executable, network client, and the normal team/application identifiers.
- [x] (2026-04-26T07:13Z) Uploaded corrected macOS build `1.1 (7)`, attached build `18810988-e876-4e5a-95d2-ce38a3cf1f2f` to macOS app-store-version `cd38e88b-3917-4760-9733-d71fdf7d18f2`, canceled stale unresolved review submission `2e862a82-ffd5-4ea2-92cd-7120abcf2d5e`, and submitted fresh macOS review submission `d0749713-211f-4c00-9a46-03135e3da365`.
- [x] (2026-05-01T23:26Z) Bumped the checked-in release metadata to `1.2 (8)`, created macOS app-store-version `f3852a17-df63-4f71-9bfd-9833f5f5f539`, patched its localization and review notes, uploaded macOS build `e0f52044-0e2e-4e84-a5fe-118550cc39dd` (`1.2 (8)`), attached it to the new macOS `1.2` version, and submitted review submission `998e8006-0671-4930-8d2f-f19067dab2fa`, which is now `WAITING_FOR_REVIEW`.

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

- Observation: the archived macOS app generated a contradictory file-access entitlement set even though the checked-in entitlements file no longer contains read-only access.
  Evidence: `codesign -dvvv --entitlements :- 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive/Products/Applications/Quick Markdown Viewer.app'` printed both `com.apple.security.files.user-selected.read-only` and `com.apple.security.files.user-selected.read-write`, while `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj` still set `ENABLE_USER_SELECTED_FILES = readonly`.

- Observation: the Xcode capability settings also drifted from the checked-in network entitlement.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_Viewer.entitlements` includes `com.apple.security.network.client`, but the app target still set `ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO` in both Debug and Release.

- Observation: App Store Connect enforces `CFBundleVersion` uniqueness across uploads strongly enough that the new macOS `1.2 (7)` package was rejected because build number `7` was already consumed by an older macOS pre-release line.
  Evidence: `xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' ...` returned `90061` saying `CFBundleVersion [7]` must be higher than the previously uploaded version `[7]`, and `GET /v1/builds/18810988-e876-4e5a-95d2-ce38a3cf1f2f?include=preReleaseVersion,app` showed that existing build `7` belonged to macOS pre-release version `1.1`.

- Observation: `altool` can finish a successful upload and still crash while serializing its own JSON output, so App Store Connect must be queried directly before deciding whether to retry.
  Evidence: `xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' ... --output-format json` reported `UPLOAD SUCCEEDED` with delivery UUID `e0f52044-0e2e-4e84-a5fe-118550cc39dd`, then terminated with `NSInvalidArgumentException`; `GET /v1/builds?filter[app]=6761271951&filter[version]=8&filter[preReleaseVersion.platform]=MAC_OS` immediately showed build `e0f52044-0e2e-4e84-a5fe-118550cc39dd` as `VALID`.

## Decision Log

- Decision: submit both platforms as version `1.2` instead of trying to keep macOS on `1.1`.
  Rationale: iOS `1.1` is already live, and the user explicitly wants both platforms resubmitted with the newer feature set.

- Decision: keep the macOS entitlement unchanged for this submission and explain its purpose clearly in the macOS review notes.
  Rationale: the shipped `qmv` installer feature depends on `com.apple.security.files.user-selected.executable`, and the user wants that rationale carried forward rather than removing the feature for this cycle.

- Decision: treat updated macOS App Review notes as the actionable reply path available from the repository automation.
  Rationale: the checked-in tooling can patch the review detail attached to the submission package, while direct resolution-center thread reply is not exposed by the existing helper.

- Decision: resubmit macOS on the existing `1.1` version with replacement build `6` instead of blocking on a fresh macOS `1.2` version resource.
  Rationale: ASC accepted a fresh iOS `1.2` line, but it rejected creation of a new macOS `1.2` version while the editable rejected `1.1` line still existed. Shipping the newer macOS binary back through the existing `1.1` submission path is the only working API route available from the current state.

- Decision: align Xcode capability build settings with the explicit entitlements instead of changing the `qmv` feature.
  Rationale: Apple’s sandbox documentation supports `com.apple.security.files.user-selected.executable` for user-selected executable writes, but the submitted archive had a concrete invalid/mismatched entitlement shape that can be fixed without removing the user-driven launcher installer.

- Decision: bump the checked-in build number to `8` and regenerate the macOS package instead of trying to reuse or reattach build `7`.
  Rationale: the existing build `7` belongs to macOS pre-release version `1.1`, so a fresh `1.2` submission required a higher `CFBundleVersion` before App Store Connect would accept another upload.

## Outcomes & Retrospective

The checked-in project now targets `MARKETING_VERSION = 1.2` and `CURRENT_PROJECT_VERSION = 8`, matching the newly submitted macOS App Store binary.

iOS is already live on app-store-version `bbac75b7-831b-429f-aa05-de03b30017e3` (`1.2`). No new iOS binary was needed for this follow-up submission.

macOS now has a fresh `1.2` app-store-version `f3852a17-df63-4f71-9bfd-9833f5f5f539` with build `e0f52044-0e2e-4e84-a5fe-118550cc39dd` (`1.2 (8)`) attached. Review submission `998e8006-0671-4930-8d2f-f19067dab2fa` was submitted on 2026-05-01 and App Store Connect reports both the version and submission as `WAITING_FOR_REVIEW`.

The repository automation still cannot post a literal Resolution Center thread reply. The actionable equivalent available from the repo was completed: the macOS review detail attached to app-store-review-detail `e6c3e533-eb68-4653-814f-3202b89e9f3e` explains that `com.apple.security.files.user-selected.executable` exists only for the explicit user-driven `Install Command Line Tool…` flow that writes `~/.local/bin/qmv`, and it now includes the reviewer-visible `qmv /path/to/file.md` behavior.

The April 26 entitlement fix remains validated on the actual upload artifact. The signed macOS package used for build `8` comes from the same corrected project settings that remove the prior contradictory read-only file entitlement shape and keep only app sandbox, user-selected read-write, user-selected executable, network client, and the normal App Store signing identifiers.

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

- the checked-in project reports `MARKETING_VERSION = 1.2` and `CURRENT_PROJECT_VERSION = 8`
- `./scripts/test-unit` passes on the checked-in tree
- the macOS `1.2 (8)` package uploads successfully and App Store Connect reports build `e0f52044-0e2e-4e84-a5fe-118550cc39dd` as `VALID`
- App Store Connect shows macOS app-store-version `f3852a17-df63-4f71-9bfd-9833f5f5f539` with build `8` attached and state `WAITING_FOR_REVIEW`
- the macOS `1.2` review note explicitly explains the `com.apple.security.files.user-selected.executable` entitlement and the `qmv /path/to/file.md` review path

## Idempotence and Recovery

If upload or submission fails mid-flight:

- reuse the same `1.2 (8)` binary if App Store Connect already reports build `e0f52044-0e2e-4e84-a5fe-118550cc39dd` as `VALID`
- rerun only the failed App Store Connect relationship/submission calls rather than rebuilding immediately
- if a partial iOS `1.2` version already exists, patch that version in place instead of creating another
- if macOS `1.2` already exists in `PREPARE_FOR_SUBMISSION`, patch that version in place, attach the valid build, and create a fresh review submission instead of creating another version shell

If Apple rejects the entitlement explanation again, the recovery path is a follow-up release that gates or removes the in-app `qmv` installer for the Mac App Store build.

If Apple still rejects a freshly archived binary whose signed entitlements contain only app sandbox, user-selected read-write, user-selected executable, and network client, remove or gate the Mac App Store `qmv` installer and resubmit without `com.apple.security.files.user-selected.executable`.

## Artifacts and Notes

Commands run:

- `xcodebuild -project 'Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj' -scheme 'Quick Markdown Viewer' -configuration Release -destination 'generic/platform=macOS' -showBuildSettings | rg 'ENABLE_USER_SELECTED_FILES|ENABLE_OUTGOING_NETWORK_CONNECTIONS|CODE_SIGN_ENTITLEMENTS|PRODUCT_BUNDLE_IDENTIFIER'`
- `./scripts/app-store-connect inspect-bundle-id --identifier com.souschefstudio.Free-Markdown-Viewer`
- `./scripts/app-store-connect request GET /v1/bundleIds/9ZAXC5Y677/bundleIdCapabilities`
- `codesign -dvvv --entitlements :- 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive/Products/Applications/Quick Markdown Viewer.app'`
- `pkgutil --expand 'artifacts/exports/macos/Quick Markdown Viewer.pkg' /tmp/qmv-pkg-expanded`
- `security cms -D -i '/tmp/qmv-payload.IVexFT/Quick Markdown Viewer.app/Contents/embedded.provisionprofile' | plutil -p -`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `pkgutil --expand 'artifacts/exports/macos/Quick Markdown Viewer.pkg' <tmp>/expanded`
- `codesign -dvvv --entitlements :- '<tmp>/payload/Quick Markdown Viewer.app'`
- `security cms -D -i '<tmp>/payload/Quick Markdown Viewer.app/Contents/embedded.provisionprofile' | plutil -extract Entitlements xml1 -o - -`
- `APP_MARKETING_VERSION=1.1 APP_BUILD_NUMBER=7 APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `APP_MARKETING_VERSION=1.1 APP_BUILD_NUMBER=7 ./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
- `./scripts/app-store-connect request GET /v1/preReleaseVersions/d7a54b38-04ac-43a7-83a8-02f5f152fe5b/builds --query 'limit=20'`
- `./scripts/app-store-connect request PATCH /v1/appStoreVersions/cd38e88b-3917-4760-9733-d71fdf7d18f2/relationships/build --body '{"data":{"type":"builds","id":"18810988-e876-4e5a-95d2-ce38a3cf1f2f"}}'`
- `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/2e862a82-ffd5-4ea2-92cd-7120abcf2d5e --body '{"data":{"type":"reviewSubmissions","id":"2e862a82-ffd5-4ea2-92cd-7120abcf2d5e","attributes":{"canceled":true}}}'`
- `./scripts/app-store-connect request POST /v1/reviewSubmissions --body '{"data":{"type":"reviewSubmissions","attributes":{"platform":"MAC_OS"},"relationships":{"app":{"data":{"type":"apps","id":"6761271951"}}}}}'`
- `./scripts/app-store-connect request POST /v1/reviewSubmissionItems --body '{"data":{"type":"reviewSubmissionItems","relationships":{"reviewSubmission":{"data":{"type":"reviewSubmissions","id":"d0749713-211f-4c00-9a46-03135e3da365"}},"appStoreVersion":{"data":{"type":"appStoreVersions","id":"cd38e88b-3917-4760-9733-d71fdf7d18f2"}}}}}'`
- `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/d0749713-211f-4c00-9a46-03135e3da365 --body '{"data":{"type":"reviewSubmissions","id":"d0749713-211f-4c00-9a46-03135e3da365","attributes":{"submitted":true}}}'`
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
- `./scripts/test-unit`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A APP_MARKETING_VERSION=1.2 APP_BUILD_NUMBER=8 ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `APP_MARKETING_VERSION=1.2 APP_BUILD_NUMBER=8 ./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
- `./scripts/app-store-connect request GET /v1/builds --query 'filter[app]=6761271951' --query 'filter[version]=8' --query 'filter[preReleaseVersion.platform]=MAC_OS' --query 'limit=20'`
- `./scripts/app-store-connect request PATCH /v1/appStoreVersions/f3852a17-df63-4f71-9bfd-9833f5f5f539/relationships/build --body '{"data":{"type":"builds","id":"e0f52044-0e2e-4e84-a5fe-118550cc39dd"}}'`
- `./scripts/app-store-connect request POST /v1/reviewSubmissions --body '{"data":{"type":"reviewSubmissions","attributes":{"platform":"MAC_OS"},"relationships":{"app":{"data":{"type":"apps","id":"6761271951"}}}}}'`
- `./scripts/app-store-connect request POST /v1/reviewSubmissionItems --body '{"data":{"type":"reviewSubmissionItems","relationships":{"reviewSubmission":{"data":{"type":"reviewSubmissions","id":"998e8006-0671-4930-8d2f-f19067dab2fa"}},"appStoreVersion":{"data":{"type":"appStoreVersions","id":"f3852a17-df63-4f71-9bfd-9833f5f5f539"}}}}}'`
- `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/998e8006-0671-4930-8d2f-f19067dab2fa --body '{"data":{"type":"reviewSubmissions","id":"998e8006-0671-4930-8d2f-f19067dab2fa","attributes":{"submitted":true}}}'`

## Interfaces and Dependencies

This work depends on:

- local signing credentials via `APPLE_DEVELOPMENT_TEAM`
- App Store Connect API credentials via `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_PATH`
- the repo release scripts and raw App Store Connect helper
- the existing app review detail/localization records as source copy for the new `1.2` versions
