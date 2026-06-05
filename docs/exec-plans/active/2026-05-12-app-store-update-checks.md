# App Store Self-Update Removal

## Purpose / Big Picture

Remove the app-managed App Store update-checking feature after App Store review rejected the macOS build because Mac apps are not allowed to check for updates themselves and notify users. The accepted behavior is that Quick Markdown Viewer no longer contacts Apple's lookup endpoint for update checks, no longer presents update prompts, and no longer exposes a macOS `Check for Updates...` menu item.

## Progress

- [x] (2026-06-04T00:00Z) Confirmed the update feature is centralized in `AppUpdateChecker`, app-root injection, scene lifecycle alert wiring, macOS commands, focused unit tests, and App Review notes.
- [x] (2026-06-04T00:00Z) Removed the update checker service, automatic checks, manual macOS menu item, alert presentation, skip-version state tests, and review-note references to update prompts.
- [x] (2026-06-04T00:00Z) Ran focused unit/build validation plus ExecPlan and docs checks.
- [x] (2026-06-04T00:00Z) Confirmed App Store Connect has iOS `1.5` `READY_FOR_SALE`, macOS `1.5` version `63537360-b39f-4168-87ad-57816bc4e355` in `REJECTED`, and rejected macOS review submission `61043c3f-9351-4eab-9377-5938c639a225`.
- [x] (2026-06-04T06:00Z) Archived, exported, uploaded, attached, and submitted macOS replacement build `1.5 (13)`.

## Surprises & Discoveries

- Observation: the update checks were shared app behavior, not only macOS behavior.
  Evidence: `Quick_Markdown_ViewerApp.swift` owned one `AppUpdateChecker` and injected it into every `WindowSceneRootView`.
- Observation: the Xcode project uses filesystem-synchronized source groups for app and test sources.
  Evidence: `project.pbxproj` declares `PBXFileSystemSynchronizedRootGroup` for `Quick Markdown Viewer` and `Quick Markdown ViewerTests`, so deleting `AppUpdateChecker.swift` removes it from target discovery without editing a per-file build phase entry.
- Observation: only macOS needs a replacement App Store review submission for this rejection.
  Evidence: App Store Connect reports iOS `1.5` version `a87dc731-e48e-4f4e-9669-fe81c8130de1` as `READY_FOR_SALE`, while macOS `1.5` version `63537360-b39f-4168-87ad-57816bc4e355` is `REJECTED`.

## Decision Log

- Decision: remove the self-update feature entirely instead of hiding only the macOS menu command.
  Rationale: the automatic lookup and prompt path also notified users, and leaving dormant update-check code would preserve the App Store review risk.
- Decision: add a small negative regression test over app source files.
  Rationale: the requirement is an absence-of-behavior compliance constraint, and the test prevents reintroducing the deleted service, endpoint, or menu title in the app shell.
- Decision: submit macOS only as `1.5 (13)`.
  Rationale: the rejected platform is macOS, iOS `1.5` is already live, and App Store Connect already consumed macOS build `12`.

## Outcomes & Retrospective

Quick Markdown Viewer now relies on the App Store for update distribution and does not perform app-managed update checks or notifications. The app-root update checker state, automatic lifecycle checks, update alert, skip-version state, and macOS `Check for Updates...` command are removed. Reviewer-facing release notes now explicitly say the app does not check for updates itself or prompt users about updates.

The macOS App Store replacement is submitted. App Store Connect reports macOS app-store-version `63537360-b39f-4168-87ad-57816bc4e355` as `WAITING_FOR_REVIEW`, attached to valid App Store-eligible build `a2d3517b-d8b4-4fcb-a859-7e2e3149459b` (`1.5 (13)`). Fresh macOS review submission `d4d9bc77-c4b5-4d5d-abbd-ca1ed798c52a` is `WAITING_FOR_REVIEW`; stale rejected submission `61043c3f-9351-4eab-9377-5938c639a225` was canceled and now reports `COMPLETE`.

## Context and Orientation

Relevant code:

- `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift` owns app scene setup and macOS command registration.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift` owns scene lifecycle, prompts, and macOS command definitions.
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift` owns the focused compliance regression test.
- `docs/release/app-review-notes.md` owns reviewer-facing network-use notes.

