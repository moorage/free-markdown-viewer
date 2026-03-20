# AGENTS.md

Purpose: this repository is optimized for safe, autonomous Codex work on a universal Apple-platform Markdown viewer that runs on macOS, iPhone, and iPad.

Start here. Use this file as the durable control plane, then follow the repo-specific docs it points to.

## Repository shape

- `Swift Markdown Viewer/` - Xcode project, app code, unit tests, and UI tests
- `Fixtures/` - deterministic markdown/media fixtures and expected outputs
- `scripts/` - shell wrappers, docs validation, repo-map generation, and capture helpers
- `docs/` - product, architecture, reliability, security, harness, and ExecPlan docs
- `.agents/` - authoritative ExecPlan standard, execution/status helpers
- `.codex/` - Codex local environment configuration

## First reads

Before non-trivial work, read in this order:

1. `README.md`
2. `ARCHITECTURE.md`
3. `.agents/PLANS.md`
4. `docs/PLANS.md`
5. `docs/harness.md`
6. `docs/debug-contracts.md`
7. the active plan in `docs/exec-plans/active/`

## When an ExecPlan is required

Create or update an ExecPlan in `docs/exec-plans/active/` when any of the following is true:

- work is likely to exceed roughly 30 minutes
- work spans multiple files or modules
- a design choice, migration, rollout, rollback, or artifact regeneration is involved
- there are unknowns to investigate
- a change affects universal-platform behavior, reliability, security, or user-visible rendering/navigation

Skip an ExecPlan only for trivial typo fixes or tightly local changes with no meaningful sequencing or risk.

## Required workflow

- search before adding
- prefer one meaningful change per loop
- keep diffs scoped to the current milestone
- after each meaningful milestone:
  - run the narrowest relevant tests first
  - run `python3 scripts/check_execplan.py` when an active ExecPlan changes
  - run `python3 scripts/knowledge/check_docs.py` when docs or control-plane files change
  - update the active ExecPlan `Progress`, `Decision Log`, and `Surprises & Discoveries`
  - update `.agents/DOCUMENTATION.md`

## Invariants

- no `WKWebView`
- no HTML/CSS/JavaScript renderer
- shared core code stays platform-neutral
- AppKit belongs only in macOS adapters
- UIKit belongs only in iOS/iPadOS adapters
- fixtures live in-repo
- artifacts live under `artifacts/` and are not checked in
- scripts should hide project paths with spaces and destination details from normal workflow

## Commands

- bootstrap: `./scripts/bootstrap-apple`
- build: `./scripts/build --platform all`
- unit tests: `./scripts/test-unit`
- integration tests: `./scripts/test-integration`
- macOS UI smoke: `./scripts/test-ui-macos --smoke`
- iOS/iPad UI smoke: `./scripts/test-ui-ios --device both --smoke`
- fast loop: `./scripts/agent-loop`
- checkpoint capture: `./scripts/capture-checkpoint --fixture basic_typography.md --platform-target macos --checkpoint shell-smoke-macos`
- docs verify: `python3 scripts/knowledge/check_docs.py`
- ExecPlan verify: `python3 scripts/check_execplan.py`
- repo map refresh: `python3 scripts/knowledge/generate_repo_map.py`

## PR expectations

- include acceptance evidence
- include exact commands run
- include updated docs where applicable
- keep the active ExecPlan current and move it to `docs/exec-plans/completed/` when finished
