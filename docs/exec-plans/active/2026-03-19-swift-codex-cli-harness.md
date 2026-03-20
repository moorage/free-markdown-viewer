# Bootstrap a Swift/Xcode Codex Harness for the Universal Apple Markdown Viewer

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

This repository does not yet have `.agents/PLANS.md`. Until Milestone 1 creates that file, maintain this document in the bootstrap format described by `docs/PLANS.md`.

## Purpose / Big Picture

After this change, a Codex CLI agent or human contributor can work on the native Markdown viewer from repository root without guessing how to build, test, launch, inspect, or verify the app on macOS, iPhone, and iPad. One shell command should be enough to run the fast verification loop, and one capture command should be enough to open an in-repo fixture, dump machine-readable UI state, dump performance counters, and save a deterministic window image for a specific platform target. The control plane should feel like the reference harness repo, but it must be adapted to Swift, Xcode, XCTest, XCUITest, simulator destinations, SwiftUI app shells, and platform-native rendering hosts instead of npm, browser tooling, or voice/browser runtimes.

The user-visible proof is simple. A newcomer should be able to open the repository, read `README.md` and `AGENTS.md`, run `./scripts/bootstrap-apple`, `./scripts/agent-loop`, `./scripts/test-ui-macos --smoke`, `./scripts/test-ui-ios --device iphone --smoke`, and `./scripts/capture-checkpoint --fixture basic_typography.md --platform-target ios --device-class ipad --checkpoint shell-smoke-ipad`, then see successful build/test passes plus JSON and PNG artifacts written under `artifacts/checkpoints/`.

## Progress

- [x] (2026-03-20T06:51Z) Read `codex_execplan_native_macos_gfm_viewer.md`, the reference harness docs/scripts in `tmp/codex-harness-to-migrate/`, and the current Xcode scaffold under `Swift Markdown Viewer/`.
- [x] (2026-03-20T06:51Z) Drafted the bootstrap plan-routing file `docs/PLANS.md`, anchored `docs/exec-plans/`, and wrote the initial active harness ExecPlan.
- [x] (2026-03-20T07:07Z) Diffed `codex_execplan_native_universal_gfm_viewer.md` against the macOS brief and rewrote this plan to target a universal macOS + iPhone + iPad harness instead of a macOS-only one.
- [x] (2026-03-20T07:24Z) Created the durable control-plane docs, `.agents/` prompts, `.codex/` metadata, docs validation scripts, and macOS GitHub workflows described in Milestone 1.
- [x] (2026-03-20T07:35Z) Implemented the shared Xcode environment helpers plus shell wrappers for `bootstrap-apple`, `build`, `test-unit`, `test-integration`, `test-ui-macos`, `test-ui-ios`, `capture-checkpoint`, `compare-goldens`, `collect-perf`, and `agent-loop`.
- [x] (2026-03-20T08:52Z) Replaced the template app with a real shared-shell harness slice: launch-argument parsing, `WorkspaceProvider`, shared snapshots, stable accessibility IDs, file-backed control seam, and platform screenshot writers for macOS and iOS/iPadOS.
- [x] (2026-03-20T09:10Z) Added the repository-owned fixture corpus, initial expected checkpoint goldens for macOS/iPhone/iPad, repo-map generation, quality-score generation, and docs verification automation.
- [x] (2026-03-20T09:02Z) Verified the public harness loop end-to-end with `./scripts/test-ui-macos --smoke`, `./scripts/test-ui-ios --device both --smoke`, `./scripts/agent-loop`, `python3 scripts/knowledge/generate_repo_map.py`, `python3 scripts/knowledge/update_quality_score.py`, and `python3 scripts/knowledge/check_docs.py`.

## Surprises & Discoveries

- Observation: the repository is no longer just the Xcode scaffold, but the durable control plane is still only partially bootstrapped.
  Evidence: `docs/PLANS.md` and `docs/exec-plans/active/2026-03-19-swift-codex-cli-harness.md` now exist, but there is still no root `README.md`, `AGENTS.md`, `ARCHITECTURE.md`, `.agents/`, or `scripts/` tree in the live repo.

- Observation: the existing Xcode target is already a multiplatform template, which now aligns better with the updated universal brief than with the original macOS-only one.
  Evidence: `Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj/project.pbxproj` sets `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx xros xrsimulator"` and `TARGETED_DEVICE_FAMILY = "1,2,7"` for the app and test targets.

