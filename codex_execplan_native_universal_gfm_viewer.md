# ExecPlan: Universal Apple GFM Viewer with Browser-Style Navigation

## Objective

Build a universal Apple-platform Markdown browser/viewer for macOS, iPhone, and iPad that renders a constrained subset of GitHub-Flavored Markdown with very high performance, low memory use, and a minimal, beautiful UI. The app must avoid browser technologies for rendering and must not support HTML/CSS rendering. It must support local workspace browsing, internal Markdown navigation, back/forward history, images, animated GIF/APNG, and local video playback for a narrow whitelist of system-supported formats.

This plan is written so Codex CLI can execute against it in a continuous build-test-run-repair loop with minimal human intervention.

## Required outcome

The finished app must:

- Run as a universal Apple-platform app on macOS, iPhone, and iPad.
- Open a local workspace root directory or user-selected folder/document-provider-backed workspace, depending on platform.
- Show a sidebar/drawer with the subdirectory tree and Markdown files.
- Render Markdown files natively using a shared core plus platform-native text/media host views.
- Support the following Markdown features:
  - headings
  - paragraphs
  - emphasis / strong
  - strikethrough
  - autolinks
  - links
  - block quotes
  - unordered/ordered lists
  - task lists
  - tables
  - fenced code blocks with syntax highlighting
  - inline code
  - images
- Support media:
  - static local images
  - animated GIF
  - animated APNG
  - local video blocks via explicit custom syntax
- Support navigation:
  - sidebar file selection
  - internal relative Markdown navigation
  - anchors within and across files
  - back and forward buttons
  - keyboard shortcuts for back/forward where platform-appropriate
  - per-history-entry scroll restoration
- Exclude:
  - inline HTML
  - raw HTML blocks
  - CSS
  - JavaScript
  - remote video
  - remote web rendering
  - browser engines

## Product constraints that must not be weakened

These constraints are part of the product design, not optional implementation choices:

- No `WKWebView` or browser-based rendering.
- No HTML intermediary representation for core rendering.
- No remote video playback.
- No autoplay video.
- No broad codec promises beyond a strict whitelist.
- No nested view explosion for tables or document blocks.
- No full-document eager rasterization of images or animations.
- No main-thread media decode.
- No support for browser-only Markdown behavior.
- No AppKit-only architecture in shared core code.
- No platform-specific UI types in shared core packages.

## Root architecture

The app is a universal native document browser with five major subsystems:

1. Workspace browser
2. Navigation/history controller
3. Markdown parse/render/layout engine
4. Media pipeline
5. Platform shells

The renderer must remain isolated from workspace browsing and navigation state. Platform shells must remain isolated from shared parsing, layout, navigation, and media logic.

## High-level architecture

```text
Workspace provider (filesystem or document-provider-backed)
    ↓
WorkspaceController
    ↓
AppCoordinator
    ├─ NavigationController
    ├─ MarkdownDocumentController
    ├─ Sidebar/Selection state
    └─ Platform shell
            ↓
Markdown parser → AST → Render IR → Block layout → Native rendering hosts
                                      ├─ Text blocks via TextKit 2 hosts
                                      ├─ Tables via custom renderer
                                      ├─ Code via custom renderer
                                      ├─ Images via custom renderer
                                      ├─ Animated GIF/APNG via custom renderer
                                      └─ Local video via AVFoundation
```

## Recommended implementation stack

- Language: Swift
- App shell: SwiftUI
- Text layout: TextKit 2 through platform-native host views
- Workspace tree: shared tree model rendered in SwiftUI sidebar/list views
- Top-level layout: `NavigationSplitView` on macOS and iPad where appropriate, compact navigation behavior on iPhone
- Video: AVFoundation, prefer `AVPlayerLayer` for embedded playback
- Animated image decode/timing: Image I/O
- Tests: XCTest + XCUITest
- Build/test execution: `xcodebuild`
- Continuous dev loop: Codex CLI operating through shell scripts

## Why full Xcode is required for the human setup

