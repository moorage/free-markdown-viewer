# Harness Guide

The harness is the shell-first control plane for this repository.

## Commands

- `./scripts/bootstrap-apple`
- `./scripts/build --platform all`
- `./scripts/test-unit`
- `./scripts/test-integration`
- `./scripts/test-ui-macos --smoke`
- `./scripts/test-ui-ios --device both --smoke`
- `./scripts/capture-checkpoint --fixture basic_typography.md --platform-target macos --checkpoint shell-smoke-macos`
- `./scripts/compare-goldens --checkpoint shell-smoke-macos`
- `./scripts/archive-release --platform ios`
- `./scripts/archive-release --platform macos`
- `./scripts/export-app-store --platform ios --archive-path <xcarchive> --export-options-plist <plist>`
- `./scripts/export-app-store --platform macos --archive-path <xcarchive> --export-options-plist <plist>`
- `./scripts/app-store-connect inspect-app`
- `./scripts/app-store-connect request GET /v1/apps --query 'filter[bundleId]=com.souschefstudio.Free-Markdown-Viewer'`
- `./scripts/agent-loop`

## Artifacts

Runtime artifacts live under `artifacts/`:

- `artifacts/xcodebuild/`
- `artifacts/checkpoints/`
- `artifacts/test-results/`

Checked-in expectations live under `Fixtures/expected/`.

## Capture flow

The app is responsible for:

- writing `state.json`
- writing `perf.json`
- writing `window.png`
- honoring `--ui-test-github-fixture <path>` so GitHub workspace tests can resolve deterministic repository metadata, refs, trees, and file payloads without touching the public network
- honoring harness commands `printSelectedDocument` and `printAllDocuments` by writing the composed plain-text print artifact to the requested path without invoking native print UI
- honoring harness commands `exportPrintedDocument` and `exportPrintedAllDocuments` by writing the real rendered print output as a PDF artifact for print-debugging without invoking native print UI

The scripts are responsible for:

- creating output directories
- passing launch arguments or UI-test environment
- waiting for the files to exist
- comparing artifacts to checked-in expectations
