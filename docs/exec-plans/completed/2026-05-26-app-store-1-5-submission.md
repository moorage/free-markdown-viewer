# App Store 1.5 Submission

This ExecPlan is a living document. Keep `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` current as the release proceeds.

## Purpose / Big Picture

Submit the current tree to App Store Connect as a new iOS/iPadOS and macOS release. The previous `1.4 (10)` line is live on both platforms, so the current submission must use a new App Store version and build number.

This release carries the recent user-visible work for native Mermaid diagrams, VS Code-style file browsing, full-text search, cancellable/background print assembly, non-blank macOS print preview output, and the macOS Markdown Quick Look extension.

## Progress

- [x] (2026-05-26T06:51Z) Verified App Store Connect app `6761271951` for bundle ID `com.souschefstudio.Free-Markdown-Viewer`; iOS `1.4` and macOS `1.4` are both `READY_FOR_SALE`.
- [x] (2026-05-26T06:51Z) Verified the latest uploaded build number is `10`, so this release uses `1.5 (11)`.
- [x] (2026-05-26T06:51Z) Bumped the checked-in Xcode project metadata to `MARKETING_VERSION = 1.5` and `CURRENT_PROJECT_VERSION = 11`.
- [x] (2026-05-26T07:06Z) Release validation passed: `./scripts/test-unit`, `python3 scripts/check_execplan.py`, `python3 scripts/knowledge/check_docs.py`, and `git diff --check`.
- [x] (2026-05-26T07:08Z) Archived signed iOS and macOS `1.5 (11)` release builds under `artifacts/archives/`.
- [x] (2026-05-26T07:09Z) Exported App Store artifacts under `artifacts/exports/ios/` and `artifacts/exports/macos/`.
- [x] (2026-05-26T07:12Z) Uploaded iOS `1.5 (11)`; App Store Connect marked delivery `8d4b08d2-846e-4ce5-9021-5966b1bd5d9c` as `VALID`.
- [x] (2026-05-26T07:14Z) macOS upload failed validation because the embedded Quick Look extension lacked `CFBundleExecutable`; added the missing extension executable key and `LSHandlerRank` for the Folder document type warning.
- [x] (2026-05-26T07:19Z) Verified the rebuilt macOS archive contains the Quick Look `CFBundleExecutable` and `LSHandlerRank = Alternate` for every declared document type.
- [x] (2026-05-26T07:22Z) Re-exported and uploaded macOS `1.5 (11)`; App Store Connect marked delivery `107adfec-c796-45e2-b93b-591815a8eb91` as `VALID`.
- [x] (2026-05-26T07:23Z) Created editable App Store versions for iOS `1.5` (`a87dc731-e48e-4f4e-9669-fe81c8130de1`) and macOS `1.5` (`63537360-b39f-4168-87ad-57816bc4e355`).
- [x] (2026-05-26T07:25Z) Patched release notes, listing metadata, and App Review notes; attached iOS build `8d4b08d2-846e-4ce5-9021-5966b1bd5d9c` and macOS build `107adfec-c796-45e2-b93b-591815a8eb91`.
- [x] (2026-05-26T07:26Z) Submitted both platform review submissions; then canceled them because screenshot replacement is blocked after submit.
- [x] (2026-05-26T07:38Z) Replaced the inherited five-shot App Store screenshot sets with the refreshed seven-shot iPhone, iPad, and macOS sets; every uploaded screenshot reports asset delivery `COMPLETE`.
- [x] (2026-05-26T07:40Z) Resubmitted both platform review submissions; iOS submission `a4b554ad-b16c-4514-9082-59298380acc9` and macOS submission `6b201f2d-6a07-4abe-8835-325ce1fb22ac` are `WAITING_FOR_REVIEW`.

## Surprises & Discoveries

- Observation: there are no active editable review submissions for the current `1.4` platform versions.
  Evidence: App Store Connect reports the prior iOS and macOS review submissions as `COMPLETE`, and both `1.4` versions are `READY_FOR_SALE`.