This project should be built as a real universal Apple app target with XCTest/XCUITest, native UI hosts, assets, and command-line build/test control through `xcodebuild`. Apple documents Xcode as the full app-development suite and `xcodebuild` as the CLI entrypoint for Xcode projects/workspaces and schemes. The Command Line Tools package is useful for UNIX-style development, but for a normal Apple-platform app target and UI automation, full Xcode is the correct setup.

## Human prerequisites before running Codex

The human should do these steps once before starting Codex on this plan.

### 1. Install full Xcode

Install the current Xcode app and verify:

```bash
xcodebuild -version
xcode-select -p
swift --version
```

### 2. Accept Xcode licensing and complete first-run tasks

Run:

```bash
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

### 3. Create or initialize the repository

At minimum, create an empty Git repository and the initial project root directory.

### 4. Create the Xcode project skeleton

A human may either:

- create an empty universal Apple app project in Xcode, or
- let Codex create the project files if the environment already supports deterministic project generation and `xcodebuild` works afterward.

Preferred human action: create a minimal `.xcodeproj` manually once, with:

- app target configured for macOS, iPhone, and iPad
- shared Swift packages or local packages for core modules
- XCTest unit test target
- UI test targets appropriate for the chosen platforms
- one shared scheme checked in

This removes a class of bootstrap risk.

### 5. Ensure simulator and UI testing prerequisites can work

The machine must be able to run UI tests locally. The human should be ready to grant any required local macOS permissions for test automation, screen recording, or accessibility if prompted by the OS, and should also ensure the required iPhone/iPad simulators are installed if simulator-based UI testing is part of the loop.

### 6. Install Codex CLI and authenticate

Set up Codex CLI and verify it runs at the repository root. OpenAI’s Codex docs describe using Codex through the CLI and recommend terminal-first workflows at the repo root. ([developers.openai.com](https://developers.openai.com/api/docs/guides/code-generation?gallery=open&galleryItem=espresso&utm_source=chatgpt.com))

### 7. Ensure the repo can be built entirely from the shell

The human should verify that all build/test entrypoints work from Terminal, not only from the Xcode GUI.

### 8. Optional but strongly recommended: grant deterministic local fixture access

Keep the workspace fixtures and media fixtures inside the repository so Codex can use them without user-specific paths.

## Codex operating model

Codex must not merely write code and stop. It must run in a continuous verification-and-repair loop. OpenAI’s Codex workflow guidance explicitly recommends a tight loop with reproduction and verification, and OpenAI’s local shell guidance describes agents operating in a continuous loop through terminal access. OpenAI’s long-horizon Codex guidance also recommends verification at each milestone, with repair before continuing. ([developers.openai.com](https://developers.openai.com/codex/workflows/?utm_source=chatgpt.com))

### Codex loop contract

For every milestone and subtask, Codex must:

1. Inspect the current codebase and plan the minimal next slice.
2. Make code changes.
3. Build.
4. Run targeted tests.
5. Launch or drive the app when UI verification is required.
6. Capture semantic state and visual artifacts.
7. Compare against expected outputs.
8. Repair failures.
9. Repeat until the milestone passes all required checks.
10. Then move to the next milestone.

### Codex must avoid these anti-patterns

- Do not stop after code generation without verification.
- Do not rely on one giant end-of-project test pass.
- Do not declare success when only compilation succeeds.
- Do not rely only on screenshot eyeballing when semantic checks are available.
- Do not keep asking the human for confirmation between routine milestones.
- Do not weaken tests to make failures disappear.

## Repository shape Codex should create or converge toward

```text
.
├─ App/
│  ├─ Shared/
│  │  ├─ AppCoordinator.swift
│  │  ├─ WorkspaceController.swift
│  │  ├─ NavigationController.swift
│  │  └─ MarkdownDocumentController.swift
│  ├─ Shell/
│  │  ├─ AppRootView.swift
│  │  ├─ SidebarView.swift
│  │  ├─ ContentView.swift
│  │  └─ TopToolbarContent.swift
│  ├─ Platform/
│  │  ├─ macOS/
│  │  ├─ iOS/
│  │  └─ SharedAdapters/
│  └─ AppEntry/
├─ Packages/
│  ├─ MarkdownCore/
│  ├─ MarkdownRenderModel/
│  ├─ MarkdownLayout/
│  ├─ MarkdownMedia/
│  ├─ WorkspaceCore/
│  ├─ NavigationCore/
│  └─ HarnessCore/
├─ Fixtures/
│  ├─ docs/
│  ├─ media/
│  └─ expected/
├─ Tests/
│  ├─ Unit/
│  ├─ Integration/
│  ├─ UITests-macOS/
│  └─ UITests-iOS/
├─ scripts/
│  ├─ bootstrap-apple
│  ├─ build
│  ├─ test-unit
│  ├─ test-integration
│  ├─ test-ui-macos
│  ├─ test-ui-ios
│  ├─ capture-checkpoint
│  ├─ compare-goldens
│  ├─ collect-perf
│  └─ agent-loop
├─ docs/
│  ├─ architecture.md
│  ├─ harness.md
│  └─ debug-contracts.md
├─ MarkdownViewer.xcodeproj
└─ README.md
```

## Core domain model

### Workspace

```swift
struct Workspace {
    let rootIdentifier: String
    let tree: DirectoryNode
}

