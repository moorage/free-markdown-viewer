# Debug Contracts

This file freezes the harness-visible app contracts.

## Launch arguments

Supported debug launch arguments:

- `--fixture-root <path>`
- `--open-file <relative-path>`
- `--theme <name>`
- `--window-size <width>x<height>`
- `--disable-file-watch`
- `--dump-visible-state <path>`
- `--dump-perf-state <path>`
- `--screenshot-path <path>`
- `--harness-command-dir <path>`
- `--ui-test-mode 1`
- `--ui-test-github-fixture <path>`
- `--ui-test-open-linked-media <url>`
- `--platform-target macos|ios`
- `--device-class mac|iphone|ipad`

## Accessibility identifiers

Stable identifiers include:

- `sidebar.list`
- `sidebar.filterField`
- `sidebar.filterClear`
- `nav.back`
- `nav.forward`
- `nav.title`
- `toolbar.openFolder`
- `toolbar.openGitHubURL`
- `toolbar.print`
- `toolbar.ignorePatterns`
- `print.preparing`
- `toolbar.tableWrap`
- `toolbar.tableSizing`
- `toolbar.documentOutline`
- `empty-state.github-url.field`
- `empty-state.github-url.load`
- `empty-state.github-url.error`
- `github-url.sheet.field`
- `github-url.sheet.load`
- `github-url.sheet.error`
- `ignore-patterns.sheet.field`
- `ignore-patterns.sheet.apply`
- `ignore-patterns.sheet.reset`
- `document.scrollView`
- `document.text`
- `document.outline.panel`
- `document.outline.list`
- `document.outline.item.<id>`
- `json.mode`
- `json.viewerScrollView`
- `json.sourceScrollView`
- `json.stickyHeader`
- `json.row.<id>`
- `json.gutter.<line>`
- `json.disclosure.<id>`
- `block.placeholder.0`
- `block.image.<id>`
- `block.video.<id>`
- `block.mermaid.<id>`
- `video.playButton.<id>`
- `media-preview.container`
- `media-preview.close`
- `media-preview.open-in-browser`
- `mermaid-preview.container`
- `mermaid-preview.close`
- `mermaid-preview.zoomIn`
- `mermaid-preview.zoomOut`
- `mermaid-preview.fit`
- `mermaid-preview.reset`

## State snapshot

The app must be able to emit JSON with:

- `platform`
- `deviceClass`
- `workspaceRoot`
- `selectedFile`
- `history.backCount`
- `history.forwardCount`
- `viewport`
- `visibleBlocks`
- `visibleBlocks[*].kind` values that distinguish rich blocks such as `animatedImage`, `video`, `mermaidDiagram`, and `jsonDocument`
- `sidebar.selectedNode`

## Perf snapshot

The app must be able to emit JSON with:

- `platform`
- `deviceClass`
- `launchTime`
- `readyTime`
- `visibleBlockCount`
- `activeAnimatedMediaCount`
- `activeVideoPlayerCount`

## Harness commands

Stable harness commands include:

- `printSelectedDocument` with argument `path`
- `printAllDocuments` with argument `path`
- `exportPrintedDocument` with argument `path`
- `exportPrintedAllDocuments` with argument `path`
