# Fenced Code Syntax Highlighting

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Add native syntax highlighting for fenced code blocks only. The viewer should use Tree-sitter highlight queries for an explicit allowlist of languages, keep indented code blocks and unknown fence languages on the current plain monospaced rendering path, and cache highlighted output by `(language, contentHash, theme)` so repeated renders stay cheap on macOS, iPhone, and iPad.

## Progress

- [x] (2026-04-16T05:33Z) Audited the current markdown pipeline and confirmed that `MarkdownRenderer` reduces code blocks to plain `sourceText`, `MarkdownBlockView` renders them with `Text(verbatim:)`, and `AppModel.shouldRenderStructuredContent(for:)` already routes any document containing code blocks through the structured SwiftUI renderer.
- [x] (2026-04-16T05:33Z) Evaluated upstream parser/highlighter surfaces and dependency fit: `swift-markdown` exposes `CodeBlock.code` and `CodeBlock.language`, `swift-tree-sitter` exposes native Swift highlight-query mapping, and the requested XML/regex parsers likely need repo-owned wrapper targets because they are not in the published SPM parser table used by `swift-tree-sitter`.
- [x] (2026-04-16T06:30Z) Landed the shared code-block payload, fenced-only annotation pass, Tree-sitter highlighter, theme-aware cache, and structured renderer integration. Supported fenced blocks now highlight through `swift-tree-sitter`; indented and unknown-language blocks stay on the plain monospace path.
- [x] (2026-04-16T06:35Z) Replaced broken upstream grammar package wiring with a repo-owned local package at `Packages/TreeSitterGrammars/`, vendored only the requested parser C sources and headers, bundled the corresponding `highlights.scm` files under `Quick Markdown Viewer/Quick Markdown Viewer/SyntaxHighlightingQueries/`, and verified macOS/iPhone/iPad builds with `./scripts/build --platform all`.
- [x] (2026-04-16T06:36Z) Added focused unit coverage plus the showcase fixture `Fixtures/docs/syntax_highlighting_showcase.md`. Narrow renderer/highlighter tests pass, regression slices covering existing CommonMark list/code semantics pass, and the repo `./scripts/test-unit` wrapper now reaches green unit cases but still ends with an external XCTest runner early-exit after the suite completes.
- [x] (2026-04-16T07:01Z) Fixed the remaining unit-test wrapper failure by removing the deferred `DispatchQueue.main.async` hop from `MacWindowConfiguration.updateNSView`. The hosted macOS test app no longer crashes during teardown, and `./scripts/test-unit` now finishes with `** TEST SUCCEEDED **`.

## Surprises & Discoveries

- Observation: the current shared model has no place to preserve fenced-block metadata, declared language, or highlighted output.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift` stores code blocks only through the generic `MarkdownBlock` fields `plainText`, `sourceText`, and `attributedText`, and `MarkdownBlockKind` has only a single `.codeBlock` case.

- Observation: the current renderer path already isolates code blocks in the structured SwiftUI surface, so syntax highlighting can be added without reworking the selectable whole-document text view first.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift` returns `true` from `shouldRenderStructuredContent(for:)` whenever a `.codeBlock` block appears, and `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift` renders `.codeBlock` with a dedicated rounded card branch.

- Observation: `HarnessLaunchOptions` already parses a `--theme` value, but the app does not currently resolve or use that theme anywhere in rendering.
  Evidence: `Quick Markdown Viewer/Quick Markdown Viewer/Harness/HarnessLaunchOptions.swift` stores `theme`, while no current code under `Quick Markdown Viewer/Quick Markdown Viewer/` reads `launchOptions.theme`.

- Observation: Swift Markdown's public `CodeBlock` API exposes `code` and optional `language`, but not an explicit fenced-vs-indented discriminator.
  Evidence: upstream `swiftlang/swift-markdown` publishes `CodeBlock.language` and `CodeBlock.code` in `Sources/Markdown/Block Nodes/Leaf Blocks/CodeBlock.swift`, with no public fence-style property.

- Observation: `swift-tree-sitter` is a better Xcode fit than embedding the Rust `tree-sitter-highlight` crate directly, but not every requested parser ships as a ready-made SPM product.
  Evidence: upstream `tree-sitter/swift-tree-sitter` documents native Swift highlight query support and an SPM parser table covering Bash, C, C++, C#, CSS, Go, HTML, JavaScript, JSON, Python, Ruby, Rust, Swift, and TypeScript; XML and regex are absent from that table.

- Observation: several upstream grammar packages fail Xcode dependency resolution because their manifests include invalid SwiftPM test-target references under the current toolchain.
  Evidence: `xcodebuild -resolvePackageDependencies -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer"` failed with `unknown dependency 'SwiftTreeSitter' in target 'TreeSitterCTests'`, which blocked use of the published grammar packages directly.