struct DirectoryNode: Identifiable {
    let id: String
    let path: WorkspacePath
    let name: String
    let directories: [DirectoryNode]
    let markdownFiles: [MarkdownFileNode]
}

struct MarkdownFileNode: Identifiable {
    let id: String
    let path: WorkspacePath
    let name: String
}

struct WorkspacePath: Hashable, Codable {
    let rawValue: String
}
```

```swift
protocol WorkspaceProvider {
    func loadRoot() async throws -> Workspace
    func readFile(at path: WorkspacePath) async throws -> String
    func listChildren(of path: WorkspacePath) async throws -> [WorkspaceNode]
    func resolveMediaURL(for path: WorkspacePath) async throws -> URL
}

enum WorkspaceNode {
    case directory(DirectoryNode)
    case markdownFile(MarkdownFileNode)
}
```

Implementations should include:

- local filesystem provider for macOS
- security-scoped or document-provider-backed provider for iPhone and iPad

### Navigation

```swift
struct NavigationEntry: Equatable {
    let filePath: WorkspacePath
    let anchor: String?
    let scrollPosition: CGFloat?
}
```

### AST

```swift
enum BlockNode {
    case paragraph([InlineNode], SourceRange)
    case heading(level: Int, content: [InlineNode], SourceRange)
    case blockQuote([BlockNode], SourceRange)
    case unorderedList([ListItemNode], SourceRange)
    case orderedList(start: Int, items: [ListItemNode], SourceRange)
    case table(TableNode, SourceRange)
    case fencedCode(info: String?, text: String, SourceRange)
    case image(ImageNode, SourceRange)
    case thematicBreak(SourceRange)
}
```

### Render IR

```swift
enum RenderBlock {
    case text(TextBlockModel)
    case quote(QuoteBlockModel)
    case list(ListBlockModel)
    case table(TableBlockModel)
    case code(CodeBlockModel)
    case image(ImageBlockModel)
    case animatedImage(AnimatedImageBlockModel)
    case video(VideoBlockModel)
    case rule(RuleBlockModel)
}
```

## Media rules

### Supported static images

- png
- jpg / jpeg
- heic
- tiff
- bmp
- gif with one frame only

### Supported animated images

- gif with multiple frames
- apng

### Supported local video formats

Strict whitelist for v1:

- mp4
- mov
- m4v

### Rejected media

- remote video URLs
- streaming playlists
- raw HTML media
- browser embeds

### Markdown syntax

Use standard Markdown image syntax for images and animated images:

```md
![alt text](./image.png)
![demo](./demo.gif)
![demo](./flow.apng)
```

Use explicit custom syntax for local video blocks:

```md
!video[Demo](./demo.mp4)
!video[](./walkthrough.mov)
```

## Navigation behavior

### Sidebar behavior

- Show directories and Markdown files only.
- Sort directories first, then Markdown files, alphabetically.
- Highlight the current file.
- Support collapse/expand.
- Ignore junk directories by default such as `.git`, `node_modules`, `.build`, and `DerivedData`.

### Internal link rules

- `#anchor` navigates within current document.
- relative `.md` links navigate internally.
- relative non-Markdown files open externally or via a basic preview policy later.
- external URLs open externally via `NSWorkspace`.
- remote video must not open in-app.

