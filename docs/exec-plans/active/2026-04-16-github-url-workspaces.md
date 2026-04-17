# GitHub URL Workspaces

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Add a second workspace-opening path that accepts public GitHub repository URLs in addition to local folders. A user should be able to paste a GitHub URL into the empty home screen and tap `Load`, or invoke the same flow from the normal app chrome, and then browse the resolved repository subtree exactly like a local workspace on macOS, iPhone, and iPad.

The supported URL surface for this milestone is repository and tree URLs on `https://github.com/`:

- `https://github.com/moorage/free-markdown-viewer`
- `https://github.com/moorage/free-markdown-viewer/`
- `https://github.com/moorage/free-markdown-viewer/tree/main`
- `https://github.com/moorage/cxhere/tree/0.1.1`
- `https://github.com/<owner>/<repo>/tree/<ref>/<subdirectory>`

Root repo URLs should resolve to the repository's default branch. Tree URLs should resolve the requested branch or tag and open the directory underneath that ref as the workspace root. The loaded content must behave like a local workspace after fetch: sidebar listing, Markdown navigation, relative media resolution, and session restore should all use the same product semantics the app already has for on-disk folders. The fetched snapshot should also be cached locally so repeated opens are fast and previously opened URLs can still reopen when the network is unavailable.

This milestone is explicitly for public GitHub repositories only. Private repositories, GitHub Enterprise hosts, auth flows, generic web URLs, and arbitrary Git browser features are out of scope.

## Progress

- [x] (2026-04-17T00:27Z) Confirmed the current architecture seam: `WorkspaceProvider` exists as a protocol, but `AppModel` still stores `LocalWorkspaceProvider` concretely and bootstrap/session flows only know how to open local folders.
- [x] (2026-04-17T00:27Z) Confirmed the existing UX anchor for the new entry point: the no-workspace empty state already renders a centered card with primary actions, and the shared shell already has local-folder actions on macOS and iOS that can gain a parallel `Open GitHub URL` path.
- [x] (2026-04-17T00:27Z) Confirmed the repository already allows user-initiated `https` networking in shipped code via `com.apple.security.network.client`, so this feature can reuse the existing remote-network permission surface instead of adding a new entitlement.
- [x] (2026-04-17T00:27Z) Drafted the implementation plan below around a cached local mirror of a resolved GitHub snapshot so the existing local-workspace renderer, relative-link routing, and media loading paths can be reused with the smallest product-level behavior change.
- [x] (2026-04-17T02:30Z) Implemented `GitHubWorkspaceService`, cache-backed GitHub workspace providers, and session-source persistence so repo-root plus `tree/<ref>/<subdir>` URLs open as local-feeling cached workspaces.
- [x] (2026-04-17T02:30Z) Added the shared GitHub URL entry flow on the empty state, in normal app chrome, and in the macOS command menu, including inline validation, loading state, and restore-safe reopen behavior.
- [x] (2026-04-17T02:30Z) Added deterministic fixture-backed unit coverage for default-branch resolution, branch or tag trees, offline cache reopen, and restored GitHub sessions; documented the new harness switch plus the broader network story.
- [ ] (2026-04-17T02:30Z) macOS UI automation still needs a clean green run for the new empty-state GitHub flow because the focused UI runner crashed before establishing its XCTest connection in this CLI environment.

## Surprises & Discoveries

