# Quick Look Feature Parity

Quick Look previews should track the app's document features where a single-file,
read-only preview can do so cheaply and safely. The extension must remain native
AppKit, must not use `WKWebView`, HTML/CSS/JavaScript rendering, remote services,
or renderer subprocesses, and must avoid work that can make Finder previews slow
or memory-heavy.

## Parity Matrix

| App feature | Quick Look behavior | Limit |
| --- | --- | --- |
| Markdown headings, paragraphs, emphasis, links, lists, quotes, rules | Rendered as native attributed text | Extension-local block formatting only |
| Markdown tables, CSV, TSV | Rendered as monospaced native tables | No interactive resizing, sorting, or lazy viewport controls |
| JSON, JSONC, NDJSON, JSONL | Rendered as native line-numbered code with an expand/collapse control; JSON and JSONC pretty-print when possible, while NDJSON collapses each parseable record line | Does not expose the full app tree/table controls |
| Inline Mermaid fences | Rendered as a bounded native diagram image attachment with title and diagram kind | Does not expose zoom, pan, detached preview UI, or Mermaid.js-only styling |
| Standalone `.mermaid` / `.mmd` files | Rendered as a bounded native diagram image attachment with title and diagram kind | Same limited preview as inline Mermaid |
| Local inline images | Rendered as scaled native image attachments with captions | No animation playback; large or unreadable images fall back to labeled source text |
| Remote or data images | Rendered as labeled source text | No network fetch and no data URI decoding in Quick Look |
| Inline videos and linked media | Rendered as labeled source text | No playback, network fetch, or linked preview navigation |
| Raw source inspection | Available through the `Source` segmented control | Uses a single cached source string for the loaded file |

## Harness Requirements

Unit coverage must load the built Quick Look extension and verify behavior through
the extension's preview formatter/test hooks, not by inspecting implementation
strings alone. Fixture coverage should include:

- `Fixtures/docs/basic_typography.md` for rendered Markdown hierarchy.
- `Fixtures/docs/mermaid_inline_showcase.md` for inline Mermaid fence parity;
  rendered mode must include a native image attachment and must not include the
  raw `flowchart LR` source text.
- A local image fixture or temporary workspace image for native image attachment
  previews.
- JSON-family fixtures such as `Fixtures/docs/json_showcase.json` and
  `Fixtures/docs/events.ndjson` for line-numbered rendered previews.
- Every supported Markdown, Mermaid, CSV, TSV, and JSON-family fixture under `Fixtures/docs`
  and `Fixtures/app-store` for non-empty bounded previews.

Finder/`qlmanage` checks are useful smoke tests, but they are not the authority:
PlugInKit can route to an installed stale app extension. The repeatable harness
authority is the built `.appex` loaded from the current build products.
