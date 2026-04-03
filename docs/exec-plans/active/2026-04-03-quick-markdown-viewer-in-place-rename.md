# Quick Markdown Viewer In-Place Rename

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Rename the existing App Store Connect app record `6761271951` from `Free Markdown Viewer` to `Quick Markdown Viewer` without creating a new app record or changing the existing bundle identifier. The outcome should cover the mutable local product identity, the App Store listing metadata, the shipped binary display name, and the build/review submission state needed to get a freshly uploaded build back into review.

The key constraint is that the current app record and bundle ID are already live in Apple systems. The repo therefore needs an in-place rename strategy rather than the earlier record-migration approach.

## Progress

- [x] (2026-04-03T20:47Z) Read the required repo control-plane docs, the existing rename/release ExecPlans, and the current project/release helper configuration before changing anything.
- [x] (2026-04-03T20:48Z) Queried App Store Connect to confirm the live app record, app-info localization, version localizations, attached builds, and review-submission states for app `6761271951`.
- [x] (2026-04-03T20:49Z) Confirmed the repo has App Store Connect credentials in `.env` even though `.env.cx.local` does not exist in this checkout.
- [x] (2026-04-03T20:50Z) Verified that the currently published `free-markdown-viewer` marketing/support URLs return `200` while the analogous `quick-markdown-viewer` URLs currently return `404`, so the URL slug should stay unchanged during this rename.
- [x] (2026-04-03T20:52Z) Renamed the checked-in project tree and support-doc filename from `Free Markdown Viewer` to `Quick Markdown Viewer` so the remaining identity edits can patch the new paths directly.
- [x] (2026-04-03T21:05Z) Updated the checked-in product identity, Xcode project, tests, release docs, and helper scripts to `Quick Markdown Viewer` while preserving bundle ID `com.souschefstudio.Free-Markdown-Viewer` and the existing live website slug.
- [x] (2026-04-03T21:16Z) Patched the live app-info localization, both version localizations, and both review-detail records so App Store Connect now shows `Quick Markdown Viewer` across the mutable listing and review-note surfaces.
- [x] (2026-04-03T21:18Z) Confirmed `./scripts/test-unit` still passes after the in-place local rename.
- [x] (2026-04-03T21:21Z) Archived, exported, and uploaded fresh App Store build `3` artifacts for iOS and macOS; App Store Connect accepted iOS build `6206b37b-bed1-46bb-a89d-1c927bbf61fc` and macOS build `70ab9c3d-a03c-40fd-a53c-ecff7aaeb67c`.
- [x] (2026-04-03T21:26Z) Reattached the new builds to the existing app-store versions, replaced the active macOS review submission, and resubmitted macOS so review submission `10966674-994a-4ade-9028-f9030ca5d711` is back in `WAITING_FOR_REVIEW`.
- [x] (2026-04-03T21:36Z) Canceled the stale rejected iOS review submission, reattached the iOS version to draft submission `bd40c20f-3460-4eaf-8915-ff494e2b844b`, waited for Apple-side propagation, and resubmitted iOS so it is also back in `WAITING_FOR_REVIEW`.

## Surprises & Discoveries

- Observation: the user-provided credentials path `.env.cx.local` is not present in this checkout, but the repo-root `.env` already contains the App Store Connect key variables required by the release helper.
  Evidence: a direct local probe showed `.env.cx.local` missing while `.env` exists with `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_PATH`.

- Observation: the current live app record is still the previously migrated `Free Markdown Viewer` record rather than the older legacy `Swift Markdown Viewer` record.
  Evidence: `./scripts/app-store-connect inspect-app --raw` returns app `6761271951` with name `Free Markdown Viewer` and bundle ID `com.souschefstudio.Free-Markdown-Viewer`.

- Observation: the rename must preserve the current website paths for now even if the visible app name changes.
  Evidence: live HTTP checks return `200` for `https://www.matthewpaulmoore.com/apps/free-markdown-viewer/` and its support page, while both `https://www.matthewpaulmoore.com/apps/quick-markdown-viewer` variants currently return `404`.

- Observation: the iOS and macOS review states are asymmetric and need different recovery handling.
  Evidence: the iOS app-store version `ad142231-153d-4b40-b149-bb55cd70b73e` is `REJECTED` with review submission `3203801d-f3c9-4f8a-b411-b00b8fc317df` in `UNRESOLVED_ISSUES`, while the macOS app-store version `90e1bb1e-5a62-4623-a866-08b2b16262e2` is `WAITING_FOR_REVIEW` and still has an `appStoreVersionSubmission` relationship.

