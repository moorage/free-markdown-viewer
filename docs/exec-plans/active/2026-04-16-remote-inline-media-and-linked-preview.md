# Remote Inline Media And Linked Preview

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

After this workstream is complete, Quick Markdown Viewer should render both local and remote media inline inside the document flow, while keeping failures visible inside the document instead of surfacing modal alerts. Standard Markdown image blocks should support `https://` image URLs in addition to existing local workspace media, and the custom `!video[]()` syntax should support direct remote video URLs as well as local files. If a remote image or video cannot be loaded, the existing inline block card should show a clear error message in place of the media instead of leaving the user with a silent empty state or a dialog.

This workstream also adds in-app previewing for linked media targets. When the user activates a direct image or video link, the app should keep the user in context and present a native preview surface rather than immediately leaving the app. The preview should use the native transient presentation that fits each platform: popover on macOS and regular-width iPad, sheet on compact iPhone. That preview must expose a native dismiss path, support Escape or cancel-action dismissal on keyboard platforms, and provide an explicit external-open action so the original target can still be handed off to the system browser or external handler when the user wants it.

The scope intentionally excludes arbitrary web pages, HTML embeds, or browser-style rich previews. The repository invariant against `WKWebView`, HTML rendering, and JavaScript remains intact. This slice is only for direct image and video resources referenced from Markdown.

## Progress

- [x] (2026-04-16T22:03Z) Confirmed the current local-only implementation surface: `WorkspaceProvider.resolveMediaURL(for:)` resolves only workspace-relative local paths, `AppModel.hydrateMedia` always routes image/video sources through that local resolver, `MarkdownRenderer.videoBlock(from:)` rejects any URL containing `://`, and `ViewerShellView.handleDocumentLink(_:)` forwards every non-Markdown link straight to `openURL`.
- [x] (2026-04-16T22:03Z) Confirmed that inline media already has a non-dialog error surface that can be extended for remote failures: `ImageBlockView` and `InlineVideoBlockView` render readable inline error text inside the block card when local media is missing or unreadable.
- [x] (2026-04-16T22:03Z) Identified the macOS platform constraint that makes remote media a real product change, not just a renderer tweak: the sandboxed macOS target currently lacks `com.apple.security.network.client`, and the checked-in App Review notes still describe the shipped app as a local-only file viewer.
- [x] (2026-04-16T22:03Z) Drafted the implementation and validation plan below, including the requirement that automated coverage use deterministic loopback-hosted fixtures instead of depending on the public internet.
- [x] (2026-04-16T22:03Z) Ran `python3 scripts/check_execplan.py docs/exec-plans/active/2026-04-16-remote-inline-media-and-linked-preview.md` and `python3 scripts/knowledge/check_docs.py`; both passed after registering the new active workstream.
- [x] (2026-04-16T22:42Z) Implemented the shared local-vs-remote media model, remote inline hydration, inline remote failure messages, and linked-media interception so direct image/video links now open an in-app preview instead of always leaving the app.
- [x] (2026-04-16T22:42Z) Added deterministic remote-media unit coverage with a loopback fixture server, plus focused macOS UI coverage for linked local image/video preview controls, Escape dismissal, and the external-open affordance.
- [x] (2026-04-16T22:42Z) Updated the macOS entitlement set and the harness/release/security docs so the shipped remote-media behavior, App Review story, and automation contracts stay aligned.

## Surprises & Discoveries

- Observation: remote images already parse successfully today, but they still fail at runtime because hydration assumes every media source is a workspace-relative file path.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift` accepts any `sourceURL` in `directImage(from:)`, while `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift` always calls `provider.resolveMediaURL(for: WorkspacePath(rawValue: image.sourceURL))`.

- Observation: remote videos are blocked one layer earlier than remote images.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift` currently returns `nil` from `videoBlock(from:)` unless `isLocalMediaReference(_:)` says the URL is local.

- Observation: the app already has a single routing choke point for link activation across both structured block rendering and the selectable text view.
  Evidence: `ViewerShellView.handleDocumentLink(_:)` is injected into both `DocumentBlockScrollView` via `openURL` and `SelectableDocumentTextView` via `onOpenLink`, so media-link preview interception can happen in one place.

- Observation: the repository currently has no general networking layer or loopback fixture-server helper.
  Evidence: `rg -n "URLSession|URLProtocol|localhost|127\\.0\\.0\\.1" "Quick Markdown Viewer" docs Fixtures scripts` only found AVFoundation media loading and no existing remote-media harness support.