- Observation: the current scheme already resolves through `xcodebuild`, so the harness can continue bootstrapping from the existing project rather than recreating it.
  Evidence: `xcodebuild -list -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj'` reports the scheme `Swift Markdown Viewer`.

- Observation: the app and tests are still placeholders, so the harness must create shared abstractions before it can meaningfully verify platform behavior.
  Evidence: `Swift Markdown Viewer/Swift Markdown Viewer/ContentView.swift` still renders `Hello, world!`, while the unit and UI tests remain the default template methods with no cross-platform product assertions.

- Observation: both the repository’s Xcode subdirectory and the project name contain spaces.
  Evidence: the live paths are `Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj` and `Swift Markdown Viewer/Swift Markdown Viewer/`. Wrapper scripts are required so future agents do not repeat fragile quoting logic across macOS and simulator destinations.

- Observation: the universal brief makes simulator coverage part of correctness, not just an optional later add-on.
  Evidence: `codex_execplan_native_universal_gfm_viewer.md` adds iPhone and iPad requirements, universal shell behavior, `scripts/test-ui-ios`, simulator prerequisites, and platform fields in the debug/perf contracts.

- Observation: `ImageRenderer.uiImage` was not reliable enough for deterministic simulator screenshots on iPad.
  Evidence: the iOS harness wrote `state.json` and `perf.json` but repeatedly failed to produce `window.png` until the screenshot writer switched to a `UIHostingController` plus `UIGraphicsImageRenderer` path.

- Observation: `simctl terminate` can block after a successful artifact capture, which makes the shell wrapper look flaky even when the app already succeeded.
  Evidence: both the direct iPhone smoke run and `scripts/test-ui-ios --device both --smoke` produced all requested files inside the simulator container before the parent script stalled in cleanup. Copying artifacts before cleanup and bounding `terminate` fixed the public wrapper behavior.

## Decision Log

- Decision: keep the existing Xcode project as the bootstrap entry point instead of recreating or renaming it before the harness exists.
  Rationale: the current scheme builds, and the goal of this workstream is to remove workflow ambiguity first. Renaming the project or rebuilding targets now would add avoidable project-file churn before the control plane is stable.
  Date/Author: 2026-03-19 / Codex

- Decision: treat the harness as universal from the first script and CI command, with macOS plus iPhone/iPad simulator destinations, even though the current code is still just the default scaffold.
  Rationale: the updated product brief explicitly requires a universal Apple-platform app. The current Xcode scaffold already exposes multiplatform targets, so the harness should formalize that scope rather than collapsing back to a macOS-only workflow.
  Date/Author: 2026-03-20 / Codex

- Decision: organize the product and harness around a shared-core plus platform-shell split instead of an AppKit-first shell with platform support added later.
  Rationale: the universal brief prohibits AppKit-only architecture in shared code. The harness must therefore reinforce shared `WorkspaceProvider`, navigation, rendering, and state-snapshot contracts while keeping macOS and iOS/iPad host code in thin platform adapters.
  Date/Author: 2026-03-20 / Codex

- Decision: adopt the reference harness structure of durable docs, ExecPlan validation, repo-map generation, local environment actions, and CI verification, but replace npm-centric commands with `xcodebuild`, shell wrappers, and small Python 3 utilities.
  Rationale: the reference harness is strong because it gives Codex a reliable control plane, not because it uses Node. This repository needs the same control-plane shape with native Apple tooling underneath it.
  Date/Author: 2026-03-19 / Codex

- Decision: use a debug-only file-backed command bridge and app-owned artifact writers instead of relying only on XCUITest gestures or external OS screenshot tools.
  Rationale: the product brief demands machine-readable state dumps, deterministic checkpoints, and non-fragile control seams. A file-backed bridge is shell-friendly, easy for Codex to drive, and avoids permissions problems that come with external screen recording or coordinate-based automation. The same bridge can be shared across macOS and simulator runs.
  Date/Author: 2026-03-19 / Codex

- Decision: keep the existing `Swift Markdown ViewerTests` and `Swift Markdown ViewerUITests` targets initially, and add platform-specific test files plus destination filtering before splitting into dedicated macOS/iOS UI targets.
  Rationale: the repository is still empty. Xcode target sprawl would add maintenance before there is enough code to justify it. Scripts can abstract the difference between one UI target with multiple destinations and later dedicated targets if the project grows into that shape.
  Date/Author: 2026-03-20 / Codex

