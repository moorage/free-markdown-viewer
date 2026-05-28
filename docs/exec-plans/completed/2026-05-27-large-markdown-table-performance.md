# Large Markdown Table Performance

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

## Purpose / Big Picture

Opening `tmp/social_back_and_forth_people_report.md` should not beachball the app. The report is a normal Markdown document with one very large pipe table, so the app needs the same kind of bounded lazy table behavior already used for standalone CSV/TSV data, without weakening the native Markdown renderer or adding HTML/WebView rendering.

## Progress

- [x] (2026-05-27T01:04Z) Confirmed the sample file is about 200 KB and 2,357 lines, dominated by one 2,328-row Markdown pipe table.
- [x] (2026-05-27T01:04Z) Identified the likely root cause: Markdown tables still render through an eager SwiftUI `Grid`, while only standalone CSV/TSV tables use the bounded lazy table surface.
- [x] (2026-05-27T02:10Z) Added shared large-table thresholds, lazy plain-cell attribution, and bounded lazy interactive rendering for large Markdown tables.
- [x] (2026-05-27T02:10Z) Added focused renderer tests covering large plain Markdown tables, large Markdown tables with links, existing link preservation, and the small-table spec example.
- [x] (2026-05-27T02:17Z) Captured the actual `tmp/social_back_and_forth_people_report.md` checkpoint successfully; the app wrote state, perf, and screenshot artifacts with `readyTime` about 1.21 seconds.
- [x] (2026-05-27T02:20Z) Ran focused tests, the actual-report checkpoint, `./scripts/test-unit`, ExecPlan/docs checks, and whitespace validation successfully.

## Surprises & Discoveries

- Observation: the previous large-table performance work intentionally scoped lazy rendering to standalone CSV/TSV files.
  Evidence: `docs/exec-plans/active/2026-05-12-large-csv-performance.md` records that Markdown tables stayed on the document-flow `Grid` path, and `ViewerShellView.tableContent(_:)` only enters the lazy path when `tabularPresentation` is present and the table is `.plainText`.
- Observation: the harness-visible report state now parses the document into 11 blocks, including the large people table as one table block.
  Evidence: `artifacts/checkpoints/large-markdown-table-macos/state.json` lists `visibleBlockCount` as 11 in the matching perf snapshot.

## Decision Log

- Decision: keep small Markdown tables on the existing natural document-flow renderer.
  Rationale: small embedded Markdown tables should preserve current layout and inline Markdown/link behavior.
- Decision: route large Markdown tables through a bounded lazy table viewport.
  Rationale: a Markdown report with thousands of rows is functionally a data table; building every row view at once is the direct beachball risk.
- Decision: avoid constructing `AttributedString(markdown:)` for every table cell during parse when cells have no inline Markdown syntax.
  Rationale: parsing should stay off the main actor, but front-loading thousands of attributed cells is still avoidable CPU and memory work.

## Outcomes & Retrospective

Large Markdown pipe tables now use a shared row/cell threshold to opt into a bounded lazy viewport during interactive rendering. Plain large tables are marked as `.plainText` when their cells do not contain inline Markdown syntax, so parsing no longer constructs an attributed string for every cell up front. Large tables that do contain links or other inline Markdown still preserve attributes, but attribution is limited to cells that need it and visible lazy rows do not require building the full SwiftUI `Grid`.

The actual `tmp/social_back_and_forth_people_report.md` file now opens through the macOS checkpoint harness and reports readiness in about 1.21 seconds after launch, with state, perf, and screenshot artifacts written under `artifacts/checkpoints/large-markdown-table-macos/`.

## Context and Orientation

Relevant code:

- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift` parses Markdown pipe tables.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift` renders table blocks.
- `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/TabularDocument.swift` defines the existing table presentation defaults used by CSV/TSV.
- `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift` owns renderer and table regression tests.

## Plan of Work

1. Add a conservative large-table threshold for Markdown pipe tables.
2. Parse Markdown table cells as plain text when they do not contain inline Markdown syntax.
3. Use a bounded lazy table viewport for large Markdown tables, while preserving the eager `Grid` path for small Markdown tables.
4. Add tests for a synthetic large Markdown table and for existing Markdown table link preservation.
5. Run focused unit tests, `python3 scripts/check_execplan.py`, and `python3 scripts/knowledge/check_docs.py`.

## Concrete Steps

From `/Users/matthewmoore/Projects/free-markdown-viewer`:

1. Edit `Quick Markdown Viewer/Quick Markdown Viewer/App/Shared/MarkdownRenderer.swift`.
2. Edit `Quick Markdown Viewer/Quick Markdown Viewer/App/Shell/ViewerShellView.swift`.
3. Add focused tests in `Quick Markdown Viewer/Quick Markdown ViewerTests/Quick_Markdown_ViewerTests.swift`.
4. Run the focused renderer tests with `xcodebuild`.
5. Run the repository ExecPlan/docs verification commands.

## Validation and Acceptance

Acceptance:

- `tmp/social_back_and_forth_people_report.md` parses into a large table without eagerly attributing every plain-text cell.
- Large Markdown tables render through a bounded lazy viewport instead of an eager `Grid`.
- Small Markdown tables keep their existing flow layout.
- Markdown links inside table cells still preserve link attributes.
- No `WKWebView`, HTML/CSS, JavaScript renderer, or external renderer is introduced.

## Idempotence and Recovery

The change is deterministic and read-only. If the bounded large Markdown-table viewport causes a layout regression, recovery is to raise the threshold or gate the lazy viewport to plain-text large tables only.

## Artifacts and Notes

Expected validation commands:

- `xcodebuild -quiet -project "Quick Markdown Viewer/Quick Markdown Viewer.xcodeproj" -scheme "Quick Markdown Viewer" -configuration Debug -derivedDataPath /tmp/qmv-large-markdown-table-tests -destination "platform=macOS,arch=arm64" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererMarksLargePlainPipeTableAsPlainText" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererPreservesLargePipeTableLinksWhenCellsContainMarkdown" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererPreservesRelativeLinksInsideTables" "-only-testing:Quick Markdown ViewerTests/Quick_Markdown_ViewerTests/testMarkdownRendererParsesTableFromSpecExample" test`
- `./scripts/capture-checkpoint --fixture social_back_and_forth_people_report.md --fixture-root tmp --platform-target macos --checkpoint large-markdown-table-macos`
- `./scripts/test-unit`
- `python3 scripts/check_execplan.py`
- `python3 scripts/knowledge/check_docs.py`
- `git diff --check`

## Interfaces and Dependencies

No new dependencies are required. The implementation uses existing native Swift parsing models and SwiftUI lazy containers.