- Observation: the app is closer to a provider abstraction than the current behavior suggests, but the last concrete mile is still local-only.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift` defines a protocol, yet `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift` stores `private var workspaceProvider: LocalWorkspaceProvider?` and constructs `LocalWorkspaceProvider(rootURL: ...)` directly inside `loadWorkspace`.

- Observation: a cached local mirror is the lowest-risk way to make GitHub content behave "as if local" without reimplementing relative Markdown and media handling.
  Evidence: relative Markdown navigation in `AppModel.resolveMarkdownLinkTarget(_:)` and local/remote media hydration in `AppModel.hydrateMedia(...)` already assume a workspace root plus ordinary file URLs; the current remote-media feature only needs special handling when content is not on disk.

- Observation: the empty-state UX already distinguishes "no workspace chosen" from "workspace chosen but empty," which gives the GitHub URL loader a natural home without disturbing the existing empty-folder behavior.
  Evidence: `ViewerShellView.openFolderPromptState` and `ViewerShellView.emptyWorkspaceState` are already separate card states, backed by `AppModel.shouldShowOpenFolderPromptState` and `AppModel.shouldShowEmptyWorkspaceState`.

- Observation: session restore and window scoping are still modeled around local filesystem roots, so GitHub URLs need an explicit session-source expansion rather than a hidden cache-path hack.
  Evidence: `WorkspaceWindowSession` only persists `rootPath`, `selectedFile`, and optional bookmark data, and `WorkspaceWindowSessionStore` schedules new windows by local `rootURL`.

- Observation: product and release docs currently describe network use only in terms of direct media URLs embedded inside Markdown, so GitHub workspace loading is a user-visible network-scope change that must be documented in the same milestone.
  Evidence: `docs/SECURITY.md` and `docs/release/app-review-notes.md` both describe `com.apple.security.network.client` as supporting direct media fetching only.

- Observation: deterministic GitHub tests must not share the app's real cache root because repo-root URLs collide with any previously fetched live snapshots for the same canonical URL.
  Evidence: the first focused unit run reopened `~/Library/Caches/GitHubWorkspaces/moorage--free-markdown-viewer/<real-sha>` instead of the fixture's synthetic `sha-main` snapshot until the tests were moved onto per-test temporary cache directories.

- Observation: the focused macOS UI test currently crashes in the runner bootstrap path before the test process establishes its XCTest connection, so it does not yet prove the GitHub empty-state flow end to end in this environment.
  Evidence: `xcodebuild -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-github-compilecheck -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= COMPILER_INDEX_STORE_ENABLE=NO "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testEmptyStateLoadsGitHubWorkspaceFromURL" test` failed with `Early unexpected exit, operation never finished bootstrapping`.

## Decision Log

- Decision: materialize GitHub workspaces into an app-owned local cache and then open the cached subtree through the existing local-workspace path instead of teaching every renderer and navigation surface to operate against a live remote filesystem.
  Rationale: the user explicitly wants GitHub content to behave like a local directory tree. A cache-backed local mirror preserves current relative Markdown navigation, media resolution, and sidebar behavior with less surface-area risk than a fully remote provider threaded through the renderer.

- Decision: resolve GitHub URLs through GitHub metadata plus an immutable snapshot identifier, then key cache storage by resolved commit SHA while preserving the user-authored ref for display and repeat opens.
  Rationale: branches move, tags usually do not, and repo-root URLs depend on the default branch. The app needs a stable on-disk cache key, while the UI still needs to show the branch/tag name the user entered.

- Decision: populate the local mirror from a GitHub snapshot archive for the resolved commit SHA instead of fetching every workspace file individually from `raw.githubusercontent.com`.
  Rationale: the feature goal is a local-feeling cached subtree, not a sparse live remote filesystem. An archive-based snapshot keeps relative links and media coherent, reduces one-request-per-file overhead, and makes cache identity match the immutable commit SHA directly.

- Decision: support only public `github.com` repository and tree URLs in this milestone, with explicit inline validation errors for unsupported hosts, unsupported URL shapes, or non-directory subtree targets.
  Rationale: this keeps the first implementation product-safe and App-Review-friendly. Authentication, private repos, Enterprise hosts, and arbitrary GitHub URL types would each require materially more UI, persistence, and error-state design.

- Decision: reuse the existing network entitlement and document the broadened network purpose instead of adding more sandbox scope.
  Rationale: the app already ships with `com.apple.security.network.client`. GitHub loading is a broader use of the same user-initiated outbound network surface, not a reason to request new filesystem or automation entitlements.

- Decision: treat the GitHub loader as a shared workspace-opening controller that is exposed inline on the empty state and through standard app chrome, rather than as an empty-state-only affordance.
  Rationale: the empty home screen requirement is mandatory, but users also need a way to open another GitHub URL after a workspace is already open without forcing a relaunch or hidden debug path.

## Outcomes & Retrospective

Implemented, with one remaining validation gap on the macOS UI runner.

GitHub repository and tree URLs now open as first-class workspaces through a cache-backed local mirror keyed by resolved commit SHA. The app parses repo-root URLs and `tree/<ref>/<subdirectory>` URLs, resolves default branches plus branch or tag refs, materializes Markdown content under the app cache, and then reuses the existing local-workspace rendering and navigation paths for sidebar listing, Markdown file opens, relative links, relative media, and session restore.

The UI work landed on both required entry surfaces: the empty home screen now accepts a GitHub URL plus `Load`, and the shared shell exposes the same action after launch, including a macOS `Open GitHub URL…` command. Harness and release docs now cover the fixture-backed test switch, new accessibility identifiers, and the broader `network.client` explanation for GitHub loading.

Focused unit coverage is green for default-branch resolution, branch or tag parsing, offline cache reopen, and restored GitHub sessions. The remaining gap is macOS UI automation for the empty-state GitHub flow; the runner crashed before XCTest finished bootstrapping in this environment, so that piece still needs a clean rerun outside this CLI failure mode.

## Context and Orientation

Relevant existing code and docs:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceWindowSessionStore.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/HarnessLaunchOptions.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`
- `docs/debug-contracts.md`
- `docs/harness.md`
- `docs/SECURITY.md`
- `docs/release/app-review-notes.md`