- Observation: App Store Connect validates embedded app extensions more strictly than the local archive/export path.
  Evidence: macOS `altool` rejected the package with error `90360`, requiring `CFBundleExecutable` in `Quick Markdown Viewer.app/Contents/PlugIns/Quick Markdown Viewer QuickLook.appex`.
- Observation: App Store Connect still warns about the Folder document type without `LSHandlerRank`.
  Evidence: macOS `altool` emitted warning `90788`; adding `LSHandlerRank = Alternate` to every declared document type removes this known metadata gap.
- Observation: App Store Connect does not allow screenshot deletion after review submission.
  Evidence: deleting an inherited screenshot after initial submission returned `409 STATE_ERROR` with detail `Can't Delete Screenshot After Submit for review appScreenshots`, so the initial submissions were canceled before replacing screenshot assets.

## Decision Log

- Decision: submit a new `1.5 (11)` release rather than attempting to reuse `1.4`.
  Rationale: App Store Connect marks both `1.4` platform versions as live and distribution-ready; live versions cannot receive the replacement build for this requested release.
  Date/Author: 2026-05-26 / Codex

## Outcomes & Retrospective

iOS and macOS `1.5 (11)` are submitted to App Store Connect and are both `WAITING_FOR_REVIEW`.

The only release blocker was the macOS package validation error for the embedded Quick Look extension. Adding the extension `CFBundleExecutable` and explicit document type `LSHandlerRank` metadata fixed the upload, and the corrected package validated successfully before submission.

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
- live iOS `1.4` app-store-version id: `1e0a074d-26a6-4f33-a8f5-a70b7897f301`
- live macOS `1.4` app-store-version id: `9a04ddf5-0e75-48fb-9262-29b83d34aed4`

## Plan of Work

1. Verify live App Store Connect state and local signing/export prerequisites.
2. Bump local project metadata to the next valid marketing/build version.
3. Run the release validation loop for the current tree.
4. Archive and export signed iOS and macOS App Store artifacts.
5. Upload both artifacts and poll until valid build records exist.
6. Create `1.5` app-store-version resources, patch release/review metadata, attach builds, and submit iOS and macOS review submissions.
7. Record final App Store Connect IDs and validation evidence.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Confirm `MARKETING_VERSION = 1.5` and `CURRENT_PROJECT_VERSION = 11`.
2. Run:
   - `./scripts/test-unit`
   - `python3 scripts/check_execplan.py docs/exec-plans/active/2026-05-26-app-store-1-5-submission.md`
   - `python3 scripts/knowledge/check_docs.py`
   - `git diff --check`