- Observation: a naive indented-code scanner is not safe enough to align with the existing renderer because list continuation indentation is ambiguous.
  Evidence: the first implementation crashed existing tests such as `testMarkdownRendererGroupsListChildrenFromCommonMarkFixture256()` by mistaking list continuation lines for indented code blocks; switching to fenced-only source scanning and defaulting unmatched renderer code blocks to plain fallback fixed the regression.

- Observation: the final `./scripts/test-unit` failure came from an existing macOS window bridge timing issue rather than the syntax-highlighting pipeline.
  Evidence: the `test-unit.xcresult` crash log pointed at `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/MacWindowConfiguration.swift:20` inside the deferred `DispatchQueue.main.async` closure; removing that deferral made the wrapper pass cleanly.

## Decision Log

- Decision: use `swift-tree-sitter` plus upstream `highlights.scm` query bundles instead of embedding the Rust `tree-sitter-highlight` crate.
  Rationale: this keeps the implementation native to Swift/Xcode, avoids introducing a Rust toolchain into the Apple build, and still uses Tree-sitter's standard highlight-query model.
  Date/Author: 2026-04-16 / Codex

- Decision: keep the existing `MarkdownRenderer` block-shape pipeline and add a narrow post-parse fenced-code annotation/highlighting pass rather than replacing markdown parsing wholesale.
  Rationale: the current renderer already handles tables, task lists, inline links, media, and HTML edge cases; a post-pass is the smallest safe change that adds syntax highlighting without destabilizing unrelated markdown behavior.
  Date/Author: 2026-04-16 / Codex

- Decision: restrict highlighting to fenced code blocks whose normalized info strings map to an explicit allowlist, and keep indented or unknown-language code blocks on the existing plain monospaced path.
  Rationale: this matches the requested scope exactly, avoids guessing languages, and preserves readable fallback behavior when grammar support is missing or intentionally excluded.
  Date/Author: 2026-04-16 / Codex

- Decision: compile only the requested grammar set, using upstream SPM grammar packages where available and repo-owned wrapper targets only for missing parsers such as regex and XML.
  Rationale: this bounds binary/build impact and avoids dragging in a broad omnibus grammar bundle that exceeds the requested language scope.
  Date/Author: 2026-04-16 / Codex

- Decision: vendor one local package that exposes the requested grammar products (`TreeSitterBash`, `TreeSitterJSON`, and so on) instead of depending on the upstream grammar package manifests directly.
  Rationale: the upstream manifests fail package resolution in this project, while a local package with just the parser C sources, support headers, and a dependency on the `tree-sitter` runtime keeps the package graph stable and still compiles only the requested languages.
  Date/Author: 2026-04-16 / Codex

- Decision: use a fenced-only source scanner plus renderer-order matching instead of Swift Markdown code-block discovery or a general indented-code parser.
  Rationale: fenced highlighting is the only requested feature, the existing renderer already identifies code blocks correctly, and treating every non-matched renderer code block as plain fallback avoids regressions in list-heavy CommonMark fixtures.
  Date/Author: 2026-04-16 / Codex

- Decision: keep `MacWindowConfiguration` window mutations synchronous inside `updateNSView` instead of deferring them onto the main queue.
  Rationale: `NSViewRepresentable.updateNSView` already executes on the UI update path, and the deferred closure could survive longer than the hosted unit-test window lifecycle and crash the runner during teardown.
  Date/Author: 2026-04-16 / Codex

- Decision: cache the final highlighted attributed output using a stable key of canonical language, SHA-256 content hash, and resolved theme identifier.
  Rationale: the renderer can stay synchronous and cheap on re-render while recomputing highlights only when the code, language, or theme actually changes.
  Date/Author: 2026-04-16 / Codex

## Outcomes & Retrospective

Implementation landed in the existing native renderer without widening highlighting scope beyond fenced code blocks. `MarkdownBlock` now carries a `MarkdownCodeBlock` payload, `MarkdownRenderer` annotates code blocks through a fenced-only source catalog, `ViewerShellView` renders highlighted `AttributedString` output when available, and repeated blocks reuse cached token spans keyed by `(language, SHA-256(code), themeIdentifier)`.

The most important implementation adjustment versus the original design was dependency strategy. Instead of leaning on upstream grammar packages plus Swift Markdown discovery, the repo now uses `swift-tree-sitter` plus a local `Packages/TreeSitterGrammars` package and a small fenced scanner over raw markdown source. That kept the build stable, avoided the broken upstream manifests, and preserved existing markdown semantics across the CommonMark corpus tests.