- Observation: repo security and release docs still assume the shipped product has no networked behavior in the app path.
  Evidence: `docs/SECURITY.md` says "no network dependency in the core harness loop", and `docs/release/app-store-submission.md` still describes the app as having "no analytics or network service requirement in the shipped code path."

- Observation: the signed macOS UI test runner cannot host the same loopback helper that works in unit tests.
  Evidence: `/usr/bin/python3` resolves through a sandbox-blocked `xcrun` shim under UI testing, and an in-process `NWListener` also failed with `Operation not permitted`, so remote-web UI coverage had to stay in unit tests while UI automation covered local linked preview behavior.

## Decision Log

- Decision: shipped remote-media support is `https://` only, with `http://127.0.0.1` / `http://localhost` reserved for harness and debug fixtures.
  Rationale: that keeps the user-facing feature aligned with App Transport Security and avoids teaching the app to fetch arbitrary insecure media from the open web, while still leaving a practical path for deterministic UI tests.

- Decision: media-link preview interception is limited to direct image/video targets that can be classified from the target URL path or known local file extension.
  Rationale: the user asked for linked images and videos, not generic web-page previews. Restricting interception to direct media keeps non-media links on the current Markdown-navigation/browser path and avoids speculative network probing on every click.

- Decision: introduce a shared media-source abstraction instead of overloading the current `resolvedURL` field with both local and remote semantics.
  Rationale: the current model only represents "local file URL or nil." Remote support needs to retain the original URL for browser handoff and failure messaging while also carrying a presentation URL or load state that may differ from the author-supplied source.

- Decision: remote images should be materialized into an app-owned cache file before display, while remote videos can stream directly through `AVURLAsset` / `AVPlayer`.
  Rationale: the current animated-image surfaces are file-URL based and already work for GIF/APNG files. Reusing that path for remote images is smaller and safer than rewriting image rendering around in-memory animated decoding. Video playback already has a native streaming path.

- Decision: linked-media preview uses a shared native presentation state, but macOS now uses a window-attached sheet while iPhone also uses sheets and regular-width iPad keeps popovers.
  Rationale: the original popover plan was viable conceptually, but the root-level SwiftUI popover path proved brittle in practice and under automation. A macOS sheet still satisfies the "native preview surface" requirement while keeping close/Escape behavior reliable.

- Decision: preview failures should render inside the preview body, not as alerts, and inline block failures should keep using block-local text.
  Rationale: the user explicitly asked for inline error reporting, and the existing media cards already establish that UX pattern.

- Decision: the preview footer exposes an external-open action routed through the original target URL. Remote URLs use an `Open in Browser` label; local file URLs use an external-open label that follows platform conventions if browser-only handoff is not supported.
  Rationale: forcing every local file through a browser is platform-inconsistent and unreliable under sandboxing. The plan preserves the user's "open it externally" intent while keeping the implementation honest.

- Decision: deterministic remote-web coverage lives in unit tests, while macOS UI tests validate linked-preview interaction using local fixture URLs.
  Rationale: this preserves coverage for both halves of the feature without depending on public internet access or sandbox-exempt helper processes during UI automation.

## Outcomes & Retrospective

This plan is implemented. The app now distinguishes local and remote media sources in the shared model, renders direct `https://` image and video URLs inline, shows remote failures inside the inline block card instead of alerting, and intercepts direct image/video links into an in-app preview surface rather than always handing them to `openURL`.

The most important implementation risk ended up being sandboxed testability, not rendering. The shipped macOS app needed `com.apple.security.network.client`, remote image caching, and new link-routing logic, but the bigger surprise was that the signed macOS UI runner could not host the deterministic loopback helper. The final validation split is intentional: remote fetch behavior is covered in unit tests with loopback-served fixture bytes, while UI tests prove close/Escape/open-in-browser behavior with local linked media.

The resulting feature stayed inside scope. There is still no `WKWebView`, no generic web-page preview, and no probing of arbitrary links. Only direct image/video resources are fetched, relative Markdown links still navigate internally, and every other non-media link continues to open externally.

## Context and Orientation

The current code already contains most of the renderer pieces that this work needs to extend:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift`
  - shared block kinds and the current `MarkdownImage` / `MarkdownVideo` value types
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift`
  - Markdown image parsing and the current local-only `!video[]()` parser gate
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift`
  - workspace-relative file loading and local media URL resolution
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
  - media hydration, block-content switching, and visible-state snapshots
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
  - inline image/video block rendering, error messages, and document-link routing
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/SelectableDocumentTextView.swift`
  - the selectable text surface that also routes link clicks back through `ViewerShellView`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
  - current media accessibility IDs and the likely place for preview-control identifiers
- `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_Viewer.entitlements`
  - current sandbox entitlements; remote media will require macOS network client access