- Decision: centralize all project-path, scheme, destination, result-bundle, DerivedData, and simulator settings in shared script helpers.
  Rationale: the current path names contain spaces and the multi-platform `xcodebuild` invocations will otherwise be duplicated across build, test, capture, and CI scripts. One shared helper reduces quoting bugs and keeps future plan updates localized.
  Date/Author: 2026-03-19 / Codex

## Outcomes & Retrospective

The harness bootstrap is implemented and verified. The repository now has a durable control plane, a working universal app shell slice, reproducible fixture-driven checkpoints on macOS, iPhone simulator, and iPad simulator, and a single `./scripts/agent-loop` entry point that exercises the same build/test/smoke flow future Codex work should use.

The most important outcome is that the universal scope is now real in both the architecture and the workflow, not just in the plan text. Shared shell code owns launch options, workspace loading, navigation state, accessibility IDs, state/perf snapshots, and the command bridge, while thin platform adapters handle the screenshot path and runtime host differences. The shell wrappers hide the project path with spaces, simulator destination selection, result-bundle locations, and artifact paths behind stable commands.

The main lesson from implementation is that the harness needs to own more of the runtime determinism than the original placeholder implied. The two places that mattered most were simulator lifecycle and app-owned screenshots. Once the screenshot path moved to a UIKit-hosted renderer on iOS/iPadOS and the cleanup path stopped blocking on `simctl terminate`, the same fixture-driven checkpoint contract worked across all three supported surfaces.

## Context and Orientation

The live repository currently has one meaningful code area: `Swift Markdown Viewer/`, which contains the Xcode project, the app target, the unit-test target, and the UI-test target. The app entry point is `Swift Markdown Viewer/Swift Markdown Viewer/Swift_Markdown_ViewerApp.swift`. The placeholder root view is `Swift Markdown Viewer/Swift Markdown Viewer/ContentView.swift`. The default tests live in `Swift Markdown Viewer/Swift Markdown ViewerTests/Swift_Markdown_ViewerTests.swift` and `Swift Markdown Viewer/Swift Markdown ViewerUITests/Swift_Markdown_ViewerUITests.swift`. The current product source of truth is `codex_execplan_native_universal_gfm_viewer.md`, which supersedes the older macOS brief.

When this plan says “harness”, it means four things together. First, it means durable control-plane documentation such as `README.md`, `AGENTS.md`, `ARCHITECTURE.md`, and the ExecPlan standards. Second, it means shell wrappers that hide `xcodebuild` complexity and give Codex one stable build/test/capture interface across macOS and simulator destinations. Third, it means an in-app debug seam that can open fixtures, change state, and dump structured artifacts without human clicking. Fourth, it means knowledge-maintenance automation such as repo-map generation, ExecPlan validation, and docs verification so the control plane does not rot as the app grows.

The two source inputs that shape this plan have different strengths. `codex_execplan_native_universal_gfm_viewer.md` is the product-specific source of truth for the universal app itself, including fixture names, accessibility identifiers, launch flags, platform-neutral shared core rules, workspace-provider abstractions, state dumps, performance counters, and milestone ordering. `tmp/codex-harness-to-migrate/` is the source of truth for the style of durable Codex control plane that should exist in the repository: `AGENTS.md`, `ARCHITECTURE.md`, `.agents/PLANS.md`, `docs/PLANS.md`, docs validation, repo-map generation, CI verification, and local environment actions.

This plan intentionally separates harness bootstrap from viewer implementation. The harness must support the eventual shared-core renderer and the macOS/iPhone/iPad shells, but it does not need the full renderer to exist before it becomes useful. The first meaningful success case is a universal app shell that can load an in-repo fixture path, expose stable accessibility identifiers, dump a structured state snapshot, and be driven from scripts on macOS and at least one simulator destination.

## Plan of Work

### Milestone 1: Establish the durable universal control plane

Create the repository documents and Codex metadata that the reference harness makes durable, but rewrite them for this native Swift/Xcode codebase and the universal Apple-platform product scope. Add `README.md` with a shell-first quickstart for opening the Xcode project, running `xcodebuild`, installing required simulators, and using the harness scripts once they exist. Add `AGENTS.md` as the root operating contract for future Codex work. It must describe the current Xcode project path, the universal macOS + iPhone + iPad product scope, the “no `WKWebView`, no HTML renderer, no AppKit-only shared core” rules, the expected docs order, and the fact that the harness is part of correctness rather than a convenience. Add `ARCHITECTURE.md` as the top-level codemap for the eventual shared workspace/navigation/render/media core, platform shells, fixtures, and harness tooling.