Removed code:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppUpdateChecker.swift`

## Plan of Work

1. Delete the shared update checker service and all references from app scene setup.
2. Remove automatic lifecycle checks, update alerts, skip-version state, and the macOS manual update command.
3. Remove update-check-specific unit tests and add a regression test that app sources do not declare self-update checks.
4. Update release review notes and durable implementation notes so reviewer-facing docs match the binary.
5. Run focused validation, docs validation, and a macOS build.
6. Bump checked-in build metadata to `1.5 (13)`, archive/export/upload the macOS package, attach the valid build to the rejected macOS `1.5` version, and submit a fresh review submission.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Edit `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_ViewerApp.swift`.
2. Edit `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/WindowSceneRootView.swift`.
3. Delete `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppUpdateChecker.swift`.
4. Edit `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`.
5. Edit `docs/release/app-review-notes.md` and `.agents/DOCUMENTATION.md`.
6. Run:
   - `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-update-removal-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppSourcesDoNotDeclareSelfUpdateChecks" test`
   - `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-update-removal-build -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build`
   - `./scripts/test-unit`
   - `python3 scripts/check_execplan.py docs/exec-plans/active/2026-05-12-app-store-update-checks.md`
   - `python3 scripts/knowledge/check_docs.py`
   - `git diff --check`
7. Submit macOS replacement:
   - `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
   - `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
   - `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait`
   - poll App Store Connect for macOS build `13`
   - patch macOS review notes
   - attach build `13` to app-store-version `63537360-b39f-4168-87ad-57816bc4e355`
   - create and submit a macOS review submission

Validation completed from `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-update-removal-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testAppSourcesDoNotDeclareSelfUpdateChecks" test`
2. `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-update-removal-build -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build`
3. `./scripts/test-unit`
4. `python3 scripts/check_execplan.py docs/exec-plans/active/2026-05-12-app-store-update-checks.md`
5. `python3 scripts/knowledge/check_docs.py`
6. `git diff --check`
7. `plutil -lint "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj"`
8. `APPLE_DEVELOPMENT_TEAM=GG34PA8F4A ./scripts/archive-release --platform macos --allow-provisioning-updates`
9. `./scripts/export-app-store --platform macos --archive-path 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive' --export-options-plist 'artifacts/export-options/macos-app-store-connect.plist' --allow-provisioning-updates`
10. `plutil -p 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive/Products/Applications/Quick Markdown Viewer.app/Contents/Info.plist'`
11. `plutil -p 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive/Products/Applications/Quick Markdown Viewer.app/Contents/PlugIns/Quick Markdown Viewer QuickLook.appex/Contents/Info.plist'`
12. `codesign -d --entitlements :- 'artifacts/archives/Quick Markdown Viewer-macos.xcarchive/Products/Applications/Quick Markdown Viewer.app'`
13. `pkgutil --check-signature 'artifacts/exports/macos/Quick Markdown Viewer.pkg'`
14. `source scripts/lib/xcode-env.sh && xcrun altool --upload-package 'artifacts/exports/macos/Quick Markdown Viewer.pkg' --api-key "$ASC_KEY_ID" --api-issuer "$ASC_ISSUER_ID" --p8-file-path "$ASC_KEY_PATH" --api-key-subject user --wait`
15. `./scripts/app-store-connect request GET /v1/builds --query 'filter[app]=6761271951' --query 'filter[version]=13' --query 'filter[preReleaseVersion.version]=1.5' --query 'filter[preReleaseVersion.platform]=MAC_OS' --query 'include=preReleaseVersion' --query 'limit=5'`
16. `./scripts/app-store-connect patch-review-detail --id 60feafff-cf62-4b27-8d20-4942f42b8586 --notes "$NOTES"`
17. `./scripts/app-store-connect request PATCH /v1/appStoreVersions/63537360-b39f-4168-87ad-57816bc4e355/relationships/build --body '{"data":{"type":"builds","id":"a2d3517b-d8b4-4fcb-a859-7e2e3149459b"}}'`
18. `./scripts/app-store-connect request POST /v1/reviewSubmissions --body '{"data":{"type":"reviewSubmissions","attributes":{"platform":"MAC_OS"},"relationships":{"app":{"data":{"type":"apps","id":"6761271951"}}}}}'`
19. `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/61043c3f-9351-4eab-9377-5938c639a225 --body '{"data":{"type":"reviewSubmissions","id":"61043c3f-9351-4eab-9377-5938c639a225","attributes":{"canceled":true}}}'`
20. `./scripts/app-store-connect request POST /v1/reviewSubmissionItems --body '{"data":{"type":"reviewSubmissionItems","relationships":{"reviewSubmission":{"data":{"type":"reviewSubmissions","id":"d4d9bc77-c4b5-4d5d-abbd-ca1ed798c52a"}},"appStoreVersion":{"data":{"type":"appStoreVersions","id":"63537360-b39f-4168-87ad-57816bc4e355"}}}}}'`
21. `./scripts/app-store-connect request PATCH /v1/reviewSubmissions/d4d9bc77-c4b5-4d5d-abbd-ca1ed798c52a --body '{"data":{"type":"reviewSubmissions","id":"d4d9bc77-c4b5-4d5d-abbd-ca1ed798c52a","attributes":{"submitted":true}}}'`
22. `./scripts/app-store-connect request GET /v1/appStoreVersions/63537360-b39f-4168-87ad-57816bc4e355 --query 'include=build,appStoreReviewDetail' --query 'fields[appStoreVersions]=platform,versionString,appStoreState,appVersionState,build,appStoreReviewDetail' --query 'fields[builds]=version,processingState,buildAudienceType,uploadedDate,usesNonExemptEncryption'`
23. `./scripts/app-store-connect request GET /v1/reviewSubmissions/d4d9bc77-c4b5-4d5d-abbd-ca1ed798c52a --query 'include=items'`