### History rules

- Opening a new internal document pushes the current entry onto the back stack and clears the forward stack.
- Back restores the previous file and scroll position.
- Forward restores the next file and scroll position.
- Scroll position is stored per history entry.

### Keyboard shortcuts

- Back: `⌘[`
- Forward: `⌘]`

## UI layout

Use a SwiftUI app shell with platform-native rendering hosts underneath.

Preferred top-level structure:

```text
NavigationSplitView or compact navigation shell
  ├─ Sidebar tree/list
  └─ Content pane
       ├─ top toolbar content
       └─ Markdown document host view
```

Behavior by platform:

- macOS: persistent sidebar where practical, toolbar with back/forward
- iPad: persistent or collapsible sidebar depending on size/class
- iPhone: compact navigation presentation with collapsible sidebar behavior

Top bar / toolbar includes:

- back button
- forward button
- current file title or breadcrumb

## Rendering architecture

### Text blocks

Use TextKit 2 for text shaping, selection, accessibility, and links.

### Tables

Treat each table as one specialized block renderer. Do not use nested `NSTableView`. Do not create a view per cell in normal display mode.

### Code blocks

Use a specialized code renderer with monospaced font, padding, background, and cached lexical syntax highlighting.

### Images

Treat block images as first-class block content rather than generic text attachments.

### Animated GIF/APNG

Use Image I/O-driven metadata and frame timing. Animate only while visible. Use a rolling frame buffer. Do not fully decode all frames into memory.

### Video

Use AVFoundation with `AVPlayerLayer` for embedded playback. Use poster frame before play. Pause by default. Do not autoplay. Prefer one active playing video at a time.

## App-level controllers Codex should implement

### AppCoordinator

Responsibilities:

- open workspace
- open file
- resolve links
- route internal vs external links
- synchronize sidebar selection
- coordinate history and document loading
- remain platform-neutral

### WorkspaceController

Responsibilities:

- load workspace tree through `WorkspaceProvider`
- filter Markdown files
- expose file lookup by path
- refresh tree

### NavigationController

Responsibilities:

- manage back/current/forward stacks
- preserve and restore history entries

### MarkdownDocumentController

Responsibilities:

- load current file
- parse
- build render IR
- layout blocks
- manage visible-state export
- remain platform-neutral

### Platform render hosts

Codex should implement native host views for:

- macOS text/document host
- iOS/iPadOS text/document host
- macOS media host surfaces
- iOS/iPadOS media host surfaces

These hosts should be thin adapters around shared render/layout/media logic.

## Harness design requirements

Codex cannot succeed reliably unless the app is observable and scriptable. The harness must expose deterministic fixtures, machine-readable state, repeatable UI control, screenshots, and perf counters.

### Required observability surfaces

#### Accessibility identifiers

Every important UI surface must have stable identifiers shared across platforms, including:

- `sidebar.outline` or `sidebar.list`
- `sidebar.node.<stable-path>`
- `nav.back`
- `nav.forward`
- `nav.title`
- `document.scrollView`
- `block.heading.<id>`
- `block.table.<id>`
- `block.code.<id>`
- `block.image.<id>`
- `block.video.<id>`
- `video.playButton.<id>`

#### Debug state dumps

The app must support a debug-only structured state export. At minimum:

```json
{
  "platform": "macOS | iOS",
  "workspaceRoot": "Fixtures/docs",
  "selectedFile": "guide/intro.md",
  "history": {
    "backCount": 2,
    "forwardCount": 1
  },
  "viewport": {
    "x": 0,
    "y": 512,
    "width": 980,
    "height": 820
  },
  "visibleBlocks": [
    {"id": "h1-0", "kind": "heading", "text": "Demo"},
    {"id": "table-3", "kind": "table", "rows": 8, "cols": 3},
    {"id": "gif-5", "kind": "animatedImage", "playing": true},
    {"id": "video-6", "kind": "video", "paused": true}
  ],
  "sidebar": {
    "selectedNode": "guide/intro.md"
  }
}
```