- Observation: the public submission flow uses `reviewSubmissions` and `reviewSubmissionItems`, not `appStoreVersionSubmissions`, and the wire-level PATCH keys differ from the Swift SDK property names.
  Evidence: `POST /v1/appStoreVersionSubmissions` returns `403` with `Allowed operation is: DELETE`, while `POST /v1/reviewSubmissions`, `POST /v1/reviewSubmissionItems`, and `PATCH /v1/reviewSubmissions/{id}` work; inspecting the generated `ReviewSubmissionUpdateRequest` in `appstoreconnect-swift-sdk` shows `isSubmitted` encodes to JSON key `submitted`.

- Observation: the iOS resubmit path requires a cancellation and propagation delay when moving from a rejected submission back to a fresh draft submission.
  Evidence: `PATCH /v1/reviewSubmissions/3203801d-f3c9-4f8a-b411-b00b8fc317df` with `canceled: true` moved the stale submission through `CANCELING` to `COMPLETE`; the first immediate submit of the fresh draft complained about missing review-version context, but the same `submitted: true` patch succeeded after a short delay once the attached review item settled.

## Decision Log

- Decision: keep the existing bundle identifier `com.souschefstudio.Free-Markdown-Viewer`.
  Rationale: the user explicitly wants to avoid deleting/recreating the app, and the bundle ID is the durable app identity Apple already associates with the existing record.
  Date/Author: 2026-04-03 / Codex

- Decision: keep the currently published marketing/support URL slug on `free-markdown-viewer` for this rename.
  Rationale: the visible app name can change safely in place, but moving App Store listing URLs to a slug that currently returns `404` would create an avoidable review risk.
  Date/Author: 2026-04-03 / Codex

- Decision: rename the local project, targets, modules, and release docs to `Quick Markdown Viewer` even though the bundle ID stays on the legacy `Free-Markdown-Viewer` token.
  Rationale: the mutable local and shipped identity should converge on one product name, while the bundle identifier remains the one Apple already issued for this app record.
  Date/Author: 2026-04-03 / Codex

- Decision: resubmit macOS through a fresh `reviewSubmission` while reusing the existing rejected iOS `reviewSubmission`.
  Rationale: the live API allowed a clean new macOS review submission after deleting the stale app-store-version submission, but it still reports the rejected iOS version as part of the historical unresolved-issues submission and refuses a second item attachment.
  Date/Author: 2026-04-03 / Codex

## Outcomes & Retrospective

The checked-in product identity is now `Quick Markdown Viewer` across the project tree, target/module names, app display name, release docs, and repo helper scripts, while the durable bundle identifier remains `com.souschefstudio.Free-Markdown-Viewer`.

App Store Connect app `6761271951` now shows `Quick Markdown Viewer` in the app-info localization, both version localizations, and both review-detail notes. Fresh App Store-eligible build `3` uploads are accepted as iOS build `6206b37b-bed1-46bb-a89d-1c927bbf61fc` and macOS build `70ab9c3d-a03c-40fd-a53c-ecff7aaeb67c`.

The macOS app-store version is back in `WAITING_FOR_REVIEW` on review submission `10966674-994a-4ade-9028-f9030ca5d711`, and the iOS app-store version is back in `WAITING_FOR_REVIEW` on review submission `bd40c20f-3460-4eaf-8915-ff494e2b844b` after the stale rejected submission `3203801d-f3c9-4f8a-b411-b00b8fc317df` was canceled out.

## Context and Orientation

Relevant local surfaces:

