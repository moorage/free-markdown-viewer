# README_FOR_APES

This file is the human-first version of the repo README.

## What this product is

`Swift Markdown Viewer` is a native Markdown reader for Apple platforms. The goal is simple:

- open a local folder full of Markdown files
- browse those files from a sidebar
- read them in a native viewer on macOS, iPhone, and iPad
- keep navigation, selection, and window/session state predictable

This is a viewer, not a web app in a native wrapper. The repo explicitly avoids `WKWebView`, HTML/CSS/JavaScript rendering, and "just show a browser" shortcuts.

## Why it exists

Most Markdown tools are either:

- editors first, with reading as a side effect
- browser-based, even when shipped as desktop apps
- hard to test deterministically across Apple platforms

This project is trying to do the opposite.

It aims to be:

- native
- local-first
- deterministic
- testable from the shell
- friendly to autonomous AI coding workflows

The harness matters because the repo is designed so an AI CLI can build, test, launch, inspect, and repair the app without a human manually driving Xcode after every change.

## How the product works today

Today the app already has the basic shape of the product:

1. You point it at a folder that contains Markdown files.
2. It indexes those files as a workspace.
3. You choose a file from the sidebar.
4. The app renders the document with native SwiftUI/AppKit/UIKit surfaces.
5. The app can preserve per-window workspace state on macOS.
6. The debug harness can dump machine-readable state, performance snapshots, and screenshots for automation.

The rendering pipeline is native and block-oriented. The repo already includes support and tests for common block types such as headings, paragraphs, lists, tables, images, and code blocks.

## Why the harness exists

The harness is the shell-first control plane around the app.

It gives humans and AI agents stable entry points instead of making them reverse-engineer Xcode settings or click through the UI by hand. In practice, that means:

- one place to bootstrap the environment
- one place to build
- one place to run unit tests
- one place to run smoke UI tests
- one place to capture checkpoints and compare artifacts
- one fast verification loop for iterative agent work

The important scripts are:

- `./scripts/bootstrap-apple`
- `./scripts/build --platform all`
- `./scripts/test-unit`
- `./scripts/test-integration`
- `./scripts/test-ui-macos --smoke`
- `./scripts/test-ui-ios --device both --smoke`
- `./scripts/capture-checkpoint --fixture basic_typography.md --platform-target macos --checkpoint shell-smoke-macos`
- `./scripts/agent-loop`

## Human setup

If you just want the repo working on your machine, do this:

### 1. Install full Xcode

You need the actual Xcode app, not just Command Line Tools.

Verify:

```bash
xcodebuild -version
xcode-select -p
swift --version
python3 --version
```

### 2. Finish Xcode first-run setup

```bash
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

### 3. Install simulators if you want full UI smoke coverage

Install at least:

- one recent iPhone simulator
- one recent iPad simulator

### 4. Bootstrap from the repo root

```bash
./scripts/bootstrap-apple
```

This checks the Xcode project, scheme, derived-data location, fixture root, and available simulator IDs.

### 5. Run the normal shell workflow

```bash
./scripts/build --platform all
./scripts/test-unit
./scripts/test-ui-macos --smoke
./scripts/test-ui-ios --device both --smoke
```

If you want the repo's standard fast loop:

```bash
./scripts/agent-loop
```

## How to set up an AI CLI so it works well here

Any AI CLI will work better in this repo if it behaves like an engineer operating from the shell, not like a code generator that stops after writing files.

### The AI CLI needs these capabilities

- run shell commands from the repo root
- read repo-local instruction files
- edit files in place
- stay in a build-test-fix loop until the requested slice is actually working
- avoid asking for routine confirmation after every small step

### The AI CLI should start from these files

For non-trivial work, have the agent read these first:

1. `README.md`
2. `ARCHITECTURE.md`
3. `AGENTS.md`
4. `.agents/PLANS.md`
5. `docs/PLANS.md`
6. `docs/harness.md`
7. `docs/debug-contracts.md`
8. the active plan in `docs/exec-plans/active/`

That gives the agent the product constraints, the architecture boundaries, and the required verification loop.

### The AI CLI should use the harness, not bypass it

Good:

- `./scripts/build --platform all`
- `./scripts/test-unit`
- `./scripts/test-ui-macos --smoke`
- `./scripts/test-ui-ios --device both --smoke`
- `./scripts/agent-loop`

Bad:

- hand-built one-off `xcodebuild` invocations when a repo script already exists
- writing ad hoc artifacts outside `artifacts/`
- depending on manual Xcode clicking as the main verification method

### The AI CLI should follow these repo rules

- keep changes small and scoped
- search before adding new helpers
- update docs when command surfaces or contracts change
- update the active ExecPlan for larger or riskier work
- prefer deterministic fixtures in `Fixtures/`
- keep runtime outputs under `artifacts/`
- do not introduce `WKWebView`
- keep shared code platform-neutral

### If you are using Codex CLI specifically

This repo already includes local Codex configuration:

- `.codex/config.toml`
- `.codex/local-environment.yaml`

Those files already set:

- the project root markers
- workspace-write sandboxing
- on-request approval behavior
- bootstrap-on-setup behavior
- named actions for build, tests, and doc verification

In practice, the happy path is:

1. authenticate Codex CLI normally
2. start it at the repository root
3. tell it to use the checked-in repo instructions
4. tell it to validate through the shell scripts before stopping

### A good kickoff brief for an AI CLI

```text
Read README_FOR_APES.md, README.md, AGENTS.md, ARCHITECTURE.md, docs/harness.md, and the active ExecPlan before making non-trivial changes. Work in small vertical slices. After each meaningful change, run the narrowest relevant repo script first, then the broader harness loop if needed. If a check fails, fix the problem before moving on. Do not replace native rendering with a web view. Keep fixtures in-repo and artifacts under artifacts/.
```

## Short version

If you are a human:

- install full Xcode
- run `./scripts/bootstrap-apple`
- use the scripts, not raw Xcode clicking

If you are setting up an AI CLI:

- run it from the repo root
- make it read the repo instructions first
- keep it inside the harness loop
- expect it to prove changes with build/test/artifact commands before it claims success
