# Code, Print, and Quick Look

Read code-heavy docs, preview Markdown from Finder with Quick Look on macOS, then print one document or assemble a full packet in the background.

```swift
struct ReleaseNote: Identifiable {
    let id: UUID
    let title: String
    let status: Status
}
```

Print preparation can be cancelled, and empty output is blocked before the native print sheet opens.