- `scripts/lib/product-identity.sh`
- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`
- `docs/release/app-store-metadata.md`
- `docs/release/app-store-submission.md`
- `docs/release/app-review-notes.md`
- `scripts/archive-release`
- `scripts/export-app-store`
- `scripts/app-store-connect`

Relevant live App Store Connect resources:

- app record: `6761271951`
- app-info localization: `a83ddb48-e426-468e-bdca-02050428dc15`
- iOS app-store version: `ad142231-153d-4b40-b149-bb55cd70b73e`
- iOS version localization: `46cadd66-1413-4ff7-a61d-dc892bee4197`
- iOS review detail: `12b5d659-58b7-4adf-b736-66477a19bea9`
- current iOS build: `55f8115f-491f-4db4-b846-b78f92fead1a` (build number `2`)
- macOS app-store version: `90e1bb1e-5a62-4623-a866-08b2b16262e2`
- macOS version localization: `561918f2-9ec7-41d1-baa1-c619aa1b3591`
- macOS review detail: `d9779019-7bf4-4632-a046-f114d364782a`
- current macOS build: `c7709d97-b586-44c1-bcfb-ecaf297c5ce4` (build number `2`)
- iOS review submission: `3203801d-f3c9-4f8a-b411-b00b8fc317df`
- macOS review submission: `ea1b0b98-9087-4a0a-a88f-7c700e37e79e`

## Plan of Work

1. Update the checked-in product identity to `Quick Markdown Viewer` while preserving the existing bundle ID and currently live support/marketing URLs.
2. Bump the shipped build number, archive/export fresh iOS and macOS release artifacts, and upload the new binaries to App Store Connect.
3. Patch the live App Store listing metadata and App Review notes so the visible app name and review copy both say `Quick Markdown Viewer`.
4. Move the app-store versions back into a resubmittable state, attach the new builds, and submit both platforms back into review.
5. Revalidate the plan/docs plus the narrowest relevant repo checks and capture the exact Apple-side outcome.

## Concrete Steps

1. Update `scripts/lib/product-identity.sh`, the Xcode project, source/test names, and repo docs to `Quick Markdown Viewer`.
2. Keep `APP_BUNDLE_IDENTIFIER` and the App Store support/marketing URLs unchanged until the website slug exists.
3. Set a new build number greater than the current uploaded build `2` and archive/export both platforms with the existing signing workflow.
4. Upload the new iOS and macOS packages with the App Store Connect API key from `.env`.
5. Patch app-info localization `a83ddb48-e426-468e-bdca-02050428dc15`, both version localizations, and both review-detail records to the new product name.
6. Withdraw any still-active submission state that blocks build attachment, attach the new builds to the existing iOS/macOS app-store versions, and create/restore app-store version submissions as needed.
7. Run `./scripts/test-unit`, `python3 scripts/check_execplan.py`, and `python3 scripts/knowledge/check_docs.py`, then update `.agents/DOCUMENTATION.md`.

## Validation and Acceptance

Acceptance requires:

- the checked-in product identity uses `Quick Markdown Viewer` on current operational surfaces
- the shipped app display name is `Quick Markdown Viewer`
- App Store Connect app-info and version-localization metadata show `Quick Markdown Viewer`
- new iOS and macOS App Store-eligible builds with a build number greater than `2` are uploaded and attached
- the app is back in a review-ready or waiting-for-review state on both platforms
- `./scripts/test-unit`, `python3 scripts/check_execplan.py`, and `python3 scripts/knowledge/check_docs.py` pass

## Idempotence and Recovery

The local rename is safe to rerun because the target identity is deterministic. Apple-side writes should use read-before-write confirmation and preserve the existing durable identifiers. If App Store submission state blocks a build attachment, recovery is to withdraw the active submission, reattach the build, and recreate the submission rather than creating a new app record.

## Artifacts and Notes

Useful live commands for this workstream:

- `./scripts/app-store-connect inspect-app --raw`
- `./scripts/app-store-connect request GET /v1/apps/6761271951/appInfos --query include=appInfoLocalizations`
- `./scripts/app-store-connect request GET /v1/apps/6761271951/appStoreVersions --query include=appStoreVersionLocalizations,appStoreReviewDetail,build`
- `APPLE_DEVELOPMENT_TEAM=<TEAM_ID> APP_BUILD_NUMBER=3 ./scripts/archive-release --platform ios --allow-provisioning-updates`
- `APPLE_DEVELOPMENT_TEAM=<TEAM_ID> APP_BUILD_NUMBER=3 ./scripts/archive-release --platform macos --allow-provisioning-updates`
- `./scripts/export-app-store --platform ios --archive-path "artifacts/archives/Quick Markdown Viewer-ios.xcarchive" --export-options-plist "artifacts/export-options/ios-app-store-connect.plist" --allow-provisioning-updates`
- `./scripts/export-app-store --platform macos --archive-path "artifacts/archives/Quick Markdown Viewer-macos.xcarchive" --export-options-plist "artifacts/export-options/macos-app-store-connect.plist" --allow-provisioning-updates`

## Interfaces and Dependencies

This work depends on:

- the existing Xcode signing setup for team `GG34PA8F4A` or an equivalent locally configured team
- the repo-root `.env` App Store Connect credentials
- App Store Connect REST endpoints for app localizations, app-store versions, builds, review details, and app-store version submissions