Create `.agents/PLANS.md`, `.agents/IMPLEMENT.md`, and `.agents/DOCUMENTATION.md` using the reference harness pattern but adapting the wording to Swift, Xcode, simulators, and the repository’s actual paths. Create `docs/PLANS.md`, `docs/RELIABILITY.md`, `docs/SECURITY.md`, `docs/QUALITY_SCORE.md`, `docs/harness.md`, and `docs/debug-contracts.md`. `docs/harness.md` should explain the supported shell commands, simulator prerequisites, result-bundle paths, checkpoint workflow, and artifact locations. `docs/debug-contracts.md` should freeze the launch arguments, accessibility identifier naming rules, JSON schemas, and command-bridge protocol so later implementation milestones do not invent incompatible ad hoc control seams. Add `.codex/config.toml` and `.codex/local-environment.yaml` with actions such as `build`, `test_unit`, `test_ui_macos`, `test_ui_ios_iphone`, `test_ui_ios_ipad`, `verify_docs`, `verify_execplan`, `capture_checkpoint`, and `agent_loop`.

This milestone should also keep the initial `docs/exec-plans/active/` and `docs/exec-plans/completed/` structure in place permanently, so future work can follow the same durable workflow.

### Milestone 2: Build the shell-safe multi-destination Xcode wrapper layer

Add a `scripts/` tree that gives Codex stable entry points from repository root. Create `scripts/lib/xcode-env.sh` to define the canonical project path, scheme name, macOS destination string, iPhone simulator destination string, iPad simulator destination string, DerivedData path, result-bundle path, artifacts path, and fixture root path. Create `scripts/bootstrap-apple` to verify `xcodebuild`, `swift`, `python3`, simulator availability, the shared scheme, and writable artifact directories. It must print concise facts and fail loudly when Xcode is missing, the scheme cannot be resolved, or the required simulator runtimes/devices are absent.

Create `scripts/build`, `scripts/test-unit`, `scripts/test-ui-macos`, `scripts/test-ui-ios`, `scripts/test-integration`, and `scripts/agent-loop`. Each script must be rerunnable and must write artifacts beneath a stable `artifacts/` tree rather than polluting user-specific locations. `scripts/build` should accept a platform scope such as `--platform macos|ios|all`; its default should build the shared app for macOS plus the simulator destinations used by smoke coverage. `scripts/test-unit` should use `xcodebuild test` or `build-for-testing` plus `test-without-building` restricted to the existing unit-test target. `scripts/test-ui-macos` should run the smallest useful macOS UI suite. `scripts/test-ui-ios` should support `--device iphone|ipad|both` so the same wrapper can drive both simulator idioms. `scripts/test-integration` should initially filter the same XCTest bundle down to the integration-named tests rather than requiring a separate test target. `scripts/agent-loop` should mirror the reference harness philosophy: build, run narrow tests first, run targeted macOS smoke and targeted iPhone/iPad smoke as appropriate, optionally capture checkpoints, then return a concise failure summary.

The wrapper layer must hide all path quoting, destination selection, simulator boot, and result-bundle naming details. Future agents should never need to remember the exact `xcodebuild` invocation or the project path with spaces.

### Milestone 3: Add the shared in-app harness seam and deterministic artifact writers

Refactor the placeholder app shell enough to host harness code without waiting for the full renderer. Keep `Swift Markdown Viewer/Swift Markdown Viewer/Swift_Markdown_ViewerApp.swift` as the app entry point, but move the real shell into structured files under `Swift Markdown Viewer/Swift Markdown Viewer/App/Shared/`, `Swift Markdown Viewer/Swift Markdown Viewer/App/Shell/`, and `Swift Markdown Viewer/Swift Markdown Viewer/App/Platform/`. Create `HarnessLaunchOptions.swift` to parse launch flags like `--fixture-root`, `--open-file`, `--theme`, `--window-size`, `--disable-file-watch`, `--dump-visible-state`, `--dump-perf-state`, `--screenshot-dir`, `--ui-test-mode`, `--harness-command-dir`, `--platform-target`, and `--device-class`. Create `HarnessStateSnapshot.swift` and `HarnessPerformanceSnapshot.swift` as `Codable` types whose JSON shape matches the universal product brief. Even before the full renderer exists, these types must already include stable fields for `platform`, `deviceClass`, `workspaceRoot`, `selectedFile`, `history`, `viewport`, `visibleBlocks`, sidebar selection, launch timing, visible block count, and media counters.

