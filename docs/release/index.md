# Release Docs Index

This directory collects the repo-owned documents used to prepare, validate, and publish an App Store release for Quick Markdown Viewer.

## Documents

- [`app-store-submission.md`](./app-store-submission.md)
  - What it is: the main App Store prep overview, including URL mappings, legal defaults, release commands, and the remaining App Store Connect work.
  - Why it's here: it gives one central handoff document for everything in the repo that supports submission before you switch to Xcode, App Store Connect, or your website.

- [`release-completion-checklist.md`](./release-completion-checklist.md)
  - What it is: the ordered checklist for turning the current repo state into a shipped App Store release.
  - Why it's here: it is the shortest operational path through the release process, so you can execute the remaining work in sequence without rediscovering dependencies.

- [`app-store-metadata.md`](./app-store-metadata.md)
  - What it is: draft App Store listing copy, naming options, URL references, and screenshot shot lists.
  - Why it's here: it keeps the customer-facing App Store content versioned in the repo so listing text and capture planning stay aligned with the product.

- [`app-review-notes.md`](./app-review-notes.md)
  - What it is: draft text for the App Review Notes field in App Store Connect, including a quick reviewer test flow.
  - Why it's here: App Review often needs concise context about local-first apps and sandboxed file access, and this gives a reusable starting point.

- [`screenshot-capture.md`](./screenshot-capture.md)
  - What it is: the instructions for generating repeatable candidate App Store screenshots from the repo-owned fixture set.
  - Why it's here: release screenshots need to be reproducible and reviewable, and this doc ties the capture command to the expected artifact layout.

- [`quick-markdown-viewer-support.md`](./quick-markdown-viewer-support.md)
  - What it is: draft content for the public support page linked from the App Store listing.
  - Why it's here: App Store submissions need a support destination, and this file keeps the support copy close to the product and release workflow.

- [`privacy-policy-draft.md`](./privacy-policy-draft.md)
  - What it is: a product-grounded draft privacy policy based on the app's current local-first behavior.
  - Why it's here: privacy disclosures must match shipped behavior, and keeping this draft in-repo makes those claims easier to review before publication.

- [`terms-of-use-draft.md`](./terms-of-use-draft.md)
  - What it is: a draft website/app terms page intended to complement Apple's standard EULA.
  - Why it's here: release preparation includes a public legal surface, and this gives a maintainable starting point for the terms page before final legal review.