Rollback remains simple: remove `Packages/TreeSitterGrammars/`, `App/Shared/SyntaxHighlighting/`, the bundled query assets, and the renderer/view wiring, then fall back to the previous `Text(verbatim:)` code-block branch.

## Context and Orientation

Relevant existing files:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/AppModel.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/SelectableDocumentTextView.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer/Harness/HarnessLaunchOptions.swift`
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`
- `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj`

Expected new implementation area:

- new files under `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/SyntaxHighlighting/`
- at least one new showcase fixture under `Fixtures/docs/`

## Plan of Work

1. Add fenced-code metadata to the shared markdown block model without changing non-code block semantics.
2. Introduce a Tree-sitter-backed highlighting subsystem with an allowlisted language registry, theme resolution, and cache keyed by `(language, contentHash, theme)`.
3. Thread highlighted attributed output into the structured code-block renderer while preserving the existing plain fallback path.
4. Add focused unit coverage, a showcase fixture, and visual validation for supported and unsupported fence languages.

## Concrete Steps

1. Update `Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj/project.pbxproj` to keep `tree-sitter/swift-tree-sitter` as the remote dependency and add a local package reference to `Packages/TreeSitterGrammars/`, which vends only the requested grammar products (`swift`, `json`, `python`, `bash`, `javascript`, `typescript`, `c`, `cpp`, `csharp`, `css`, `html`, `xml`, `go`, `regex`, `ruby`, `rust`) from checked-in parser C sources and headers.

2. Extend `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/Models.swift` with a dedicated code-block payload that can carry raw code, raw info string, normalized/canonical language, a fenced-vs-indented flag, and optional highlighted attributed output while preserving existing `MarkdownBlockKind.codeBlock`.

3. Add a fenced-code catalog helper under `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/SyntaxHighlighting/` that scans only fenced code blocks from raw markdown source, matches them to renderer code blocks in source order, and defaults all unmatched renderer code blocks to plain fallback metadata. If unmatched fenced entries remain, emit a developer-visible debug message and keep rendering plain text instead of crashing.

4. Add a language registry and alias normalizer under `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/SyntaxHighlighting/` that maps fence info strings onto the requested canonical languages only. Support common aliases such as `sh|shell|zsh -> bash`, `js|jsx|mjs|cjs -> javascript`, `ts|tsx|mts|cts -> typescript`, `c++|cc|cxx -> cpp`, `c#|cs|csharp -> csharp`, and `htm -> html`. Unknown strings must remain unknown and use the plain fallback.

5. Add a `TreeSitterCodeBlockHighlighter` and `HighlightedCodeBlockCache` under `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/SyntaxHighlighting/` that load per-language highlight queries through `swift-tree-sitter`, hash code text with `CryptoKit` SHA-256, and cache final `AttributedString` results by `(canonicalLanguage, contentHash, themeIdentifier)`.

6. Resolve a stable highlight theme identifier from `HarnessLaunchOptions.theme` when present, otherwise from the current light/dark UI environment. Keep the theme surface minimal in this milestone: enough to drive token colors and the cache key, not a broader app-theming system.

7. Integrate the new code-block annotation/highlighting pass into the existing shared renderer flow so document blocks are annotated before the SwiftUI code-block branch renders. Keep highlighting failures non-fatal: preserve the raw code block, emit a developer-visible debug message, and continue rendering plain monospace text.

8. Update `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift` so `.codeBlock` prefers highlighted attributed output when available, keeps the existing rounded card/background treatment, and falls back to the current `Text(verbatim:)` path for indented blocks, unknown languages, cache misses that fail to populate, or grammar/query errors. Update `Quick Markdown Viewer/Quick Markdown Viewer/App/Platform/SelectableDocumentTextView.swift` only as needed to share any new code-block attributed-text helper, not to expand highlighting scope beyond fenced blocks.

9. Add targeted tests to `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift` for fenced-vs-indented detection, allowlist alias normalization, unknown-language fallback, cache hit/miss behavior across language/content/theme changes, and rendered highlighted output for a representative multi-language fixture. Add a showcase fixture under `Fixtures/docs/` that includes repeated supported fences, a fence with no info string, and an unsupported fence to lock the fallback behavior.

## Validation and Acceptance

Acceptance requires:

- only fenced code blocks receive syntax highlighting; indented code blocks remain on the current plain monospaced rendering path
- allowlisted fence languages cover exactly `swift`, `json`, `python`, `bash`, `javascript`, `typescript`, `c`, `cpp`, `csharp`, `css`, `html`, `xml`, `go`, `regex`, `ruby`, and `rust`
- unknown or unsupported info strings preserve visible code content and render with plain monospaced fallback
- highlighted output is cached by `(language, contentHash, theme)` and unit tests prove cache reuse and invalidation behavior
- documents with repeated identical fenced blocks reuse cached highlighted output instead of recomputing it for every re-render
- macOS, iPhone, and iPad builds all compile with the new package/grammar integration
- a showcase checkpoint visibly highlights supported fences and leaves the unknown-language fence plain
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `./scripts/build --platform all`
- `./scripts/test-unit`