Implement a debug-only file-backed command bridge under `Swift Markdown Viewer/Swift Markdown Viewer/Harness/` or an equivalent shared harness folder. The bridge should watch a command directory passed in through `--harness-command-dir`, read one JSON request at a time, execute it on the main app shell, and write a matching JSON response. Use stable request types such as `openWorkspace`, `openFile`, `setWindowSize`, `scrollToY`, `scrollToBlock`, `dumpState`, `dumpPerf`, `captureWindow`, `playMedia`, and `pauseMedia`. Add platform-specific artifact writers beneath `App/Platform/macOS/` and `App/Platform/iOS/` as needed, but keep the command codec and snapshot contracts shared. Do not depend on `screencapture`, screen-recording permissions, or coordinate-based clicking for the core artifact loop.

This milestone must also define the shared workspace abstraction that the universal brief requires. Add a `WorkspacePath` value type and a `WorkspaceProvider` protocol in a shared location, then create a macOS filesystem provider plus an iOS/iPad test-fixture or document-provider-backed provider stub. The shell should also expose a central accessibility identifier catalog, for example `AccessibilityIDs.swift`, with stable IDs shared across platforms. It should surface `sidebar.outline` or `sidebar.list`, `nav.back`, `nav.forward`, `nav.title`, `document.scrollView`, and at least one placeholder block identifier early so UI tests and snapshots can stabilize before the full block renderer is complete.

### Milestone 4: Create the universal fixture corpus and checkpoint pipeline

Create the repository-owned fixture tree under `Fixtures/`. Add `Fixtures/docs/`, `Fixtures/media/`, and `Fixtures/expected/`. Start with the fixture names from the universal brief, but allow placeholder content for feature areas that are not implemented yet. `basic_typography.md`, `anchors_and_relative_links.md`, `mixed_long_document.md`, and `stress_1000_blocks.md` should exist immediately because they exercise the shell, scrolling, history, and platform layout paths even before tables, code blocks, GIFs, APNG, and video are fully supported. Add small local media files for at least one PNG, one GIF, one APNG, and one MP4 so the harness can validate media classification and missing-file behavior later without depending on developer-specific paths.

Add `scripts/capture-checkpoint`, `scripts/compare-goldens`, and `scripts/collect-perf`. `scripts/capture-checkpoint` should create a fresh artifact directory under `artifacts/checkpoints/<checkpoint-name>/`, launch the app in harness mode against the requested fixture and platform target, wait for the app to write a ready file, optionally send command requests through the file-backed bridge, then request `state.json`, `perf.json`, and `window.png`. `scripts/compare-goldens` should compare JSON deterministically and compare images through a small repo-owned utility rather than a third-party package. `scripts/collect-perf` should gather the app’s internal performance snapshot plus host-side memory data from standard macOS commands, while preserving the platform and device metadata so macOS, iPhone, and iPad results do not overwrite one another.

This milestone must create the first checked-in expected outputs in `Fixtures/expected/` and prove that a smoke checkpoint is reproducible on macOS plus at least one simulator idiom, with the other simulator idiom added before the milestone closes.

### Milestone 5: Add native tests and knowledge-maintenance automation

Turn the placeholder test bundles into real harness coverage. Inside `Swift Markdown Viewer/Swift Markdown ViewerTests/`, add tests for launch-option parsing, command-request decoding, command-response encoding, artifact path normalization, fixture path resolution, `WorkspaceProvider` behavior, and snapshot schema stability. Add integration-named tests in the same target for the bridge-to-shell flow, for example opening a fixture and observing a valid state dump without using XCUITest. Inside `Swift Markdown Viewer/Swift Markdown ViewerUITests/`, add harness smoke tests that launch the app with `--fixture-root`, assert the stable accessibility identifiers, and validate that the shell creates the requested dump files when the launch arguments ask for them. Split the test files by destination behavior, for example `HarnessSmokeMacOSTests.swift` and `HarnessSmokeIOSTests.swift`, even if they still live inside one XCUITest target at first.