New code is likely to live under a dedicated shared folder such as `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/GitHubWorkspace/` so parsing, remote resolution, cache management, and test fixtures stay discoverable and do not bloat `AppModel.swift`.

## Plan of Work

1. Add a GitHub workspace descriptor layer that can parse supported GitHub URLs, normalize trailing slashes, resolve repo-root URLs to the default branch, and split `tree/<ref>/<path>` URLs into the intended ref plus subtree path.
2. Introduce a GitHub snapshot cache that resolves the requested ref to a concrete commit SHA, downloads or reuses a cached snapshot, and exposes the resolved subtree as a local directory root.
3. Expand app state and session persistence so a window can own either a local folder workspace or a GitHub workspace without regressing current window-scoped behavior.
4. Add a shared GitHub URL loading UI for the empty state and normal app chrome, including inline validation, loading, and non-modal failure states on macOS and iOS.
5. Add deterministic tests and docs updates covering GitHub URL parsing, branch/tag resolution, cache reuse, session restore, empty-state loading, and the updated network/App Review story.

## Concrete Steps

Run all commands from `/Users/matthewmoore/Projects/free-markdown-viewer` unless stated otherwise.

1. Introduce a shared workspace-source model and GitHub URL parser.

   - Add a `WorkspaceSource` or equivalent discriminated type that can represent `localFolder` and `githubRepository`.
   - Add a `GitHubWorkspaceDescriptor` that stores `owner`, `repo`, `requestedRef`, `resolvedCommitSHA`, `subdirectory`, and a stable display string.
   - Support:
     - repo root URLs with or without a trailing slash
     - `tree/<ref>`
     - `tree/<ref>/<subdirectory>`
   - Reject:
     - non-`github.com` hosts
     - unsupported paths such as issues, pulls, commits, releases, or gists
     - malformed repo URLs

2. Resolve refs in a way that handles both branches and tags.

   - For repo-root URLs, fetch repository metadata to determine `default_branch`.
   - For tree URLs, resolve the longest valid ref prefix so names like `main`, `0.1.1`, and slash-containing branch names can still map cleanly to a subtree path.
   - Persist both the user-authored ref token and the resolved immutable commit SHA so display and cache identity do not drift apart.
   - Surface clear inline errors when the ref or subtree does not exist.

3. Materialize a cache-backed local mirror for the resolved GitHub snapshot.

   - Add a `GitHubWorkspaceCache` under the app cache directory, keyed by `owner/repo/commitSHA`, plus a lightweight alias index from requested URL to the last successful resolved snapshot.
   - Download the resolved snapshot archive for the commit SHA into the cache, extract it into an app-owned mirror directory, and expose the requested subtree as a local directory root.
   - Reuse the existing local-workspace file enumeration, local Markdown reading, relative Markdown link routing, and relative media resolution against that cached root.
   - If the network is unavailable but an exact or last-successful cached snapshot exists for the requested URL, reopen the cached snapshot and show that it is using cached content rather than failing silently.
   - Add cache eviction rules so old GitHub snapshots do not grow without bound on iPhone or iPad.

