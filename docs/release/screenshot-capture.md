# Screenshot Capture

Use `scripts/capture-app-store-screenshots` to generate a repeatable set of candidate App Store screenshots and matching harness state/perf snapshots.

## Fixture set

The capture flow uses `Fixtures/app-store/` so the sidebar and document titles read like customer-facing content:

- `Open Markdown Folders.md`
- `Outline Navigation.md`
- `Full Text Search.md`
- `Mermaid Workflow.md`
- `Structured JSON.json`
- `Metrics.csv`
- `Media Preview.md`
- `Code and Printing.md`
- `Command Line Launcher.md`

## Command

Run all platforms:

- `./scripts/capture-app-store-screenshots`

Run one platform only:

- `./scripts/capture-app-store-screenshots --platform iphone`
- `./scripts/capture-app-store-screenshots --platform ipad`
- `./scripts/capture-app-store-screenshots --platform macos`

## Output

Artifacts are written under `artifacts/app-store-screenshots/`:

- `iphone/*.png`
- `ipad/*.png`
- `macos/*.png`
- matching `*.state.json`
- matching `*.perf.json`

## Notes

- iPhone capture prefers a 6.9-inch simulator and iPad capture prefers a 13-inch simulator so the generated assets match the highest-resolution App Store screenshot tiers Apple accepts today.
- macOS capture uses a `1440x900` window so the exported PNGs land at `2880x1800`, which matches Apple's accepted desktop screenshot dimensions.
- iPhone and iPad screenshots are captured with `simctl io screenshot` after the app reports a ready state, so they reflect the actual simulator display rather than the harness image exporter.
- The simulator status bar is normalized to `9:41`, full battery, and strong connectivity during iPhone/iPad capture.
- macOS currently relies on the in-app screenshot writer because there is no repo-owned window capture helper yet. The state/perf snapshots are reliable; inspect the generated PNGs before uploading them.