Create `scripts/check_execplan.py` plus `scripts/knowledge/check_docs.py`, `scripts/knowledge/generate_repo_map.py`, `scripts/knowledge/update_quality_score.py`, and `scripts/knowledge/suggest_doc_updates.py`. These should follow the reference harness pattern but adapt to this repository’s native layout. The repo-map generator must ignore `artifacts/`, `.git/`, `DerivedData`, `xcuserdata`, `tmp/`, and any generated screenshot/result-bundle directories. `check_docs.py` must verify the presence of the control-plane docs and call `scripts/check_execplan.py`. `update_quality_score.py` should summarize harness debt such as missing docs, missing fixture outputs, missing test layers, missing simulator coverage, and missing checkpoint coverage. Add `docs/generated/repo-map.json` as a checked-in artifact.

Add GitHub workflows under `.github/workflows/` that run on macOS. `verify.yml` should call the bootstrap, build, unit-test, macOS UI smoke, and iOS UI smoke scripts. `knowledge-base.yml` should validate docs and repo-map drift. Keep the workflows repo-safe: no workflow should require non-local secrets or unsupported Apple SDK targets.

### Milestone 6: Prove the harness with the first real universal viewer shell slice

Use the harness to validate one thin vertical slice of the actual viewer shell. Replace the `Hello, world!` placeholder with a real universal shell that can open the fixture root, show a sidebar or drawer, show back and forward controls, and render a simple selected-document body. The shell does not need the full Markdown engine yet, but it must exercise the future shape of the app enough for the harness to prove value. On macOS the shell should show the persistent sidebar where practical. On iPad it should show a split or collapsible sidebar. On iPhone it should use a compact presentation that still exposes navigation and selection. The shell must update the state snapshot and accessibility identifiers correctly when a different fixture is opened or when a checkpoint command requests a new file.

This milestone is the proof that the harness is not just documentation and scripts. At the end of it, `./scripts/agent-loop` should compile the app, run harness-focused unit/UI checks, and capture or compare at least one real checkpoint on macOS, iPhone simulator, and iPad simulator against checked-in expected outputs.

## Concrete Steps

Run all commands from `/Users/matthewmoore/Projects/swift-markdown-viewer` unless stated otherwise.

1. Verify the current bootstrap assumptions before editing scripts or docs:

       xcodebuild -list -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj'

   Expected result: the scheme list includes `Swift Markdown Viewer`.

2. Create the control-plane docs and metadata from Milestone 1, then confirm the new plan-routing layer exists:

       python3 scripts/check_execplan.py docs/exec-plans/active/2026-03-19-swift-codex-cli-harness.md
       python3 scripts/knowledge/check_docs.py

   Expected result: both commands succeed and report the active plan plus the required docs tree.

3. Build the universal app through the wrapper, not by typing raw `xcodebuild` flags repeatedly:

       ./scripts/bootstrap-apple
       ./scripts/build --platform all

   Expected result: `./scripts/bootstrap-apple` prints the resolved project path, scheme, simulator destinations, Xcode version, and artifact directories; `./scripts/build --platform all` ends with successful build output and leaves `.xcresult` bundles under `artifacts/xcodebuild/`.

4. Turn the default unit and UI targets into harness verification commands:

       ./scripts/test-unit
       ./scripts/test-ui-macos --smoke
       ./scripts/test-ui-ios --device iphone --smoke
       ./scripts/test-ui-ios --device ipad --smoke

   Expected result: the unit tests prove the harness codecs, workspace abstractions, and path handling; the UI smoke suites launch the app on macOS, iPhone simulator, and iPad simulator and assert the stable accessibility identifiers.

5. Create the first fixture-driven checkpoints:

       ./scripts/capture-checkpoint --fixture basic_typography.md --platform-target macos --checkpoint shell-smoke-macos
       ./scripts/capture-checkpoint --fixture basic_typography.md --platform-target ios --device-class iphone --checkpoint shell-smoke-iphone
       ./scripts/capture-checkpoint --fixture basic_typography.md --platform-target ios --device-class ipad --checkpoint shell-smoke-ipad

   Expected result: each checkpoint directory contains `state.json`, `perf.json`, and `window.png`. The JSON must identify the requested platform target, device class, fixture root, and selected file, and the screenshot must show the real app shell rather than the template `Hello, world!` view.

6. Compare the fresh checkpoints to checked-in expectations:

       ./scripts/compare-goldens --checkpoint shell-smoke-macos
       ./scripts/compare-goldens --checkpoint shell-smoke-iphone
       ./scripts/compare-goldens --checkpoint shell-smoke-ipad

   Expected result: each command exits successfully when the new artifacts match `Fixtures/expected/`.

7. Run the fast Codex loop that future work should rely on:

       ./scripts/agent-loop

   Expected result: the script builds the app, runs narrow tests, runs macOS and simulator smoke paths relevant to the current slice, reports any failures concisely, and exits zero when the repo is healthy.