4. Thread the new workspace source through `AppModel` and session restore.

   - Stop storing `LocalWorkspaceProvider` concretely in `AppModel`; store either a protocol-erased provider or a higher-level workspace handle that can wrap a cached GitHub mirror.
   - Extend `WorkspaceWindowSession` so it can persist a remote GitHub descriptor instead of only a local filesystem root path.
   - Keep current per-window behavior intact on macOS and restore GitHub-backed windows on relaunch by reopening from cache first, then refreshing as needed for mutable refs.
   - Preserve the current empty-folder behavior for GitHub subdirectories that contain no Markdown files.

5. Add the user-facing GitHub URL loading surfaces.

   - Extend the no-workspace empty-state card with:
     - a GitHub URL text field
     - a `Load` button
     - Return-key submit
     - inline validation and fetch-error text
     - a loading spinner or disabled state while resolution or download is in flight
   - Add a parallel `Open GitHub URL…` affordance in normal app chrome so a second remote workspace can be opened after startup.
   - Keep `Open Folder` and the macOS `Install qmv` affordances intact; the GitHub loader is additive, not a replacement.

6. Add deterministic automated coverage without depending on the public internet.

   - Add repo-owned GitHub fixture responses and snapshot archives under `Fixtures/` or a dedicated test-fixture folder.
   - Route tests through an injectable GitHub client or test transport so unit and UI tests can resolve fake branches, tags, and subtree URLs without hitting the real GitHub network.
   - Cover:
     - repo-root URL default-branch resolution
     - trailing-slash normalization
     - branch URL parsing
     - tag URL parsing
     - subtree URL parsing
     - invalid or unsupported URL errors
     - cached reopen when offline
     - empty-state field plus `Load` button on macOS and iOS
     - restored GitHub sessions reopening the cached subtree

7. Update docs and release or security narratives in the same change.

   - Add new launch or test knobs to `docs/debug-contracts.md` and `docs/harness.md` if the tests need GitHub fixture transport or direct remote-workspace launch support.
   - Update `docs/SECURITY.md` to describe user-initiated GitHub repository fetching and cache behavior.
   - Update `docs/release/app-review-notes.md` so the network entitlement story includes GitHub repository loading in addition to direct media fetching.
   - Update `.agents/DOCUMENTATION.md` and keep this ExecPlan current as implementation decisions land.

## Validation and Acceptance

Acceptance requires all of the following:

- Pasting `https://github.com/moorage/free-markdown-viewer` or `https://github.com/moorage/free-markdown-viewer/` opens the repo root on its default branch.
- Pasting `https://github.com/moorage/free-markdown-viewer/tree/main` opens the repo root pinned to `main`.
- Pasting `https://github.com/moorage/cxhere/tree/0.1.1` opens the repo root pinned to tag `0.1.1`.
- Pasting a `tree/<ref>/<subdirectory>` URL opens that subdirectory as the workspace root instead of the full repository root.
- The opened GitHub content behaves like a local workspace: sidebar entries populate, Markdown files open, relative Markdown links navigate, and relative media references resolve through the cached snapshot.
- Reopening a previously fetched GitHub URL reuses cached data, and reopening while offline still works when a cached snapshot already exists.
- Invalid or unsupported GitHub URLs show explicit inline validation or fetch errors; the app does not silently no-op, crash, or replace the current workspace with a half-loaded state.
- macOS and iOS both expose the GitHub URL entry flow, and focused UI coverage proves the empty-state load path on both platform families.
- Existing local-folder open flows, session restore for local workspaces, and current remote inline-media behavior remain intact.
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-04-16-github-url-workspaces.md` passes.
- `python3 scripts/knowledge/check_docs.py` passes after the related docs updates.

## Idempotence and Recovery

The cache-backed design should be safe to rerun because GitHub snapshots are stored under app-owned cache directories and keyed by immutable commit SHA. Reopening the same URL should either reuse the existing cached snapshot or replace it atomically with a newer one for mutable refs like the default branch or a named branch.

If implementation work regresses local workspace behavior, the smallest rollback is to disable the new GitHub URL entry points and session-source branch while leaving the local-folder path untouched. If cached GitHub data becomes corrupt, recovery is to clear the corresponding app cache entry and refetch. No user-authored local files should ever be mutated as part of GitHub workspace loading.

## Artifacts and Notes

Planning commands run for this ExecPlan:

- `sed -n '1,220p' README.md`
- `sed -n '1,260p' ARCHITECTURE.md`
- `sed -n '1,260p' .agents/PLANS.md`
- `sed -n '1,260p' docs/PLANS.md`
- `sed -n '1,260p' docs/harness.md`
- `sed -n '1,260p' docs/debug-contracts.md`
- `sed -n '1,260p' docs/exec-plans/active/2026-03-28-launch-empty-viewer.md`
- `sed -n '1,300p' docs/exec-plans/active/2026-03-23-window-scoped-workspaces.md`
- `sed -n '1,320p' docs/exec-plans/active/2026-04-16-remote-inline-media-and-linked-preview.md`
- `sed -n '1,280p' docs/exec-plans/active/2026-03-25-relative-markdown-links.md`
- `rg -n "WorkspaceProvider|workspaceRoot|openFolder|empty viewer|empty home|Load|remote|GitHub|raw.githubusercontent.com|sidebar" "Quick Markdown Viewer"`
- `sed -n '1,260p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift"`
- `sed -n '1,760p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift"`
- `sed -n '420,560p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift"`
- `sed -n '1,240p' "Quick Markdown Viewer/Quick Markdown Viewer/Harness/HarnessLaunchOptions.swift"`
- `sed -n '1,260p' "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceWindowSessionStore.swift"`
- `sed -n '1,220p' .agents/DOCUMENTATION.md`
- `rg -n "network.client|https|GitHub|remote workspace|raw.githubusercontent.com|cache" docs "Quick Markdown Viewer/Quick Markdown Viewer/Quick_Markdown_Viewer.entitlements" "Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift" "Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift"`
- `date -u +"%Y-%m-%dT%H:%MZ"`

