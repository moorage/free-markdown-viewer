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
- `block.image.<id>`
- `block.video.<id>`
- `video.playButton.<id>`

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
- `visibleBlocks[*].kind` values that distinguish media blocks such as `animatedImage` and `video`
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
