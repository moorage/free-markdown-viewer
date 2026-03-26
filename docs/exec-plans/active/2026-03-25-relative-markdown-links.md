# Relative Markdown Link Navigation

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Restore visible and navigable Markdown links for repo-local `.md` files. The target behavior is that inline links in ordinary paragraphs and in table cells render with native link styling, remain clickable in the selectable text surface, and navigate to the linked Markdown document when the destination resolves inside the opened workspace.

## Progress

- [x] (2026-03-26T05:50Z) Confirmed the current regression: the selectable text formatter rebuilds plain strings from blocks, which strips link attributes entirely, and table cells are stored as plain text so table links cannot survive parsing either.
- [x] (2026-03-26T06:01Z) Preserved attributed inline content through table parsing and the selectable formatter, and reapplied native link styling so inline links remain visibly blue and clickable.
- [x] (2026-03-26T06:01Z) Routed relative Markdown links through viewer-level link interception that resolves against the current document path and opens matching workspace files.
- [x] (2026-03-26T06:01Z) Added focused regression coverage and reran the narrow validation slice plus docs checks.

## Surprises & Discoveries

- Observation: Swift `AttributedString(markdown:)` already preserves relative Markdown link destinations such as `./app-store-submission.md`; the links disappear later in the app pipeline.
  Evidence: a local `swift -e` probe against `AttributedString(markdown: "[doc](./app-store-submission.md)")` produced a run with `link = ./app-store-submission.md`.

- Observation: the current selectable formatter applies block-level presentation by rebuilding raw `String` content, which discards all inline attributes including `.link`.
  Evidence: `Swift Markdown Viewer/Swift Markdown Viewer/App/Platform/SelectableDocumentTextView.swift` previously rendered `NSMutableAttributedString(string: blockText(for: block), attributes: ...)` from `block.plainText`.

- Observation: relative workspace links need app-level routing, not just visual styling, because system URL opening does not know the current document directory or workspace root.
  Evidence: the app had no existing `openURL` interception or text-view delegate link handler anywhere under `Swift Markdown Viewer/Swift Markdown Viewer/App/`.

- Observation: the structured SwiftUI renderer also needs the same routing path, otherwise table-cell links in block-rendered documents would still bypass workspace navigation.
  Evidence: table-containing documents render via `ViewerShellView.detailContent -> DocumentBlockScrollView`, not through the selectable text view path.

## Decision Log

- Decision: keep table cells as structured data with both visible text and optional attributed inline content instead of reparsing them in each view.
  Rationale: that preserves links once during parsing and lets both the grid renderer and selectable formatter share the same canonical cell data.
  Date/Author: 2026-03-26 / Codex

- Decision: intercept document link clicks centrally in the viewer and route repo-local Markdown links through `AppModel.openFile`.
  Rationale: relative Markdown targets must resolve against the current document path and stay inside the opened workspace; the system URL opener cannot do that resolution correctly.
  Date/Author: 2026-03-26 / Codex

## Outcomes & Retrospective

The renderer now preserves relative Markdown links end to end. Table cells carry parsed inline attributed content, the selectable formatter styles those attributed runs instead of flattening them to strings, and both the native selectable text view and the SwiftUI block renderer funnel link taps through one viewer-level handler. That handler opens matching Markdown files inside the workspace when the destination resolves relative to the current document, while external links still fall back to the system URL opener.

The highest-leverage fix was preserving attributed content instead of trying to reconstruct links later. Once the parser retained link-bearing table cells and the selectable formatter stopped erasing `.link` runs, the remaining work was routing relative URLs through app state rather than through the operating system.

## Context and Orientation

Relevant files:

- `Swift Markdown Viewer/Swift Markdown Viewer/App/Shared/MarkdownRenderer.swift`
- `Swift Markdown Viewer/Swift Markdown Viewer/App/Shared/Models.swift`
- `Swift Markdown Viewer/Swift Markdown Viewer/App/Shared/AppModel.swift`
- `Swift Markdown Viewer/Swift Markdown Viewer/App/Platform/SelectableDocumentTextView.swift`
- `Swift Markdown Viewer/Swift Markdown Viewer/App/Shell/ViewerShellView.swift`
- `Swift Markdown Viewer/Swift Markdown ViewerTests/Swift_Markdown_ViewerTests.swift`

## Plan of Work

1. Preserve link-bearing `AttributedString` content for paragraph/list text and for parsed table cells.
2. Update the selectable text formatter so it styles attributed inline content instead of flattening blocks to plain strings.
3. Add internal document-link routing for relative/local Markdown links in both the selectable text view and the structured SwiftUI renderer.
4. Add regression tests for link preservation and relative workspace navigation.

## Concrete Steps

1. Extend the shared table model to carry per-cell attributed content.
2. Rework `SelectableDocumentFormatter` to compose `NSAttributedString` output from `AttributedString` runs and reapply native link styling after block-level attributes.
3. Add text-view delegate callbacks plus a shared viewer-level link handler that falls back to system URL opening only for non-workspace links.
4. Add focused unit tests for selectable-link preservation, table-cell link preservation, and relative document navigation.
5. Run the narrowest relevant `xcodebuild` test slice, `python3 scripts/check_execplan.py`, and `python3 scripts/knowledge/check_docs.py`.

## Validation and Acceptance

Acceptance requires:

- inline Markdown links in selectable documents render with link attributes intact
- relative `.md` links in paragraphs navigate to the target file inside the workspace
- relative `.md` links inside tables preserve link attributes and navigate through the same handler
- non-Markdown or external links still fall back to system handling
- targeted unit coverage passes, plus `python3 scripts/check_execplan.py` and `python3 scripts/knowledge/check_docs.py`

## Idempotence and Recovery

The change is confined to parsing, document rendering, and link routing. If link interception regresses external URL handling, recovery is to disable the custom routing and keep the attributed-text preservation changes.

## Artifacts and Notes

Planned validation commands:

- `xcodebuild -quiet -project "Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj" -scheme "Swift Markdown Viewer" -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-relative-links -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Swift Markdown ViewerTests/Swift_Markdown_ViewerTests/testSelectableDocumentFormatterPreservesRelativeMarkdownLinks" "-only-testing:Swift Markdown ViewerTests/Swift_Markdown_ViewerTests/testMarkdownRendererPreservesRelativeLinksInsideTables" "-only-testing:Swift Markdown ViewerTests/Swift_Markdown_ViewerTests/testAppModelOpensRelativeMarkdownLinkWithinWorkspace" test`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`

Validation completed:

- `xcodebuild -quiet -project "Swift Markdown Viewer/Swift Markdown Viewer.xcodeproj" -scheme "Swift Markdown Viewer" -configuration Debug -derivedDataPath /tmp/swift-markdown-viewer-relative-links -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= "-only-testing:Swift Markdown ViewerTests/Swift_Markdown_ViewerTests/testSelectableDocumentFormatterPreservesRelativeMarkdownLinks" "-only-testing:Swift Markdown ViewerTests/Swift_Markdown_ViewerTests/testMarkdownRendererPreservesRelativeLinksInsideTables" "-only-testing:Swift Markdown ViewerTests/Swift_Markdown_ViewerTests/testAppModelOpensRelativeMarkdownLinkWithinWorkspace" test`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`

## Interfaces and Dependencies

No new external dependencies are required. The implementation stays inside the existing native renderer stack and uses AppKit/UIKit text-view delegate hooks plus the SwiftUI `openURL` environment.