Expected implementation touch points:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceProvider.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/WorkspaceWindowSessionStore.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/GitHubWorkspace/`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/HarnessLaunchOptions.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/AccessibilityIDs.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests.swift`
- `docs/debug-contracts.md`
- `docs/harness.md`
- `docs/SECURITY.md`
- `docs/release/app-review-notes.md`
- `.agents/DOCUMENTATION.md`

Expected validation commands after implementation:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-github-workspaces-unit -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testGitHubWorkspaceURLResolvesDefaultBranchForRepoRoot" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testGitHubWorkspaceURLResolvesBranchAndTagTreeRefs" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testGitHubWorkspaceCacheReopensWhenOffline" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testRestoredGitHubWorkspaceSessionUsesCachedSnapshot" test`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-github-workspaces-ui-macos -destination "platform=macOS,arch=arm64" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testEmptyStateLoadsGitHubWorkspaceFromURL" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testOpenGitHubURLShowsInlineValidationErrorForUnsupportedURL" test`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-github-workspaces-ui-ios -destination "platform=iOS Simulator,name=iPhone 16" "-only-testing:Quick Markdown ViewerUITests/Quick_Markdown_ViewerUITests/testiPhoneEmptyStateLoadsGitHubWorkspaceFromURL" test`
- `./scripts/test-unit`
- `./scripts/test-ui-macos --smoke`
- `./scripts/test-ui-ios --device both --smoke`
- `python3 scripts/check_execplan.py docs/exec-plans/active/2026-04-16-github-url-workspaces.md`
- `python3 scripts/knowledge/check_docs.py`

## Interfaces and Dependencies

New shared interfaces likely required:

- `GitHubWorkspaceDescriptor` for parsed and resolved GitHub workspace identity
- `WorkspaceSource` or equivalent session or persistence model that distinguishes local and GitHub workspaces
- `GitHubWorkspaceCache` for alias lookup, snapshot storage, and eviction
- `GitHubRemoteClient` or equivalent injectable transport for metadata, ref, and snapshot fetching
- a small shared view model for the URL-entry form so empty-state and toolbar or menu surfaces do not fork behavior

Platform or framework dependencies:

- `URLSession` for user-initiated GitHub metadata and snapshot downloads
- app cache directories under `FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)`
- archive extraction support for the downloaded GitHub snapshot payload
- the existing macOS `com.apple.security.network.client` entitlement
- SwiftUI text-field, button, loading, and sheet or navigation presentation APIs on macOS and iOS

Behavioral constraints the implementation must preserve:

- no `WKWebView`
- no general web browsing surface
- no authentication flow in this milestone
- no mutation of user-selected local workspaces
- no public-internet dependency in automated coverage
