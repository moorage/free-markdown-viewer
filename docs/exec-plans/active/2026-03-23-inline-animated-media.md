# Inline Animated Media Rendering

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

After this workstream is complete, the app should render inline animated GIFs, inline APNGs, and local MP4 video blocks directly inside the document flow on macOS, iPhone, and iPad. The repository should own the media fixtures, the markdown fixtures that reference them, and the tests that prove those media blocks show up in the app instead of degrading to text placeholders or remaining invisible to the harness.

This initial slice intentionally stops before implementation. It seeds deterministic repo-owned media assets from `tmp/`, adds markdown fixtures that use the product-brief syntax, and lands red unit/UI tests that freeze the expected classification and accessibility surface. The next implementation slice should make those tests pass without changing the contract they define.

## Progress

- [x] (2026-03-24T05:34Z) Confirmed the existing product contract for animated images and local video: GIF/APNG use standard Markdown image syntax, MP4 uses explicit `!video[]()` syntax, and the target accessibility surface includes `block.image.<id>`, `block.video.<id>`, and `video.playButton.<id>`.
- [x] (2026-03-24T05:34Z) Copied `tmp/rickrolled.gif`, `tmp/rickrolled.png`, and `tmp/rickrolled.mp4` into the repo-owned `Fixtures/media/` tree and added the markdown fixtures `animated_gif.md`, `animated_apng.md`, and `video_local_mp4.md`.
- [x] (2026-03-24T05:34Z) Added red-first unit and UI tests that assert animated GIF/APNG classification as `animatedImage`, MP4 classification as `video`, and the presence of accessible inline media surfaces in the app once implementation lands.
- [x] (2026-03-24T05:40Z) Ran `python3 scripts/check_execplan.py` and `python3 scripts/knowledge/check_docs.py`; both passed after adding the new active plan and media accessibility contract notes.
- [x] (2026-03-24T05:40Z) Ran the targeted `InlineAnimatedMediaTests` slice; fixture presence passed and the three new behavior assertions failed as intended because the live app still exports text/image-style blocks instead of `animatedImage` and `video`.
- [x] (2026-03-24T05:40Z) Attempted the targeted macOS `InlineAnimatedMediaUITests` slice and confirmed the current stop point is an environment-level UITest runner bootstrap failure, not a compile or fixture-wiring issue.
- [x] (2026-03-24T05:54Z) Implemented shared `!video[]()` parsing, workspace-aware media hydration for GIF/APNG versus static images, harness media counters, and inline media block rendering with stable accessibility identifiers.
- [x] (2026-03-24T05:54Z) Reran the focused unit and regression slice successfully: `InlineAnimatedMediaTests`, `testSelectableDocumentFormatterUsesRenderedDocumentText`, `testMarkdownRendererParsesDirectImageFixture`, and `testMarkdownRendererParsesReferenceImageFixture` all pass.
- [x] (2026-03-24T06:23Z) Investigated the local macOS UITest runner failure and confirmed the "damaged" runner dialog was caused by running UI tests with `CODE_SIGNING_ALLOWED=NO`; the same slice boots normally when Xcode is allowed to ad-hoc sign the runner.
- [x] (2026-03-24T06:23Z) Hardened the macOS UI tests to derive the repo root from `#filePath` instead of `PWD`, which let the signed inline-media UI slice reach real app assertions on this machine.
- [x] (2026-03-24T06:23Z) Reran the signed macOS inline-media UI slice. `testAnimatedAPNGFixtureShowsAccessibleInlineImageBlock` now passes locally, while the GIF and MP4 UI assertions still fail and need follow-up product/debug work.
- [x] (2026-03-24T07:32Z) Replaced the macOS media hosts with native AppKit-backed surfaces: `NSImageView` for inline animated images and `AVPlayerView` for inline video. The focused signed macOS inline-media UI slice is now fully green.
- [x] (2026-03-24T07:34Z) Restored the macOS title accessibility contract by keeping the `nav.title` overlay in the accessibility tree without visually showing it. The older macOS smoke UI test is now green again.

## Surprises & Discoveries

- Observation: the repo-level harness plan already required `Fixtures/media/`, but the tree had never been created in the live repository.
  Evidence: `find Fixtures -maxdepth 3` listed `Fixtures/docs/`, `Fixtures/expected/`, and `Fixtures/window-workspaces/`, but no `Fixtures/media/`.