#### Perf dump

The app must expose a machine-readable perf snapshot with at least:

- platform
- launch time
- first render time
- visible block count
- active animated media count
- active video player count
- current memory estimate or RSS capture from harness side
- image decode counters
- frame cache sizes

### Required test launch arguments

The app should support deterministic launch flags such as:

```text
--fixture-root Fixtures/docs
--open-file guide/intro.md
--theme test-light
--window-size 1100x900
--disable-file-watch
--disable-remote-images
--dump-visible-state /tmp/state.json
--dump-perf-state /tmp/perf.json
--screenshot-dir /tmp/screens
--ui-test-mode 1
--platform-target macos|ios
```

### Required debug control seam

Codex should not have to drive every action through fragile coordinate-based UI gestures. Add a debug-only seam accessible in test mode.

At minimum, provide operations equivalent to:

```swift
protocol HarnessControllable {
    func openWorkspace(at path: String)
    func openFile(at path: String)
    func setViewport(width: CGFloat, height: CGFloat)
    func scrollTo(y: CGFloat)
    func scrollToBlock(id: String)
    func dumpVisibleState() -> Data
    func dumpPerfCounters() -> Data
    func playMedia(blockID: String)
    func pauseMedia(blockID: String)
    func forceRelayout()
}
```

This can be wired through launch arguments plus XCUITest hooks, or a debug-only local IPC endpoint if desired.

## Fixture corpus Codex must create

Create a deterministic fixture corpus in-repo.

### Markdown fixtures

- `basic_typography.md`
- `lists_and_tasks.md`
- `tables_small.md`
- `tables_wide.md`
- `codeblocks_languages.md`
- `images_static.md`
- `images_large.md`
- `animated_gif.md`
- `animated_apng.md`
- `video_local_mp4.md`
- `anchors_and_relative_links.md`
- `nested_workspace_navigation.md`
- `mixed_long_document.md`
- `stress_1000_blocks.md`

### Media fixtures

- small/large png and jpeg
- representative gif
- representative apng
- local `mp4`, `mov`, and `m4v`
- broken-path media references

### Expected outputs

For key checkpoints, create:

- expected visible-state JSON
- golden screenshots
- expected navigation state
- expected media classification

## Required test layers

### 1. Unit tests

Must cover:

- opening workspace
- sidebar selection
- clicking Markdown links to another file
- back/forward button behavior
- keyboard shortcuts for navigation where supported
- scrolling to target blocks
- image appearance
- animated GIF/APNG play while visible and pause offscreen
- video poster frame and play transition
- window or viewport resize relayout correctness
- screenshot capture at named checkpoints
- macOS smoke suite
- iPhone simulator smoke suite
- iPad simulator smoke suite

## Verification rules per feature class

### Rendering verification

Verify via all of:

- build success
- relevant unit and integration tests
- visible-state JSON
- golden screenshots where stable

### Animated media verification

Verify:

- classified as animated image
- frame index advances while visible
- playback pauses when offscreen
- no all-frame eager decode

### Video verification

Verify:

- local video classified correctly
- poster frame present before playback
- play changes state to playing
- remote video references are rejected
- offscreen or navigation transition pauses/stops playback according to policy

### Navigation verification

Verify:

- sidebar click opens file
- internal relative links open the correct file
- current sidebar selection updates after internal navigation
- back restores previous file and scroll position
- forward restores next file and scroll position

## Performance gates

Codex must treat performance as part of correctness.

At minimum, define performance checks for:

- launch to first rendered frame
- first-screen render time for representative fixtures
- peak RSS for `mixed_long_document.md`
- peak RSS for animated media fixture
- active video player count
- visible block count and view count
- no offscreen animation playback

Initial thresholds can be conservative and then tightened, but they must exist.

## Scripts Codex must implement

### `scripts/bootstrap-apple`

Responsibilities:

- verify Xcode availability
- verify `xcodebuild`
- verify shared scheme exists
- create derived-data directories if desired

### `scripts/build`

Responsibilities:

- build the app target through `xcodebuild`
- emit concise logs and a stable exit code

### `scripts/test-unit`

Responsibilities:

- run unit tests only

