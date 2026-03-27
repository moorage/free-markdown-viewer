# Free Markdown Viewer

NOTE: THIS IS FOR AIs TO READ.  If you are human, head to [README_FOR_APES.md](./README_FOR_APES.md) 

Universal Apple-platform Markdown viewer for macOS, iPhone, and iPad.

The repository is being bootstrapped from an empty Xcode template into a Codex-friendly control plane plus a native rendering shell. The durable workflow lives in the files below:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `.agents/PLANS.md`
- `docs/PLANS.md`
- `docs/exec-plans/active/2026-03-19-swift-codex-cli-harness.md`
- `docs/harness.md`
- `docs/debug-contracts.md`

## Quickstart

Prerequisites:

- full Xcode installed
- `xcodebuild`, `swift`, and `python3` available in Terminal
- iPhone and iPad simulators installed if you want simulator smoke coverage

Bootstrap and inspect the environment:

```bash
./scripts/bootstrap-apple
```

Build the app:

```bash
./scripts/build --platform all
```

Run narrow validation:

```bash
./scripts/test-unit
./scripts/test-ui-macos --smoke
./scripts/test-ui-ios --device iphone --smoke
./scripts/test-ui-ios --device ipad --smoke
```

Run the fast Codex loop:

```bash
./scripts/agent-loop
```

Capture a deterministic checkpoint:

```bash
./scripts/capture-checkpoint \
  --fixture basic_typography.md \
  --platform-target macos \
  --checkpoint shell-smoke-macos
```

## Repo map

- `Free Markdown Viewer/` - Xcode project, app target, unit tests, and UI tests
- `Fixtures/` - deterministic markdown/media fixtures and expected outputs
- `scripts/` - build, test, capture, docs, and knowledge tooling
- `docs/` - durable planning, harness contracts, and internal reliability/security docs
- `.agents/` - ExecPlan standard, execution runbook, and implementation notes
- `.codex/` - local Codex environment configuration

## Notes

- The renderer stays native. No `WKWebView`, HTML, CSS, or JavaScript rendering belongs in this repository.
- Shared core logic must remain platform-neutral. AppKit and UIKit belong only in thin host adapters.
- `artifacts/` is runtime-only and ignored by git.