- Observation: `tmp/rickrolled.png` is a real APNG even though generic file inspection reports it as a PNG.
  Evidence: `strings -a tmp/rickrolled.png | rg 'acTL|fcTL|fdAT|IDAT'` returns APNG chunks, and `xxd -g 1 -l 256 tmp/rickrolled.png` shows `acTL` and `fcTL` chunk headers near the start of the file.

- Observation: the current renderer and harness do not yet expose the media contract that the brief expects.
  Evidence: `Swift Markdown Viewer/Swift Markdown Viewer/App/Shared/Models.swift` has no dedicated animated-image or video block kind, `SelectableDocumentFormatter` turns `.image` blocks into `"Image:"` / `"Source:"` text, and `AppModel.performanceSnapshot()` hard-codes both media counters to zero.

- Observation: the macOS UI-test environment currently fails before any new media assertion can run.
  Evidence: `/tmp/swift-markdown-viewer-inline-media-ui-check/Logs/Test/Test-Swift Markdown Viewer-2026.03.23_22-39-14--0700.xcresult` reports `Swift Markdown ViewerUITests-Runner ... Early unexpected exit ... Test crashed with signal kill before establishing connection`, and macOS surfaced the dialog that the runner app was "damaged" and should be moved to the Trash.

- Observation: the UITest runner provenance marker remains on the built macOS runner bundle even after direct `xattr -d` attempts.
  Evidence: `xattr -l /tmp/swift-markdown-viewer-inline-media-ui-bft/Build/Products/Debug/Swift Markdown ViewerUITests-Runner.app` still reports `com.apple.provenance` after explicit removal commands returned success.

- Observation: on macOS 26.3.1 / Xcode 26.3, the local UITest runner failure was caused by the unsigned runner bundle layout rather than by the provenance marker alone.
  Evidence: the unsigned `build-for-testing` bundle fails `codesign --verify --deep --strict` with missing sealed resources, while the default-signed bundle still carries `com.apple.provenance` but passes the same strict verification and boots XCTest successfully.

- Observation: `PWD` and `currentDirectoryPath` are not reliable ways for macOS UI tests to locate checked-in fixtures under `xcodebuild test`.
  Evidence: the debug accessibility dump for the pre-fix UI run showed the app title as `Fixtures/docs > No file selected`, and switching the UI tests to derive the repo root from `#filePath` allowed the APNG inline-media test to pass.

## Decision Log

- Decision: use the fixture names from the product brief verbatim: `animated_gif.md`, `animated_apng.md`, and `video_local_mp4.md`.
  Rationale: those names are already part of the repository’s durable product plan, so reusing them avoids duplicate fixture vocabulary and keeps future checkpoint naming predictable.

- Decision: lock video authoring to the brief’s custom `!video[]()` syntax instead of inventing a raw-HTML or link-based fallback.
  Rationale: the repo explicitly forbids HTML rendering, and the product brief already defines `!video[]()` as the supported local video syntax.

- Decision: make the first UI assertions prefix-based (`block.image.` / `block.video.` / `video.playButton.`) rather than hard-coding a block-id suffix.
  Rationale: the tests need to freeze the existence of the media accessibility surface without over-constraining the eventual block identifier algorithm before implementation starts.

- Decision: keep this slice red-first and stop before renderer changes.
  Rationale: the user explicitly asked for planning plus fixtures/tests without implementation, and the quickest safe way to honor that is to land failing coverage that documents the expected end state.

- Decision: preserve the selectable text view for text-only documents and switch to a block-rendered scroll view only when a document contains image or video blocks.
  Rationale: that keeps the cross-block text-selection behavior for ordinary documents while still allowing real inline media views and accessibility identifiers where the media feature needs them.

- Decision: keep macOS UI-test invocations signed on this machine instead of forcing `CODE_SIGNING_ALLOWED=NO`.
  Rationale: unsigned UI-test runners are rejected locally with a damaged-runner dialog and invalid sealed-resource signatures, while ad-hoc signed runners boot and exercise the real app.

- Decision: derive UI-test fixture roots from `#filePath` rather than `PWD`.
  Rationale: `xcodebuild test` does not provide a stable repo-root working directory, so compile-time source paths are the durable way to locate `Fixtures/docs` from macOS UI tests.

## Outcomes & Retrospective

The repository now has durable animated-media input files and red tests, but it still does not render those media blocks. That is the intended stopping point for this slice. The docs, fixtures, and test names now define the implementation target clearly enough that the next work loop can focus on classification, native media hosts, harness state, and accessibility without re-deciding syntax or fixture provenance.

