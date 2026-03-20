# ARCHITECTURE.md

This document is the top-level codemap for the live repository. It names the major modules, boundaries, and cross-cutting concerns so a newcomer can navigate the repository without guessing.

## System overview

This repository is building a universal Apple-platform Markdown viewer with five major subsystems:

1. workspace browsing
2. navigation and history
3. markdown parsing and lightweight rendering state
4. media classification and playback hosts
5. platform shells and harness tooling

The live codebase is still early. The Xcode template exists, but most durable structure is being added by the harness bootstrap plan.

## Top-level domains

### App shell

Purpose:

- host the viewer on macOS, iPhone, and iPad
- expose a shared shell with platform-specific host adapters

Primary code area:

- `Swift Markdown Viewer/Swift Markdown Viewer/`

Stable concepts:

- `AppModel`
- `WorkspaceProvider`
- `NavigationEntry`
- `HarnessLaunchOptions`
- `HarnessStateSnapshot`

### Tests

Purpose:

- verify launch-option parsing, workspace selection, snapshot correctness, and UI accessibility contracts

Primary code areas:

- `Swift Markdown Viewer/Swift Markdown ViewerTests/`
- `Swift Markdown Viewer/Swift Markdown ViewerUITests/`

### Fixtures and artifacts

Purpose:

- provide deterministic markdown/media inputs and checked-in expected outputs

Primary code areas:

- `Fixtures/docs/`
- `Fixtures/media/`
- `Fixtures/expected/`
- `artifacts/` for runtime outputs only

### Harness and knowledge tooling

Purpose:

- provide shell-first build/test/capture entry points
- keep docs and repo-map artifacts current

Primary code areas:

- `scripts/`
- `docs/`
- `.agents/`
- `.codex/`

## Layering rules

- shared state and contracts stay in platform-neutral Swift files
- AppKit usage stays behind `#if os(macOS)` adapters
- UIKit usage stays behind `#if os(iOS)` adapters
- shell scripts call shared helpers in `scripts/lib/`
- docs verification and repo-map generation must use only standard Python 3 library modules

## Cross-cutting concerns

### Observability

The harness must be able to:

- launch the app deterministically
- dump machine-readable state and perf snapshots
- capture app-owned screenshots
- identify key UI elements through stable accessibility identifiers

### Reliability

Critical commands should fail clearly when:

- Xcode is missing
- the shared scheme is absent
- the requested simulator device is unavailable
- required docs or plans are missing

### Product drift control

If code changes affect:

- command surface -> update `docs/harness.md`
- snapshot schema -> update `docs/debug-contracts.md`
- architecture boundaries -> update this file
- workflow expectations -> update `AGENTS.md` and `README.md`