### `scripts/test-integration`

Responsibilities:

- run integration tests only

### `scripts/test-ui-macos`

Responsibilities:

- run macOS UI tests
- support fixture targeting and named test subsets

### `scripts/test-ui-ios`

Responsibilities:

- run iPhone and/or iPad simulator UI tests
- support fixture targeting and named test subsets

### `scripts/capture-checkpoint`

Responsibilities:

- run the app in test mode on a specific fixture
- drive to a named checkpoint
- save screenshot, state JSON, and perf JSON

### `scripts/compare-goldens`

Responsibilities:

- compare current outputs to checked-in goldens
- return diff summary with paths

### `scripts/collect-perf`

Responsibilities:

- capture perf data for target fixtures
- store outputs in a stable directory

### `scripts/agent-loop`

This is the central Codex command.

Responsibilities:

1. build
2. run fast tests
3. run targeted integration tests for changed areas
4. run targeted UI tests for changed areas
5. capture artifacts if needed
6. compare outputs against expectations
7. print concise machine-readable failure summary
8. exit nonzero on failure

## Contract for `scripts/agent-loop`

Codex should be able to run:

```bash
./scripts/agent-loop
```

and get a full incremental health check suitable for continuous repair.

The script should prefer speed while still protecting correctness. One approach:

### Fast default path

- build
- unit tests
- selected integration tests
- selected macOS UI smoke tests
- selected iOS/iPad smoke tests where applicable

### Expanded path for milestone completion

- full build
- full unit test suite
- full integration suite
- selected visual and perf checkpoints
- full UI suite for affected milestones

## How Codex should work milestone by milestone

Codex must implement the app in thin vertical slices, not one giant pass.

## Milestone order

### Milestone 0: project scaffold and shell-driven build

Deliverables:

- Xcode project in repo
- shared scheme checked in
- universal targets configured for macOS, iPhone, and iPad
- shell scripts for build and test
- app launches to a placeholder shell on supported platforms
- unit test and UI test targets runnable through `xcodebuild`

Verification:

- `scripts/build`
- `scripts/test-unit`
- `scripts/test-ui-macos` smoke launch
- `scripts/test-ui-ios` smoke launch

### Milestone 1: shared workspace browser and shell navigation scaffold

Deliverables:

- `WorkspaceProvider` abstraction
- local filesystem provider for macOS
- initial document-provider or test-fixture provider for iOS/iPad
- SwiftUI sidebar/tree shell
- open workspace root
- current file loading from sidebar selection
- top toolbar with back/forward disabled state

Verification:

- unit tests for workspace scan and filtering
- integration tests for provider and tree model
- UI test selecting a file from sidebar on macOS and iPad-capable layout

### Milestone 2: Markdown parsing and text rendering foundation

Deliverables:

- parser integration
- AST and render IR skeleton
- text blocks, headings, lists, block quotes
- links and autolinks
- platform-native text host adapters for macOS and iOS/iPadOS
- current file title in top bar

Verification:

- parser tests
- render-model tests
- screenshot/golden for basic fixtures

### Milestone 3: task lists, strikethrough, tables, code blocks

Deliverables:

- task list rendering
- strikethrough
- table block renderer
- fenced code blocks with initial syntax highlighting

Verification:

- unit and integration tests for each
- screenshot/golden checkpoints

### Milestone 4: internal navigation and history

Deliverables:

- `NavigationController`
- relative `.md` links open internally
- anchors
- back/forward behavior
- scroll restoration
- keyboard shortcuts

Verification:

- history logic tests
- integration tests for path/anchor resolution
- UI tests for multi-file navigation and back/forward restore on macOS and at least one simulator form factor

### Milestone 5: static local images

Deliverables:

- media resolver
- image probing and display-size decode
- image block renderer
- broken image fallback

Verification:

- media classification tests
- screenshot checkpoints for static image fixtures
- perf sanity check on large images

### Milestone 6: animated GIF/APNG

Deliverables:

- animated image classification
- visible-only playback
- frame buffering policy
- offscreen pause behavior

Verification:

- animation state tests
- UI tests that verify play/pause behavior via semantic state
- artifact capture for animated fixture

