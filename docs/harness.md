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

The scripts are responsible for:

- creating output directories
- passing launch arguments or UI-test environment
- waiting for the files to exist
- comparing artifacts to checked-in expectations
