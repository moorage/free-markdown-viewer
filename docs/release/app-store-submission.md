# App Store Submission Prep

This repository now carries the parts of App Store prep that can be done locally without App Store Connect access.

Current icon source:

- App icon set generated from `tmp/best 2.png`

## URL map

Recommended public URLs:

- Product / marketing URL: `https://www.matthewpaulmoore.com/apps/free-markdown-viewer`
- Support URL: `https://www.matthewpaulmoore.com/apps/free-markdown-viewer/support`
- Privacy policy URL: `https://www.matthewpaulmoore.com/legal/privacy`
- Terms of use URL: `https://www.matthewpaulmoore.com/legal/terms`

Recommended mapping in App Store Connect:

- App name: `Quick Markdown Viewer`
- Pricing: `Free`
- Support URL: `https://www.matthewpaulmoore.com/apps/free-markdown-viewer/support`
- Marketing URL: `https://www.matthewpaulmoore.com/apps/free-markdown-viewer`
- Privacy Policy URL: `https://www.matthewpaulmoore.com/legal/privacy`

For this in-place rename, keep the live `free-markdown-viewer` URL slug until the `quick-markdown-viewer` pages actually exist. The visible app name changes to `Quick Markdown Viewer`, but the live support and marketing URLs stay on the published slug to avoid App Review dead links.

## Default legal posture

Recommended baseline:

- Use Apple’s standard EULA: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`
- Publish your own privacy policy at `https://www.matthewpaulmoore.com/legal/privacy`
- Publish your own website/app terms at `https://www.matthewpaulmoore.com/legal/terms`

Good starter generators and template sources:

- Termly privacy policy generator: `https://termly.io/products/privacy-policy-generator/`
- Termly terms generator: `https://termly.io/products/terms-and-conditions-generator/`
- PrivacyPolicies.com privacy policy generator: `https://www.privacypolicies.com/privacy-policy-generator/`
- PrivacyPolicies.com terms generator: `https://www.privacypolicies.com/terms-conditions-generator/`

These are starting points, not final legal advice. Review and adapt the output for the actual app behavior before publication.

## Free app settings

The current repo is aligned with a normal free app:

- no StoreKit or in-app purchase flow
- no login/account dependency
- no analytics or network service requirement in the shipped code path
- local-first document viewing

Expected App Privacy answer if the shipped app remains unchanged:

- data not collected
- no tracking

Verify that claim against the final shipped build before submission.

## Website drafts

Draft source pages live here:

- `docs/release/app-store-metadata.md`
- `docs/release/screenshot-capture.md`
- `docs/release/quick-markdown-viewer-support.md`
- `docs/release/privacy-policy-draft.md`
- `docs/release/terms-of-use-draft.md`
- `docs/release/app-review-notes.md`

## Release commands

Local validation:

- `./scripts/test-unit`
- `./scripts/build --platform macos`
- `./scripts/app-store-connect inspect-app`

Release archive once signing is configured:

- `APPLE_DEVELOPMENT_TEAM=<TEAM_ID> ./scripts/archive-release --platform ios`
- `APPLE_DEVELOPMENT_TEAM=<TEAM_ID> ./scripts/archive-release --platform macos`

Export after archiving:

- `./scripts/export-app-store --platform ios --archive-path <xcarchive> --export-options-plist <plist>`
- `./scripts/export-app-store --platform macos --archive-path <xcarchive> --export-options-plist <plist>`

Environment loading:

- repo scripts now auto-load a repo-root `.env` file before running
- existing shell environment values still win over `.env` entries
- keep secrets such as `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`, and `APPLE_DEVELOPMENT_TEAM` in `.env` or your shell environment, not in checked-in files

Optional overrides for the archive script:

- `APP_BUNDLE_IDENTIFIER_OVERRIDE`
- `APP_MARKETING_VERSION`
- `APP_BUILD_NUMBER`

## Manual App Store Connect work that still remains

Create the app record manually in App Store Connect. Apple currently requires the app record itself to be created in the UI before later metadata, pricing, and submission work can continue.

Recommended values for the first create step:

- Platforms: `iOS` and `macOS`
- App name: `Quick Markdown Viewer`
- Primary language: `English (U.S.)`
- Bundle ID: `com.souschefstudio.Free-Markdown-Viewer`
- SKU: `FREEMD`
- User access: `Full Access` unless you intentionally want to limit the app record

The repo-owned App Store Connect helper can confirm the current state before and after that step:

- `./scripts/app-store-connect inspect-app`

- review the generated candidate screenshots and upload the final set
- choose the final categories/content rating/review answers
- publish the support/privacy/terms pages on the live website
- archive with your real signing team and upload via Organizer or Transporter
- complete the App Privacy questionnaire in App Store Connect using the final shipped behavior

See `docs/release/release-completion-checklist.md` for the exact remaining steps in order.