- `Quick Markdown Viewer/Quick Markdown ViewerTests/InlineAnimatedMediaTests.swift`
  - current local inline-media state coverage
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/InlineAnimatedMediaUITests.swift`
  - current accessible inline-media UI coverage
- `docs/debug-contracts.md`
  - harness-visible accessibility and snapshot contracts that need updating once preview IDs are introduced
- `docs/SECURITY.md`
  - the repo security posture that must keep the harness free from public-network dependency
- `docs/release/app-review-notes.md`
  - the App Review explanation that will need to mention network access for user-authored remote media on macOS

The current renderer has three concrete gaps this plan must close:

1. local-only hydration:
   `AppModel.hydrateMedia` can only turn workspace-relative media references into usable URLs.

2. local-only video parsing:
   `MarkdownRenderer.videoBlock(from:)` intentionally refuses remote URLs today.

3. no in-app preview for linked media:
   `ViewerShellView.handleDocumentLink(_:)` only distinguishes Markdown document links from everything else.

## Plan of Work

### Milestone 1: extend the shared media model and sandbox surface

Introduce a shared representation that can describe both local and remote media without losing the original author-supplied URL. The implementation should preserve the current block kinds (`image`, `animatedImage`, `video`) but allow each image/video payload to carry:

- original source string
- source kind (`localWorkspaceRelative`, `remoteHTTPS`, possibly `unsupported`)
- presentation URL or load token
- cached local file URL for remote animated images when needed

In the same milestone, update the macOS entitlement surface to add `com.apple.security.network.client` and prepare the release/review docs that justify it only for user-authored remote media references. This milestone should not change user-facing rendering yet; it just removes the type and entitlement blockers.

### Milestone 2: add remote inline image and video loading with inline failure states

Teach hydration and rendering to support remote media:

- standard Markdown images should accept `https://...` sources and hydrate them into a remote-media load state rather than forcing workspace resolution
- `!video[]()` should accept `https://...` sources in addition to local ones
- remote animated images should download into an app-owned cache file so the existing native GIF/APNG surfaces can keep working
- remote videos should stream through native AVFoundation

All failures must stay in the existing inline block-card UX:

- network error
- 404 / missing resource
- ATS rejection / insecure URL
- unsupported type / decode failure
- sandboxed local-file escape

No alert panels or modal error sheets should be introduced for these failures.

### Milestone 3: intercept direct media links and present a native preview surface

Add a shared media-link classifier and preview state so `ViewerShellView.handleDocumentLink(_:)` can choose among three outcomes:

1. internal Markdown navigation for `.md` links
2. in-app preview for direct local or remote media links
3. current `openURL` behavior for every other link

The preview should render native media, not a browser view:

- macOS and regular-width iPad: popover anchored to the current viewer surface
- compact iPhone: sheet presentation
- image preview: native image surface using the same local-or-cached representation as inline media
- video preview: native AVPlayer host

The preview must expose:

- dismiss control visible in the preview chrome/body
- Escape or cancel-action dismissal on keyboard platforms
- external-open button routed through the original target URL
- inline error text inside the preview body if the preview target cannot be loaded

### Milestone 4: add deterministic fixtures, harness contracts, and regression coverage

The repo cannot depend on the public internet for automated coverage. Add deterministic remote-media coverage using a test-only loopback fixture server or equivalent helper that serves existing repo-owned bytes from `Fixtures/media/`. Use that helper to cover:

- remote image success
- remote video success
- remote image failure (404 or decode failure)
- linked local image preview
- linked remote video preview
- preview dismissal via close and Escape/cancel
- external-open action visibility

Update harness contracts and accessibility IDs so UI automation can prove the preview exists and closes correctly without using image-diff guesswork.

## Concrete Steps

Run all commands from `/Users/matthewmoore/Projects/free-markdown-viewer` unless stated otherwise.

1. Add the shared media-source model and parser support, then run the targeted unit slice:

       xcodebuild -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-remote-media-unit -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/InlineAnimatedMediaTests" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests" test

   Expected result: local inline-media tests stay green, new remote image/video parsing tests pass, and relative Markdown link navigation remains intact.

2. Add remote inline image/video loading plus inline failure rendering, then rerun the same targeted unit slice:

       xcodebuild -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-remote-media-unit-2 -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/InlineAnimatedMediaTests" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests" test

   Expected result: the new remote image/video success and failure assertions pass without introducing any alert-driven error path.