### Milestone 7: local video blocks

Deliverables:

- custom `!video[]()` syntax
- local-only video resolution
- poster frame generation
- `AVPlayerLayer` playback block
- paused by default

Verification:

- parser and media classification tests
- UI tests for poster frame and play transition
- rejection tests for remote video

### Milestone 8: harness hardening across platforms

Deliverables:

- debug state dump
- perf dump
- checkpoint capture
- golden comparison tooling
- robust `scripts/agent-loop`
- macOS and iOS/iPad UI smoke coverage

Verification:

- integration tests for debug exports
- UI test artifact generation
- simulated failure to ensure loop exits nonzero and reports clearly

### Milestone 9: polish and performance tightening

Deliverables:

- refined theme
- memory trimming
- faster relayout
- reduce view count where possible
- final accessibility pass

Verification:

- perf checks on long document and animated media
- accessibility-focused UI tests
- milestone-level visual regression suite

## Codex prompt/instruction file guidance

Codex should be given repo-local instructions that reinforce persistence, verification, and non-interactive execution. OpenAI’s Codex guidance recommends tight-loop workflows and emphasizes reproduction plus verification; the Codex prompting guide also advises explicit autonomy and persistence patterns for coding tasks. ([developers.openai.com](https://developers.openai.com/codex/workflows/?utm_source=chatgpt.com))

Create a repo instruction file that tells Codex:

- work in small vertical slices
- always run relevant build/test/verification commands after changes
- repair failures before moving on
- do not stop at partial implementation when clear next steps exist
- prefer shell-driven validation to speculation
- prefer semantic/debug checks over pixel-only checks
- capture artifacts when UI behavior is in scope

## Suggested `AGENTS.md` content themes

The repo should include an `AGENTS.md` that tells Codex:

- the exact app constraints
- forbidden technologies
- required milestone order
- required verification commands
- expected fixture corpus
- how to use `scripts/agent-loop`
- that work is not complete until checks pass

## What the human should do while Codex is running

Normally, nothing. The plan is designed to minimize human intervention.

Human actions should only be needed for:

- one-time macOS permission prompts
- initial Xcode/bootstrap issues
- signing or scheme issues
- approving any OS-level security dialog that blocks UI automation or media capture
- installing additional iOS/iPad simulators if required by the test matrix

The human should not need to manually inspect every step if the harness artifacts are working.

## Definition of done

The project is done when all of the following are true:

- The app runs on macOS, iPhone, and iPad.
- The app opens a workspace and shows the Markdown file tree.
- Clicking files in the sidebar loads them.
- Internal Markdown links navigate correctly.
- Back/forward works with scroll restoration.
- All specified GFM subset features render correctly.
- Images, animated GIF/APNG, and local video behave according to policy.
- Remote video is rejected.
- The app is built and tested entirely from the shell.
- `scripts/agent-loop` can repeatedly detect issues, fail clearly, and pass when the code is correct.
- macOS and iOS/iPad smoke tests are part of the loop.
- The fixture corpus and golden artifacts are checked in.
- Performance gates and semantic debug checks exist and pass.
- The fixture corpus and golden artifacts are checked in.
- Performance gates and semantic debug checks exist and pass.

## First command for Codex

Once the human prerequisites are complete, start Codex at the repo root and instruct it to execute this plan non-interactively, milestone by milestone, always using the verification loop and always repairing failures before advancing. OpenAI’s Codex workflow docs explicitly recommend running from the repo root with a tight loop including reproduction and verification. ([developers.openai.com](https://developers.openai.com/codex/workflows/?utm_source=chatgpt.com))

## Minimal kickoff brief for Codex

Use this brief at the start of the Codex run:

> Build the app described in `codex_execplan_native_macos_gfm_viewer.md`. Follow the milestone order. Work in thin vertical slices. After every meaningful change, run the relevant build, tests, and harness checks. If something fails, diagnose and fix it before continuing. Do not stop after partial implementation when a clear next step remains. Prefer semantic state dumps, targeted UI tests, screenshots, and perf checks over guesswork. Verify on macOS and on iPhone/iPad simulator surfaces where applicable. The work is not done until the shell-driven verification loop passes.