8. Refresh and validate the durable knowledge artifacts:

       python3 scripts/knowledge/generate_repo_map.py
       python3 scripts/knowledge/update_quality_score.py
       python3 scripts/knowledge/check_docs.py

   Expected result: `docs/generated/repo-map.json` and `docs/QUALITY_SCORE.md` update deterministically, and the docs checker confirms the universal harness control plane is complete.

## Validation and Acceptance

The harness is acceptable only when a newcomer can start from repository root and discover the correct workflow without opening Xcode first. `README.md`, `AGENTS.md`, `ARCHITECTURE.md`, `.agents/PLANS.md`, `docs/PLANS.md`, `docs/harness.md`, and `docs/debug-contracts.md` must all exist, point at one another coherently, and describe the same command surface for macOS, iPhone simulator, and iPad simulator work.

The shell wrapper layer is acceptable when the project path with spaces and the destination-selection details stop mattering to normal development. A contributor should be able to run `./scripts/build --platform all`, `./scripts/test-unit`, `./scripts/test-ui-macos --smoke`, `./scripts/test-ui-ios --device both --smoke`, and `./scripts/agent-loop` without manually spelling out the project path, scheme, destination, simulator runtime, or DerivedData location. The scripts must leave their artifacts beneath `artifacts/` and must fail with readable messages when prerequisites are missing.

The in-app harness seam is acceptable when the app can be launched in debug harness mode against an in-repo fixture and can then produce deterministic artifacts without coordinate-based automation on all supported surfaces. A valid smoke run writes `state.json`, `perf.json`, and `window.png`. `state.json` must include `platform`, `deviceClass`, `workspaceRoot`, `selectedFile`, `history.backCount`, `history.forwardCount`, `viewport`, and `visibleBlocks`. `perf.json` must include at least `platform`, `deviceClass`, `launchTime`, `readyTime`, `visibleBlockCount`, and placeholder media counters even before the renderer implements all media types.

The initial performance contract is harness-focused rather than renderer-focused. On local Debug builds running the smoke fixture, launch-to-ready should stay under five seconds on macOS and under eight seconds on simulator surfaces, an idle `dumpState` or `dumpPerf` round trip through the file-backed bridge should stay under 250 milliseconds on macOS and 500 milliseconds on simulator surfaces, and `captureWindow` should complete under 1.5 seconds on macOS and under 2.5 seconds on simulator surfaces. Once the renderer lands, later plans may tighten these thresholds and add block/media-specific memory gates, but the control-plane metrics must exist from the beginning.

The knowledge-maintenance layer is acceptable when `python3 scripts/check_execplan.py`, `python3 scripts/knowledge/check_docs.py`, and the macOS GitHub workflows all pass, and when rerunning the repo-map and quality-score generators without source changes is a no-op.

## Idempotence and Recovery

All harness commands must be safe to rerun. `./scripts/bootstrap-apple` should create missing artifact directories but never delete checked-in files. Build and test wrappers should write to stable result-bundle paths under `artifacts/` and replace older bundles only for the same command name and destination. The app’s debug-only harness mode must be opt-in through launch arguments or a debug build setting so normal application runs remain clean.

The file-backed bridge must use per-run command directories so stale requests from a prior crash do not poison the next run. `scripts/capture-checkpoint` should create a fresh temporary run directory, wait for a ready marker from the app, and remove only that run directory on cleanup. If a UI test, simulator boot, or harness launch hangs, the recovery path is to kill the launched app or simulator process, delete the temporary command directory, and rerun the command. No recovery step should require deleting the Xcode project or hand-editing DerivedData outside the repository.

Checked-in expected artifacts belong under `Fixtures/expected/`. Runtime artifacts belong under `artifacts/`. Never overwrite checked-in goldens implicitly during normal build or test commands. Goldens should change only through an explicit compare-or-refresh workflow that is documented in `docs/harness.md`.

## Artifacts and Notes

The file-backed bridge should exchange JSON shaped like this:

    {
      "id": "shell-smoke-open",
      "command": "openFile",
      "arguments": {
        "path": "basic_typography.md"
      }
    }

The matching response should be just as explicit:

    {
      "id": "shell-smoke-open",
      "status": "ok",
      "result": {
        "selectedFile": "basic_typography.md"
      }
    }