3. Implement linked-media preview interception and native preview presentation, then run focused macOS UI coverage:

       xcodebuild -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-remote-media-ui-macos -destination "platform=macOS,arch=arm64" "-only-testing:Quick Markdown ViewerUITests/InlineAnimatedMediaUITests" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests" test

   Expected result: linked media opens an in-app preview, the preview can be dismissed with the visible close control and Escape/cancel, and direct non-media links still follow the existing navigation/browser behavior.

4. Run iPhone and iPad smoke coverage after the preview container is wired for compact and regular layouts:

       ./scripts/test-ui-ios --device both --smoke

   Expected result: the new preview path does not break launch or navigation on compact and regular iOS surfaces.

5. Rebuild and run the repo-level validation loop once the feature and docs are complete:

       ./scripts/test-unit
       ./scripts/test-ui-macos --smoke
       python3 scripts/check_execplan.py docs/exec-plans/active/2026-04-16-remote-inline-media-and-linked-preview.md
       python3 scripts/knowledge/check_docs.py

   Expected result: unit tests pass, smoke UI coverage stays green, and the updated control-plane docs validate cleanly.

## Validation and Acceptance

This feature is acceptable only when all of the following are true:

- `![alt](https://...)` image blocks render inline using native image surfaces instead of degrading to unresolved-path text.
- `!video[alt](https://...)` remote video blocks render inline using native AVFoundation hosts.
- any remote inline-media failure renders readable inline error text inside the block card; no modal alert or dialog is shown.
- `[label](relative-image-or-video)` and `[label](https://direct-media-url)` open an in-app preview surface instead of immediately leaving the app.
- the preview exposes a dismiss control, keyboard cancel/Escape dismissal where the platform supports it, and an external-open action.
- non-media links keep the current behavior: relative Markdown links navigate internally; everything else still opens externally.
- the new behavior is covered without public-network dependency, using deterministic loopback-hosted bytes or equivalent local fixtures.
- macOS release notes and entitlement documentation explain the new network-client scope in the same change that adds the entitlement.

## Idempotence and Recovery

The shared-model and preview-state changes are code-only and safe to reapply. Remote image caches should live under app-managed cache or temp directories and be safe to clear between runs. The loopback fixture server should serve existing checked-in media bytes so it can be started and stopped repeatedly without mutating repo-owned artifacts.

If the implementation must be rolled back, revert the remote-media hydration and preview interception together while keeping the new tests and plan if possible. The preferred degraded behavior is the current one: direct non-Markdown links still open externally, and unsupported remote media shows inline failure text rather than crashing or hanging the UI.

## Artifacts and Notes

Planning commands run for this ExecPlan:

- `sed -n '1,220p' README.md`
- `sed -n '1,220p' ARCHITECTURE.md`
- `sed -n '1,220p' .agents/PLANS.md`
- `sed -n '1,220p' docs/harness.md`
- `sed -n '1,220p' docs/debug-contracts.md`
- `sed -n '1,260p' docs/exec-plans/active/2026-03-23-inline-animated-media.md`
- `rg -n "animatedImage|video|openURL|popover|sheet|URLSession|URLProtocol" "Quick Markdown Viewer"`
- `date -u +"%Y-%m-%dT%H:%MZ"`

Files and docs that the implementation slice is expected to touch:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/SelectableDocumentTextView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_Viewer.entitlements`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/InlineAnimatedMediaTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/InlineAnimatedMediaUITests.swift`
- `docs/debug-contracts.md`
- `docs/SECURITY.md`
- `docs/release/app-review-notes.md`
- `docs/release/app-store-submission.md`

## Interfaces and Dependencies

Shared-code additions will likely need:

- a new shared media-source or media-load-state type in `App/Shared/Models.swift`
- a small remote-media loader/cache helper that can use `URLSession` for images without leaking AppKit/UIKit into shared code
- preview-state plumbing in `ViewerShellView` that works for both structured block rendering and `SelectableDocumentTextView` link callbacks

Platform and framework dependencies:

- `URLSession` for remote image download
- `ImageIO` plus existing native image surfaces for animated-image classification and rendering
- `AVFoundation` / `AVKit` for local and remote video preview/playback
- SwiftUI `popover`, `sheet`, and `openURL`
- macOS sandbox entitlement `com.apple.security.network.client`

Harness and contract dependencies:

- new preview accessibility IDs such as container, dismiss button, and external-open button
- deterministic loopback media serving for UI tests
- retained existing `block.image.<id>`, `block.video.<id>`, and `video.playButton.<id>` contracts

The implementation must preserve repo invariants:

- no `WKWebView`
- no HTML/CSS/JavaScript renderer
- no public-network dependency in the harness loop
- AppKit only in macOS adapters
- UIKit only in iOS/iPadOS adapters
