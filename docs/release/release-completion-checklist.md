# Release Completion Checklist

This file is the shortest path from the current repo state to a live App Store release.

## Already done in the repo

- app icon set generated from `tmp/best 2.png`
- App Store metadata defaults wired into the Xcode project
- privacy manifest added
- iPhone and iPad folder-opening flow implemented
- archive and export helper scripts added
- release/support/legal draft pages written under `docs/release/`

## What you need to do

### 1. Publish the website pages

Publish these pages at the live URLs already referenced by the release docs:

- `https://www.matthewpaulmoore.com/apps/free-markdown-viewer`
- `https://www.matthewpaulmoore.com/apps/free-markdown-viewer/support`
- `https://www.matthewpaulmoore.com/legal/privacy`
- `https://www.matthewpaulmoore.com/legal/terms`

Starting draft files:

- `docs/release/app-store-metadata.md`
- `docs/release/quick-markdown-viewer-support.md`
- `docs/release/privacy-policy-draft.md`
- `docs/release/terms-of-use-draft.md`
- `docs/release/app-review-notes.md`

### 2. Set your Apple signing team

Open the Xcode project and set your real Apple Developer team for the app target and test targets, or export it through the environment variable used by the archive script.

If you want to archive from Terminal, use:

```bash
APPLE_DEVELOPMENT_TEAM=<YOUR_TEAM_ID> ./scripts/archive-release --platform ios
APPLE_DEVELOPMENT_TEAM=<YOUR_TEAM_ID> ./scripts/archive-release --platform macos
```

If you prefer, place `APPLE_DEVELOPMENT_TEAM` and App Store Connect API settings such as `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_PATH` in a repo-root `.env` file. Repo scripts now auto-load `.env`, while explicit shell environment values still override it.

### 3. Create the App Store Connect record

Use these defaults unless you want to rename the product:

- App name: `Quick Markdown Viewer`
- Platforms: `iOS` and `macOS`
- Primary language: `English (U.S.)`
- Bundle ID: `com.souschefstudio.Free-Markdown-Viewer`
- SKU: `FREEMD`
- Pricing: `Free`
- Support URL: `https://www.matthewpaulmoore.com/apps/free-markdown-viewer/support`
- Marketing URL: `https://www.matthewpaulmoore.com/apps/free-markdown-viewer`

Keep these URLs on the published `free-markdown-viewer` slug until matching `quick-markdown-viewer` pages are live.
- Privacy Policy URL: `https://www.matthewpaulmoore.com/legal/privacy`
- Category: `Productivity`
- EULA: Apple standard EULA

Check whether the record already exists with:

```bash
./scripts/app-store-connect inspect-app
```

### 4. Fill out App Store Connect metadata

You still need to provide:

- app description
- keywords
- promotional text if desired
- screenshots for iPhone, iPad, and macOS
- content rating answers
- App Review notes
- App Privacy questionnaire answers

Recommended App Review notes source:

- `docs/release/app-review-notes.md`

Recommended listing copy and screenshot plan source:

- `docs/release/app-store-metadata.md`
- `docs/release/screenshot-capture.md`

### 5. Capture screenshots

Start with the repo-owned capture set:

```bash
./scripts/capture-app-store-screenshots
```

That writes candidate screenshots to `artifacts/app-store-screenshots/` for iPhone, iPad, and macOS, plus matching state/perf snapshots for review.

You still need to review those images and upload the final App Store-compliant set in the device sizes App Store Connect asks for.

### 6. Archive and upload

After signing is configured:

```bash
APPLE_DEVELOPMENT_TEAM=<YOUR_TEAM_ID> ./scripts/archive-release --platform ios
APPLE_DEVELOPMENT_TEAM=<YOUR_TEAM_ID> ./scripts/archive-release --platform macos
```

Optional export flow if you need it:

```bash
./scripts/export-app-store --platform ios --archive-path <xcarchive> --export-options-plist <plist>
./scripts/export-app-store --platform macos --archive-path <xcarchive> --export-options-plist <plist>
```

Then upload through Xcode Organizer or Transporter.

## Recommended final checks before upload

- Confirm the icon looks correct in Xcode asset preview and in a local build.
- Confirm the live website URLs are reachable.
- Confirm the app still behaves as a free, local-first Markdown viewer with no account requirement.
- Confirm the App Privacy answers remain `data not collected` and `no tracking` for the shipped build.
- Run `./scripts/test-unit`.

## If you want one final dry run after signing

Do these in order:

1. Set the real `DEVELOPMENT_TEAM`.
2. Build locally in Xcode once for iPhone, iPad, and macOS.
3. Archive iOS.
4. Archive macOS.
5. Upload iOS first, then macOS.