The main lesson from planning is that most of the policy had already been written down in `codex_execplan_native_universal_gfm_viewer.md`; the missing pieces were the checked-in fixture assets and the tests that enforce that policy against the live app. The implementation slice should therefore reuse the brief directly instead of improvising a new media contract.

Validation split cleanly into three buckets. Docs validation is green. The new unit slice is red in the intended way, which confirms the tests are exercising the live block/snapshot contract rather than failing because of missing fixtures. The macOS UI slice is currently blocked by an earlier runner bootstrap crash, so future implementation work should re-run those UI assertions after the local UITest runner issue is cleared.

The implementation slice is now in place. The shared markdown layer parses local `!video[]()` blocks, the document loader upgrades GIF/APNG files to `animatedImage` blocks after resolving real workspace URLs, the harness perf snapshot counts visible animated and video media, and media-bearing documents render through real inline block views instead of the text-only formatter. The focused macOS unit/regression slice is green.

The local UITest blocker is now narrower. End-to-end UI execution is no longer blocked by the damaged-runner dialog as long as the runner is allowed to use Xcode's default ad-hoc signing. On this machine, the signed inline-media UI slice now reaches real assertions and passes for the APNG fixture. The remaining gaps are product-facing: the GIF and MP4 UI assertions still fail, and even the older macOS smoke UI test is still flaky in this environment, so broader macOS UI harness stabilization remains a separate task.

The product-facing inline-media gaps are now closed for the targeted feature slice. The macOS implementation no longer relies on SwiftUI's generic `Image` or `VideoPlayer` hosts for these assets. Instead it uses AppKit-backed `NSImageView` and `AVPlayerView`, which resolved the local symptom set where images failed to render and the MP4 play action crashed. The signed focused macOS inline-media UI suite is now green. The previously flaky macOS smoke UI test is also green again after restoring the hidden title's accessibility exposure.

## Context and Orientation

Relevant files for the follow-up implementation:

- `codex_execplan_native_universal_gfm_viewer.md`
- `Fixtures/docs/animated_gif.md`
- `Fixtures/docs/animated_apng.md`
- `Fixtures/docs/video_local_mp4.md`
- `Fixtures/media/rickrolled.gif`
- `Fixtures/media/rickrolled.png`
- `Fixtures/media/rickrolled.mp4`
- `Swift Markdown Viewer/Swift Markdown Viewer/App/Shared/Models.swift`
- `Swift Markdown Viewer/Swift Markdown Viewer/App/Shared/MarkdownRenderer.swift`
- `Swift Markdown Viewer/Swift Markdown Viewer/App/Shared/AppModel.swift`
- `Swift Markdown Viewer/Swift Markdown Viewer/App/Platform/SelectableDocumentTextView.swift`
- `Swift Markdown Viewer/Swift Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Swift Markdown Viewer/Swift Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Swift Markdown Viewer/Swift Markdown Viewer/Harness/HarnessSnapshots.swift`
- `Swift Markdown Viewer/Swift Markdown ViewerTests/InlineAnimatedMediaTests.swift`
- `Swift Markdown Viewer/Swift Markdown ViewerUITests/InlineAnimatedMediaUITests.swift`

## Plan of Work

### Milestone 1: seed durable fixtures and red coverage

Keep the copied `rickrolled` assets in `Fixtures/media/` and the three new markdown docs in `Fixtures/docs/` as the durable test corpus for this feature area. Preserve the current red tests so they continue to represent the target behavior during implementation.

### Milestone 2: extend parsing and shared media classification

Teach the shared markdown layer to distinguish static images from animated GIF/APNG media and to parse the custom `!video[]()` local-video syntax into a dedicated video block instead of plain text. The shared block model and harness-visible block kinds should distinguish `animatedImage` and `video` from ordinary paragraphs and static images.

### Milestone 3: add native inline media hosts

Render animated GIF/APNG blocks with native image/media APIs and render MP4 blocks with a native video host that is paused by default, shows a poster frame, and exposes a stable play button accessibility identifier. This work must stay platform-native and preserve the repo invariant against `WKWebView` or HTML media rendering.

### Milestone 4: wire harness state, perf counters, and checkpoint coverage

Update state snapshots, accessibility IDs, and perf snapshots so the harness can detect visible animated media and video blocks. Once the implementation works, add or refresh checkpoint captures and expected outputs for the animated-media fixtures on macOS and iOS surfaces.

## Concrete Steps

Run all commands from `/Users/matthewmoore/Projects/swift-markdown-viewer` unless stated otherwise.

