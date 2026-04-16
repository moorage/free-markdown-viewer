# Syntax Highlighting Showcase

Supported fenced block:

```swift
struct Greeter {
    let name: String

    func message() -> String {
        "Hello, \\(name)"
    }
}
```

Repeated supported fenced block to exercise cache reuse:

```swift
struct Greeter {
    let name: String

    func message() -> String {
        "Hello, \\(name)"
    }
}
```

Supported block with another grammar:

```json
{
  "enabled": true,
  "languages": ["swift", "json", "bash"]
}
```

Fenced block with no language stays plain:

```
plain fence with no info string
```

Unsupported language stays plain:

```brainheck
+++--
```
