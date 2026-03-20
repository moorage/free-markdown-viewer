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
- `--platform-target macos|ios`
- `--device-class mac|iphone|ipad`

## Accessibility identifiers

Stable identifiers include:

- `sidebar.list`
- `nav.back`
- `nav.forward`
- `nav.title`
- `document.scrollView`
- `document.text`
- `block.placeholder.0`

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