## Idempotence and Recovery

All highlight output is derived from checked-in grammar/query assets plus the current document text. No persisted workspace or document state changes are required for this feature. If package integration or parser setup regresses, recovery is to bypass the highlighting pass and return the existing plain `MarkdownBlockKind.codeBlock` rendering while keeping the rest of the markdown pipeline intact.

Because the cache key is purely derived data, cache contents can be dropped and rebuilt at any time. The smallest rollback is to remove the new syntax-highlighting files and project-package references, leaving `MarkdownRenderer`, `AppModel`, and `ViewerShellView` on their current plain-code-block behavior.

## Artifacts and Notes

Planned validation commands:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/quick-markdown-viewer-syntax-highlighting-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testFencedCodeBlocksUseAllowlistedSyntaxHighlighting" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testIndentedCodeBlocksRemainPlainMonospace" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testUnknownFenceLanguageFallsBackToPlainMonospace" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testSyntaxHighlightCacheKeysByLanguageContentHashAndTheme" test`
- `./scripts/capture-checkpoint --fixture syntax_highlighting_showcase.md --platform-target macos --checkpoint syntax-highlighting-macos`
- `./scripts/compare-goldens --checkpoint syntax-highlighting-macos`
- `./scripts/build --platform all`
- `./scripts/test-unit`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`

Validation run in this implementation:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/quick-markdown-viewer-syntax-highlighting-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererMarksIndentedCodeBlocksAsPlainFallback" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererAnnotatesFencedCodeBlocksWithNormalizedLanguage" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererFallsBackForUnknownFenceLanguage" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testCodeBlockSyntaxHighlighterCachesByLanguageContentHashAndTheme" test`
- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/quick-markdown-viewer-syntax-highlighting-regression-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Quick Markdown ViewerTests/testMarkdownRendererGroupsListChildrenFromCommonMarkFixture256" "-only-testing:Quick Markdown ViewerTests/testStateSnapshotFlattensNestedListChildren" "-only-testing:Quick Markdown ViewerTests/testMarkdownRendererParsesNestedAndTaskListItems" "-only-testing:Quick Markdown ViewerTests/testMarkdownRendererMatchesCommonMarkFixtureCorpusSemantics" "-only-testing:Quick Markdown ViewerTests/testMarkdownRendererMarksIndentedCodeBlocksAsPlainFallback" "-only-testing:Quick Markdown ViewerTests/testMarkdownRendererAnnotatesFencedCodeBlocksWithNormalizedLanguage" "-only-testing:Quick Markdown ViewerTests/testMarkdownRendererFallsBackForUnknownFenceLanguage" "-only-testing:Quick Markdown ViewerTests/testCodeBlockSyntaxHighlighterCachesByLanguageContentHashAndTheme" test`
- `./scripts/build --platform all`
- `./scripts/test-unit`

Notes on validation:

- `./scripts/build --platform all` succeeded for macOS, iPhone simulator, and iPad simulator.
- `./scripts/test-unit` now succeeds end-to-end after removing the deferred `MacWindowConfiguration` window mutation that was crashing the hosted macOS unit-test app during teardown.

Notes:

- No harness contract changes are planned for this milestone unless validation proves that the state snapshot needs to expose code-block language/theme metadata for debugging.
- This plan intentionally does not add inline-code highlighting, raw-HTML highlighting, or auto-detection of unknown fence languages.

## Interfaces and Dependencies

New shared interfaces:

- `MarkdownCodeBlock` or equivalent code-block payload type in `Models.swift`
- `SyntaxHighlightLanguage`
- `SyntaxHighlightTheme`
- `SyntaxHighlightCacheKey`
- `FencedCodeBlockCatalog`
- `TreeSitterCodeBlockHighlighter`
- `HighlightedCodeBlockCache`

External dependencies:

- `tree-sitter/swift-tree-sitter` for native Swift parser/query integration
- local `Packages/TreeSitterGrammars` package for the requested grammar targets only: Bash, C, C++, C#, CSS, Go, HTML, JavaScript, JSON, Python, Regex, Ruby, Rust, Swift, TypeScript, XML
- bundled `highlights.scm` assets under `Quick Markdown Viewer/Quick Markdown Viewer/SyntaxHighlightingQueries/`

Important dependency boundaries:

- do not add a Markdown Tree-sitter grammar; markdown parsing stays with the existing renderer plus a narrow fenced source scanner
- do not highlight inline code or unknown fence languages
- do not allow grammar selection outside the explicit allowlist