3. Archive and export:
   - `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform ios --allow-provisioning-updates`
   - `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
   - `./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
   - `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
4. Upload:
   - `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
   - `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
5. Use `scripts/app-store-connect request` to create platform versions, attach build `11` records, and submit review submissions.

## Validation and Acceptance

Acceptance requires:

- the checked-in project reports `MARKETING_VERSION = 1.5` and `CURRENT_PROJECT_VERSION = 11`
- release validation and docs checks pass
- App Store Connect reports valid iOS and macOS build `11` records
- App Store Connect has submitted review submissions for iOS `1.5` and macOS `1.5`, or a concrete API blocker is recorded with the exact failing request class and response summary

## Idempotence and Recovery

Archive/export steps overwrite release artifacts under `artifacts/`. If an upload succeeds but a command exits unclearly, query App Store Connect for build `11` before retrying. If one platform submits and the other blocks, leave the submitted platform untouched and continue only from the failed platform's version/build/submission calls.

If App Store Connect rejects `1.5` version creation because a platform already has an editable successor version, inspect that existing version, attach the new valid build only if its version string is `1.5`, and record the resource IDs before submitting.

## Artifacts and Notes

Expected local artifacts:

- `artifacts/archives/Quick Markdown Viewer-ios.xcarchive`
- `artifacts/archives/Quick Markdown Viewer-macos.xcarchive`
- `artifacts/exports/ios/Quick Markdown Viewer.ipa`
- `artifacts/exports/macos/Quick Markdown Viewer.pkg`

Commands and App Store Connect IDs will be appended as the submission proceeds.

Submitted App Store Connect resources:

- iOS app-store-version id: `a87dc731-e48e-4f4e-9669-fe81c8130de1`
- iOS build id: `8d4b08d2-846e-4ce5-9021-5966b1bd5d9c`
- iOS review submission id: `a4b554ad-b16c-4514-9082-59298380acc9`
- macOS app-store-version id: `63537360-b39f-4168-87ad-57816bc4e355`
- macOS build id: `107adfec-c796-45e2-b93b-591815a8eb91`
- macOS review submission id: `6b201f2d-6a07-4abe-8835-325ce1fb22ac`

Commands run:

- `./scripts/test-unit`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform ios --allow-provisioning-updates`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `./scripts/export-app-store --platform ios --archive-path 'artifacts/archives/Quick Markdown Viewer-ios.xcarchive' --export-options-plist 'artifacts/export-options/ios-app-store-connect.plist' --allow-provisioning-updates`
- `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/ios/Quick Markdown Viewer.ipa' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
- `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait --output-format json`
- `plutil -lint 'Quick Markdown Viewer/QuickLookPreview-Info.plist' 'Quick Markdown Viewer/Info-macOS.plist'`
- `xcodebuild -quiet -project 'Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj' -scheme 'Quick Markdown Viewer' -configuration Debug -derivedDataPath /tmp/qmv-appstore-metadata-fix-tests -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testQuickLookPreviewExtensionDeclaresMarkdownSupport' '-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMacDocumentTypeDeclarationsIncludeHandlerRanks' test`
- `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
- `./scripts/app-store-connect request POST '/v1/appStoreVersions' ...`
- `./scripts/app-store-connect patch-version-localization ...`
- `./scripts/app-store-connect patch-review-detail ...`
- `./scripts/app-store-connect request PATCH '/v1/appStoreVersions/{id}/relationships/build' ...`
- `./scripts/app-store-connect request POST '/v1/reviewSubmissions' ...`
- `./scripts/app-store-connect request POST '/v1/reviewSubmissionItems' ...`
- `./scripts/app-store-connect request PATCH '/v1/reviewSubmissions/{id}' --body '{"data":{"type":"reviewSubmissions","id":"...","attributes":{"submitted":true}}}'`
- `./scripts/app-store-connect request GET '/v1/appStoreVersions/{id}?fields[appStoreVersions]=platform,versionString,appStoreState,appVersionState,usesIdfa,releaseType'`
- `./scripts/app-store-connect request PATCH '/v1/reviewSubmissions/{id}' --body '{"data":{"type":"reviewSubmissions","id":"...","attributes":{"canceled":true}}}'`
- `./scripts/app-store-connect request DELETE '/v1/appScreenshots/{id}'`
- `./scripts/app-store-connect upload-screenshot --set-id ... --file ...`
- `./scripts/app-store-connect request GET '/v1/appScreenshotSets/{id}/appScreenshots?fields[appScreenshots]=fileName,assetDeliveryState,sourceFileChecksum&limit=20'`
- `./scripts/app-store-connect request POST '/v1/reviewSubmissions' ...`
- `./scripts/app-store-connect request POST '/v1/reviewSubmissionItems' ...`
- `./scripts/app-store-connect request PATCH '/v1/reviewSubmissions/{id}' --body '{"data":{"type":"reviewSubmissions","id":"...","attributes":{"submitted":true}}}'`

## Interfaces and Dependencies

This work depends on:

- local Xcode archive/export tooling
- Apple signing team `GG34PA8F4A`
- App Store Connect API credentials loaded from the repo-local environment
- App Store Connect review submission APIs
- Apple's Transporter/altool upload service