1. Verify the seeded media fixtures are present and unchanged:

       shasum -a 256 Fixtures/media/rickrolled.gif Fixtures/media/rickrolled.mp4 Fixtures/media/rickrolled.png

   Expected result: the files exist in-repo and match the copied source assets.

2. Keep the new markdown fixtures aligned with the product brief syntax:

       sed -n '1,120p' Fixtures/docs/animated_gif.md
       sed -n '1,120p' Fixtures/docs/animated_apng.md
       sed -n '1,120p' Fixtures/docs/video_local_mp4.md

   Expected result: GIF/APNG use `![...]()` syntax and MP4 uses `!video[]()`.

3. Implement the shared parsing and classification changes, then run the targeted unit slice:

       xcodebuild -quiet -project "Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj" -scheme "Swift Markdown Viewer" -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-unit -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Swift Markdown ViewerTests/InlineAnimatedMediaTests" test

   Expected result: `InlineAnimatedMediaTests` pass with visible block kinds `animatedImage` for GIF/APNG and `video` for MP4.

4. Implement accessible inline media hosts, then run the targeted UI slice:

       xcodebuild -quiet -project "Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj" -scheme "Swift Markdown Viewer" -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-ui -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Swift Markdown ViewerUITests/InlineAnimatedMediaUITests" test

   Expected result: the app exposes at least one `block.image.<id>` element for GIF/APNG fixtures and both `block.video.<id>` and `video.playButton.<id>` for the MP4 fixture.

5. After the renderer implementation is in place, rerun the repo checks:

       python3 scripts/check_execplan.py
       python3 scripts/knowledge/check_docs.py

   Expected result: the active plan validates, docs checks stay green, and the media tests remain the governing contract for this workstream.

## Validation and Acceptance

This feature is acceptable only when the three new markdown fixtures render media inline in the real app instead of collapsing to textual placeholders. For GIF and APNG fixtures, the harness-visible block list must distinguish them as `animatedImage` blocks and the UI must expose stable `block.image.<id>` accessibility identifiers. For the MP4 fixture, the parser must recognize `!video[]()` syntax, the app must render a paused-by-default inline video block, and the UI must expose both `block.video.<id>` and `video.playButton.<id>`.

Until implementation lands, the new `InlineAnimatedMediaTests` and `InlineAnimatedMediaUITests` are expected to fail. That failing state is intentional and should only be removed by making the app satisfy the contract, not by weakening or deleting the tests.

## Idempotence and Recovery

Copying the `rickrolled` assets into `Fixtures/media/` is idempotent; re-copying them simply refreshes the same repo-owned files. If future implementation work needs to be deferred or reverted, keep the fixtures, tests, and plan in place so the repository retains the intended contract. Recovery from a bad implementation should revert the renderer changes while preserving these red tests as the feature backlog guardrail.

## Artifacts and Notes

Source asset hashes at plan creation time:

- `5a76766edeb159ed86bbe1522260010c2dce43ea166648aafc169212e174bc74  tmp/rickrolled.gif`
- `fb59dc18f5a6d6acfc8f777ca11ca91034a9eea1c830baf63b63ceab941dd086  tmp/rickrolled.mp4`
- `6b4686af5c825c3c3e49e149644737dd3dc8db8a9a08134a414d918f8d9e4246  tmp/rickrolled.png`

APNG confirmation commands:

- `strings -a tmp/rickrolled.png | rg 'acTL|fcTL|fdAT|IDAT'`
- `xxd -g 1 -l 256 tmp/rickrolled.png`

Validation commands run for this planning slice:

- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `xcodebuild -quiet -project "Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj" -scheme "Swift Markdown Viewer" -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-unit-check -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Swift Markdown ViewerTests/InlineAnimatedMediaTests" test`
- `xcodebuild -quiet -project "Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj" -scheme "Swift Markdown Viewer" -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-ui-check -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Swift Markdown ViewerUITests/InlineAnimatedMediaUITests" test`
- `xcrun xcresulttool get object --legacy --path '/tmp/swift-markdown-viewer-inline-media-ui-check/Logs/Test/Test-Swift Markdown Viewer-2026.03.23_22-39-14--0700.xcresult' --format json`
- `xcodebuild -quiet -project "Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj" -scheme "Swift Markdown Viewer" -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-ui-bft -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= build-for-testing`
- `xattr -d com.apple.provenance '/tmp/swift-markdown-viewer-inline-media-ui-bft/Build/Products/Debug/Swift Markdown ViewerUITests-Runner.app'`
- `xcodebuild -quiet -project "Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj" -scheme "Swift Markdown Viewer" -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-regression -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Swift Markdown ViewerTests/InlineAnimatedMediaTests" "-only-testing:Swift Markdown ViewerTests/Swift_Markdown_ViewerTests/testSelectableDocumentFormatterUsesRenderedDocumentText" "-only-testing:Swift Markdown ViewerTests/Swift_Markdown_ViewerTests/testMarkdownRendererParsesDirectImageFixture" "-only-testing:Swift Markdown ViewerTests/Swift_Markdown_ViewerTests/testMarkdownRendererParsesReferenceImageFixture" test`
- `sw_vers`
- `xcodebuild -version`
- `xattr -lr '/tmp/swift-markdown-viewer-inline-media-ui-bft/Build/Products/Debug/Swift Markdown ViewerUITests-Runner.app'`
- `codesign --verify --deep --strict --verbose=4 '/tmp/swift-markdown-viewer-inline-media-ui-bft/Build/Products/Debug/Swift Markdown ViewerUITests-Runner.app'`
- `spctl -a -vv '/tmp/swift-markdown-viewer-inline-media-ui-bft/Build/Products/Debug/Swift Markdown ViewerUITests-Runner.app'`
- `xcodebuild -quiet -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj' -scheme 'Swift Markdown Viewer' -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-ui-signed -destination 'platform=macOS,arch=arm64' "-only-testing:Swift Markdown ViewerUITests/InlineAnimatedMediaUITests" test`
- `xcodebuild -quiet -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj' -scheme 'Swift Markdown Viewer' -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-ui-signed-bft -destination 'platform=macOS,arch=arm64' build-for-testing`
- `codesign --verify --deep --strict --verbose=2 '/tmp/swift-markdown-viewer-inline-media-ui-signed-bft/Build/Products/Debug/Swift Markdown ViewerUITests-Runner.app'`
- `xcodebuild -quiet -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj' -scheme 'Swift Markdown Viewer' -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-unit-final2 -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Swift Markdown ViewerTests/InlineAnimatedMediaTests" test`
- `xcodebuild -quiet -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj' -scheme 'Swift Markdown Viewer' -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-ui-signed-fix4 -destination 'platform=macOS,arch=arm64' "-only-testing:Swift Markdown ViewerUITests/InlineAnimatedMediaUITests" test`
- `xcodebuild -quiet -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj' -scheme 'Swift Markdown Viewer' -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-ui-smoke-signed-fix2 -destination 'platform=macOS,arch=arm64' "-only-testing:Swift Markdown ViewerUITests/Swift_Markdown_ViewerUITests/testSmokeLaunchShowsHarnessShell" test`
- `swift - <<'SWIFT' ... NSImage(contentsOf:) probe for Fixtures/media/rickrolled.gif and Fixtures/media/rickrolled.png ... SWIFT`
- `swift - <<'SWIFT' ... AVURLAsset probe for Fixtures/media/rickrolled.mp4 ... SWIFT`
- `xcodebuild -quiet -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj' -scheme 'Swift Markdown Viewer' -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-unit-renderfix -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Swift Markdown ViewerTests/InlineAnimatedMediaTests" test`
- `xcodebuild -quiet -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj' -scheme 'Swift Markdown Viewer' -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-inline-media-ui-renderfix -destination 'platform=macOS,arch=arm64' "-only-testing:Swift Markdown ViewerUITests/InlineAnimatedMediaUITests" test`
- `xcodebuild -quiet -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj' -scheme 'Swift Markdown Viewer' -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-ui-smoke-after-media-fix -destination 'platform=macOS,arch=arm64' "-only-testing:Swift Markdown ViewerUITests/Swift_Markdown_ViewerUITests/testSmokeLaunchShowsHarnessShell" test`
- `xcodebuild -quiet -project 'Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj' -scheme 'Swift Markdown Viewer' -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-ui-smoke-titlefix -destination 'platform=macOS,arch=arm64' "-only-testing:Swift Markdown ViewerUITests/Swift_Markdown_ViewerUITests/testSmokeLaunchShowsHarnessShell" test`

## Interfaces and Dependencies

The parser contract is already defined by the product brief:

- animated GIF/APNG fixtures use standard Markdown image syntax
- local MP4 uses custom `!video[]()` syntax
- remote video remains unsupported

Follow-up implementation will need to coordinate:

- shared markdown parsing and block modeling in `App/Shared/`
- relative media-path resolution through `WorkspaceProvider`
- harness-visible state kinds and accessibility identifiers in `Harness/`
- native media playback/image animation hosts on macOS and iOS/iPadOS