## Validation and Acceptance

Acceptance requires:

- app sources no longer define `AppUpdateChecker`
- app launch and active-scene lifecycle no longer run automatic update checks
- macOS commands no longer include `Check for Updates...`
- reviewer-facing release notes no longer describe App Store lookup update checks or update prompts
- focused unit test and macOS build pass
- ExecPlan and docs checks pass
- macOS `1.5 (13)` package uploads successfully
- App Store Connect reports macOS build `13` as `VALID`
- macOS app-store-version `63537360-b39f-4168-87ad-57816bc4e355` has build `13` attached
- a fresh macOS review submission is in an Apple-reviewable state

Final acceptance evidence:

- macOS app-store-version `63537360-b39f-4168-87ad-57816bc4e355`: `WAITING_FOR_REVIEW`
- macOS build `a2d3517b-d8b4-4fcb-a859-7e2e3149459b`: version `13`, `VALID`, `APP_STORE_ELIGIBLE`
- macOS review submission `d4d9bc77-c4b5-4d5d-abbd-ca1ed798c52a`: `WAITING_FOR_REVIEW`
- macOS review submission item `ZDRkOWJjNzctYzRiNS00ZDVkLWFiYmQtY2ExZWQ3OThjNTJhfDZ8ODg2MTM2ODg1`: `READY_FOR_REVIEW`
- stale rejected submission `61043c3f-9351-4eab-9377-5938c639a225`: canceled, state `COMPLETE`

## Idempotence and Recovery

The removal is source-only and does not migrate persisted state. Existing `UserDefaults` values under the old skipped-version key become harmless orphaned preferences because no code reads them.

If validation fails, search for remaining update-check references in app sources first, then rebuild after removing the reference or stale test expectation.

## Artifacts and Notes

No generated artifacts are expected. Xcode derived data lives under `/tmp/qmv-update-removal-*`.

Release artifacts:

- `artifacts/archives/Quick Markdown Viewer-macos.xcarchive`
- `artifacts/exports/macos/Quick Markdown Viewer.pkg`

## Interfaces and Dependencies

Removed dependency:

- Apple's App Store lookup endpoint for app-managed update checks.

Remaining network paths:

- user-initiated public GitHub workspace loading
- direct remote media URLs authored inside Markdown
