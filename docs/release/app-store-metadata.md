# App Store Metadata Draft

Use this file as the source for App Store Connect listing text and screenshot planning.

## App identity

- App name: `Quick Markdown Viewer`
- Subtitle option 1: `Open Markdown folders fast`
- Subtitle option 2: `Local-first Markdown reader`
- Subtitle option 3: `Browse docs across Apple devices`
- Primary category: `Productivity`
- Pricing: `Free`

## Promotional text

Open Markdown folders on Mac, iPhone, and iPad with a fast, local-first viewer that keeps documents readable and easy to navigate.

## What's New

Use this for the `What's New` field on the next App Store version:

- Open a document outline from the right side and jump directly to Markdown headings
- Highlight the current section in the outline while reading
- Resize the outline pane on Mac and iPad
- View large CSV and TSV files with a faster lazy table surface
- Check for newer App Store versions, with skip controls and a Mac menu command

## Description

Quick Markdown Viewer is a simple, local-first app for opening folders full of Markdown files and browsing them across macOS, iPhone, and iPad.

Use it to read notes, documentation, knowledge bases, exported reports, and project folders without setting up an account or relying on a web service.

Features:

- Open a folder and browse Markdown files from a sidebar
- Open public GitHub repository and repository tree URLs, including branch and tag paths
- Hide dependency and vendor folders from each window's sidebar with editable ignore patterns
- Read Markdown with native rendering for headings, lists, tables, code blocks, images, animated images, and local video
- Open CSV and TSV files alongside Markdown and view them with native table rendering
- Open a right-side outline for Markdown headings and jump around long documents
- Render direct remote image and video links authored inside Markdown
- Print the current file or the entire workspace with rendered Markdown and table output
- Navigate quickly between files with back and forward history
- Adjust viewer font size for comfortable reading
- Adjust CSV and TSV wrapping plus table sizing for easier reading
- Work entirely with files you choose from Finder or the Files app
- On macOS, optionally install the `qmv` command-line launcher to reopen folders from Terminal

Quick Markdown Viewer is designed to stay lightweight and direct:

- no account required
- no subscription
- no in-app purchase
- no tracking

## Keywords

Pick one final set under Apple’s character limit. Start with this:

- markdown,viewer,notes,docs,documentation,readme,md,text,writer

Shorter alternative:

- markdown,viewer,docs,notes,readme,text,md

## Support and policy URLs

- Marketing URL: `https://www.matthewpaulmoore.com/apps/free-markdown-viewer`
- Support URL: `https://www.matthewpaulmoore.com/apps/free-markdown-viewer/support`

The website slug stays on `free-markdown-viewer` for now because those pages are live today; only the visible app name is changing in this workstream.
- Privacy Policy URL: `https://www.matthewpaulmoore.com/legal/privacy`
- Terms URL: `https://www.matthewpaulmoore.com/legal/terms`

## App Review notes

Primary draft source:

- `docs/release/app-review-notes.md`

## Screenshot shot list

Capture the same content set on each platform so the listing feels consistent.

### Shared content setup

Use one polished demo folder with:

- one typography-heavy Markdown file
- one file with a table
- one file with local image references
- one file with a code block

Avoid placeholder-looking filenames if possible.

Repository-owned capture set:

- `Fixtures/app-store/Open Markdown Folders.md`
- `Fixtures/app-store/Architecture Overview.md`
- `Fixtures/app-store/Code Sample.md`
- `Fixtures/app-store/Image Preview.md`
- `Fixtures/app-store/Navigation Notes.md`

Repeatable capture command:

- `./scripts/capture-app-store-screenshots`

### iPhone screenshots

Suggested sequence:

1. Sidebar open with a clean list of Markdown files
2. Rich document view showing headings, paragraphs, and lists
3. Table rendering in the viewer
4. Media rendering with image or animated image content
5. Font size controls in use on a readable document

Suggested captions:

- `Open Markdown folders from Files`
- `Browse documents with a clean sidebar`
- `Read tables, code, and rich formatting`
- `View local images right in your notes`
- `Adjust text size for comfortable reading`

### iPad screenshots

Suggested sequence:

1. Two-column browsing layout with sidebar and document visible together
2. Large formatted document view
3. Table-heavy document
4. Media-rich document with image preview
5. Navigation controls with back/forward flow

Suggested captions:

- `See your files and document at the same time`
- `Read long Markdown documents comfortably`
- `Handle structured content like tables with ease`
- `Keep local media next to your notes`
- `Move through your folder quickly`

### macOS screenshots

Suggested sequence:

1. Full desktop window with sidebar and document
2. Table rendering
3. Code block and typography rendering
4. Media rendering
5. Font-size-adjusted reading view

Suggested captions:

- `Browse Markdown folders on your Mac`
- `Render tables and structured documents clearly`
- `Read code blocks and documentation natively`
- `Keep linked local media visible`
- `Tune the viewer to your preferred reading size`

## Final listing decisions to make

- choose one subtitle
- choose one keyword set
- choose final screenshot captions
- confirm `Quick Markdown Viewer` is the final App Store name