The first stable smoke snapshot should look roughly like this, even if most block kinds are still placeholders:

    {
      "platform": "iOS",
      "deviceClass": "iPad",
      "workspaceRoot": "Fixtures/docs",
      "selectedFile": "basic_typography.md",
      "history": {
        "backCount": 0,
        "forwardCount": 0
      },
      "viewport": {
        "x": 0,
        "y": 0,
        "width": 1024,
        "height": 1366
      },
      "visibleBlocks": [
        {
          "id": "block.placeholder.0",
          "kind": "paragraph",
          "text": "Basic typography"
        }
      ],
      "sidebar": {
        "selectedNode": "basic_typography.md"
      }
    }

The wrapper scripts should standardize artifacts like this:

    artifacts/
      xcodebuild/
        build-macos.xcresult
        build-ios-sim.xcresult
        test-unit.xcresult
        test-ui-macos-smoke.xcresult
        test-ui-ios-iphone-smoke.xcresult
        test-ui-ios-ipad-smoke.xcresult
      checkpoints/
        shell-smoke-macos/
          state.json
          perf.json
          window.png
        shell-smoke-iphone/
          state.json
          perf.json
          window.png
        shell-smoke-ipad/
          state.json
          perf.json
          window.png

## Interfaces and Dependencies

Create `scripts/lib/xcode-env.sh` with exported variables for the project path, scheme, macOS destination, iPhone simulator destination, iPad simulator destination, DerivedData directory, result-bundle directory, fixture root, and artifacts root. All other shell scripts must source this file instead of duplicating those values.

In a shared harness file such as `Swift Markdown Viewer/Swift Markdown Viewer/Harness/HarnessLaunchOptions.swift`, define types equivalent to:

    enum HarnessPlatformTarget: String, Codable {
        case macOS
        case iOS
    }

    enum HarnessDeviceClass: String, Codable {
        case mac
        case iphone
        case ipad
    }

    struct HarnessLaunchOptions {
        let fixtureRoot: URL?
        let openFile: String?
        let theme: String?
        let windowSize: CGSize?
        let disableFileWatch: Bool
        let dumpVisibleStateURL: URL?
        let dumpPerfStateURL: URL?
        let screenshotDirectoryURL: URL?
        let commandDirectoryURL: URL?
        let uiTestMode: Bool
        let platformTarget: HarnessPlatformTarget
        let deviceClass: HarnessDeviceClass
    }

In a shared workspace file such as `Swift Markdown Viewer/Swift Markdown Viewer/App/Shared/WorkspaceProvider.swift`, define the universal workspace contract required by the product brief:

    struct WorkspacePath: Hashable, Codable {
        let rawValue: String
    }

    protocol WorkspaceProvider {
        func loadRoot() async throws -> Workspace
        func readFile(at path: WorkspacePath) async throws -> String
        func resolveMediaURL(for path: WorkspacePath) async throws -> URL
    }

In `Swift Markdown Viewer/Swift Markdown Viewer/Harness/HarnessCommand.swift`, define request and response types for the file-backed bridge. The request side must support at least `openWorkspace`, `openFile`, `setWindowSize`, `scrollToY`, `scrollToBlock`, `dumpState`, `dumpPerf`, `captureWindow`, `playMedia`, and `pauseMedia`. The response side must always echo the request `id` and include either a typed `result` payload or an explicit failure payload with a readable message.

In shared harness files such as `Swift Markdown Viewer/Swift Markdown Viewer/Harness/HarnessStateSnapshot.swift` and `Swift Markdown Viewer/Swift Markdown Viewer/Harness/HarnessPerformanceSnapshot.swift`, define the stable JSON contracts used by the harness artifacts. These files are part of the public harness contract inside the repository. If their shape changes, update `docs/debug-contracts.md`, the tests, the expected fixtures, and the plan in the same change.

Use system frameworks only unless a later milestone proves a missing capability. The core dependencies should be SwiftUI for the app shell, Foundation for JSON and file I/O, XCTest/XCUITest for tests, Python 3 standard library for docs and repo-map scripts, AppKit for macOS host adapters only, and UIKit for iOS/iPad host adapters only. Do not introduce `WKWebView`, HTML rendering, JavaScript execution, npm-based control scripts, or any dependency that weakens the native-renderer or shared-core constraints.

Plan change note: 2026-03-20 / Codex. Updated to reflect `codex_execplan_native_universal_gfm_viewer.md`, which supersedes the earlier macOS-only product brief and requires a universal macOS + iPhone + iPad harness.
