import CryptoKit
import Foundation
import SwiftTreeSitter
import SwiftUI
import TreeSitterBash
import TreeSitterC
import TreeSitterCPP
import TreeSitterCSharp
import TreeSitterCSS
import TreeSitterGo
import TreeSitterHTML
import TreeSitterJavaScript
import TreeSitterJSON
import TreeSitterPython
import TreeSitterRegex
import TreeSitterRuby
import TreeSitterRust
import TreeSitterSwift
import TreeSitterTypeScript
import TreeSitterXML

#if os(macOS)
import AppKit
private typealias HighlightPlatformColor = NSColor
private typealias HighlightPlatformFont = NSFont
private typealias HighlightFontTextStyle = NSFont.TextStyle
#elseif os(iOS)
import UIKit
private typealias HighlightPlatformColor = UIColor
private typealias HighlightPlatformFont = UIFont
private typealias HighlightFontTextStyle = UIFont.TextStyle
#endif

enum SyntaxHighlightLanguage: String, Hashable, Sendable {
    case swift
    case json
    case python
    case bash
    case javascript
    case typescript
    case c
    case cpp
    case csharp
    case css
    case html
    case xml
    case go
    case regex
    case ruby
    case rust

    nonisolated static func normalizedFenceLanguage(from infoString: String?) -> SyntaxHighlightLanguage? {
        guard let rawToken = infoString?
            .split(whereSeparator: \.isWhitespace)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !rawToken.isEmpty else {
            return nil
        }

        switch rawToken {
        case "swift":
            return .swift
        case "json":
            return .json
        case "python", "py":
            return .python
        case "bash", "sh", "shell", "zsh":
            return .bash
        case "javascript", "js", "jsx", "mjs", "cjs":
            return .javascript
        case "typescript", "ts", "tsx", "mts", "cts":
            return .typescript
        case "c":
            return .c
        case "cpp", "c++", "cc", "cxx":
            return .cpp
        case "csharp", "c#", "cs":
            return .csharp
        case "css":
            return .css
        case "html", "htm":
            return .html
        case "xml", "xhtml", "svg":
            return .xml
        case "go", "golang":
            return .go
        case "regex", "regexp", "regular-expression", "regular-expressions":
            return .regex
        case "ruby", "rb":
            return .ruby
        case "rust", "rs":
            return .rust
        default:
            return nil
        }
    }

    var queryResourceName: String { rawValue }
}

struct SyntaxHighlightTheme: Hashable, Sendable {
    enum Style: Hashable, Sendable {
        case light
        case dark
    }

    let identifier: String
    let style: Style

    static func resolved(launchTheme: String?, colorScheme: ColorScheme) -> SyntaxHighlightTheme {
        if let launchTheme {
            let normalized = launchTheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else {
                return systemTheme(for: colorScheme)
            }
            let isDark = normalized.contains("dark")
                || normalized.contains("night")
                || normalized.contains("coal")
                || normalized.contains("navy")
                || normalized.contains("ayu")
            return SyntaxHighlightTheme(
                identifier: normalized,
                style: isDark ? .dark : .light
            )
        }

        return systemTheme(for: colorScheme)
    }

    private static func systemTheme(for colorScheme: ColorScheme) -> SyntaxHighlightTheme {
        let style: Style = colorScheme == .dark ? .dark : .light
        return SyntaxHighlightTheme(
            identifier: style == .dark ? "system-dark" : "system-light",
            style: style
        )
    }
}

enum MarkdownCodeBlockCatalog {
    nonisolated static func annotate(blocks: [MarkdownBlock], source: String) -> [MarkdownBlock] {
        let entries = scanFencedBlocks(source: source)
        var entryIndex = 0
        let annotated = blocks.map { annotate($0, entries: entries, entryIndex: &entryIndex) }
        if entryIndex != entries.count {
            reportDebugIssue("Unmatched fenced code blocks remained after renderer annotation.")
        }
        return annotated
    }

    private nonisolated static func annotate(
        _ block: MarkdownBlock,
        entries: [MarkdownCodeBlock],
        entryIndex: inout Int
    ) -> MarkdownBlock {
        let annotatedChildren = block.children.map { annotate($0, entries: entries, entryIndex: &entryIndex) }

        guard block.kind == .codeBlock else {
            return block.replacing(children: annotatedChildren)
        }

        let codeBlock: MarkdownCodeBlock
        if entries.indices.contains(entryIndex),
           entries[entryIndex].code == block.sourceText {
            codeBlock = entries[entryIndex]
            entryIndex += 1
        } else {
            codeBlock = MarkdownCodeBlock(
                code: block.sourceText,
                infoString: nil,
                rawLanguage: nil,
                language: nil,
                isFenced: false
            )
        }

        return block.replacing(children: annotatedChildren, codeBlock: codeBlock)
    }

    private nonisolated static func flattenCodeBlocks(in blocks: [MarkdownBlock]) -> [MarkdownBlock] {
        var flattened: [MarkdownBlock] = []
        for block in blocks {
            if block.kind == .codeBlock {
                flattened.append(block)
            }
            flattened.append(contentsOf: flattenCodeBlocks(in: block.children))
        }
        return flattened
    }

    private nonisolated static func scanFencedBlocks(source: String) -> [MarkdownCodeBlock] {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [MarkdownCodeBlock] = []
        var index = 0

        while index < lines.count {
            if let fenced = fencedBlock(in: lines, startingAt: index) {
                blocks.append(fenced.block)
                index = fenced.nextIndex
                continue
            }

            index += 1
        }

        return blocks
    }

    private nonisolated static func fencedBlock(
        in lines: [String],
        startingAt startIndex: Int
    ) -> (block: MarkdownCodeBlock, nextIndex: Int)? {
        guard lines.indices.contains(startIndex),
              let opening = openingFence(in: lines[startIndex]) else {
            return nil
        }

        var codeLines: [String] = []
        var index = startIndex + 1
        while index < lines.count {
            if isClosingFence(
                lines[index],
                marker: opening.marker,
                minimumCount: opening.count
            ) {
                break
            }
            codeLines.append(lines[index])
            index += 1
        }

        let code = codeLines.joined(separator: "\n").trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
        let infoString = opening.infoString?.isEmpty == false ? opening.infoString : nil
        let rawLanguage = infoString?
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init)
            .map { $0.lowercased() }

        let block = MarkdownCodeBlock(
            code: code,
            infoString: infoString,
            rawLanguage: rawLanguage,
            language: SyntaxHighlightLanguage.normalizedFenceLanguage(from: infoString),
            isFenced: true
        )

        return (block, min(index + 1, lines.count))
    }

    private nonisolated static func openingFence(in line: String) -> (marker: Character, count: Int, infoString: String?)? {
        let indentCount = line.prefix { $0 == " " }.count
        guard indentCount <= 3 else { return nil }

        let content = line.dropFirst(indentCount)
        guard let marker = content.first, marker == "`" || marker == "~" else {
            return nil
        }

        let fenceCount = content.prefix { $0 == marker }.count
        guard fenceCount >= 3 else { return nil }

        let info = String(content.dropFirst(fenceCount)).trimmingCharacters(in: .whitespaces)
        return (marker, fenceCount, info.isEmpty ? nil : info)
    }

    private nonisolated static func isClosingFence(
        _ line: String,
        marker: Character,
        minimumCount: Int
    ) -> Bool {
        let indentCount = line.prefix { $0 == " " }.count
        guard indentCount <= 3 else { return false }

        let content = line.dropFirst(indentCount)
        guard content.first == marker else { return false }

        let fenceCount = content.prefix { $0 == marker }.count
        guard fenceCount >= minimumCount else { return false }

        return content.dropFirst(fenceCount).allSatisfy(\.isWhitespace)
    }

    private nonisolated static func reportDebugIssue(_ message: String) {
        #if DEBUG
        fputs("SyntaxHighlighting: \(message)\n", stderr)
        #endif
    }
}

private struct SyntaxHighlightCacheKey: Hashable {
    let language: SyntaxHighlightLanguage
    let contentHash: String
    let themeIdentifier: String
}

private enum SyntaxHighlightTokenStyle: Hashable {
    case comment
    case keyword
    case string
    case number
    case type
    case function
    case property
    case variable
    case constant
    case tag
    case punctuation
    case `operator`

    init?(captureName: String) {
        switch captureName {
        case let value where value.hasPrefix("comment"):
            self = .comment
        case let value where value.hasPrefix("keyword"):
            self = .keyword
        case let value where value.hasPrefix("string"):
            self = .string
        case let value where value.hasPrefix("number"):
            self = .number
        case let value where value.hasPrefix("type"):
            self = .type
        case let value where value.hasPrefix("function"):
            self = .function
        case let value where value.hasPrefix("property"):
            self = .property
        case let value where value.hasPrefix("variable"):
            self = .variable
        case let value where value.hasPrefix("constant"):
            self = .constant
        case let value where value.hasPrefix("tag"):
            self = .tag
        case let value where value.hasPrefix("punctuation"):
            self = .punctuation
        case let value where value.hasPrefix("operator"):
            self = .operator
        default:
            return nil
        }
    }
}

private struct SyntaxHighlightTokenSpan: Hashable {
    let range: NSRange
    let style: SyntaxHighlightTokenStyle
}

private struct CachedHighlightedCodeBlock: Hashable {
    let tokenSpans: [SyntaxHighlightTokenSpan]
}

private final class HighlightedCodeBlockCache {
    static let shared = HighlightedCodeBlockCache()

    private var storage: [SyntaxHighlightCacheKey: CachedHighlightedCodeBlock] = [:]
    private let lock = NSLock()

    func value(for key: SyntaxHighlightCacheKey) -> CachedHighlightedCodeBlock? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    func insert(_ value: CachedHighlightedCodeBlock, for key: SyntaxHighlightCacheKey) {
        lock.lock()
        storage[key] = value
        lock.unlock()
    }

    func removeAll() {
        lock.lock()
        storage.removeAll()
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage.count
    }
}

private final class SyntaxHighlightingBundleMarker: NSObject {}

enum CodeBlockSyntaxHighlighter {
    private struct LanguageResources {
        let language: Language
        let query: Query
    }

    private static var resources: [SyntaxHighlightLanguage: LanguageResources] = [:]
    private static let resourcesLock = NSLock()

    static func highlightedAttributedText(
        for codeBlock: MarkdownCodeBlock,
        theme: SyntaxHighlightTheme,
        fontScale: CGFloat
    ) -> AttributedString? {
        guard codeBlock.isFenced, let language = codeBlock.language else {
            return nil
        }

        let key = SyntaxHighlightCacheKey(
            language: language,
            contentHash: sha256Hex(for: codeBlock.code),
            themeIdentifier: theme.identifier
        )

        let cached = HighlightedCodeBlockCache.shared.value(for: key) ?? {
            let value = CachedHighlightedCodeBlock(tokenSpans: highlightTokenSpans(for: codeBlock.code, language: language))
            HighlightedCodeBlockCache.shared.insert(value, for: key)
            return value
        }()

        return renderAttributedString(
            code: codeBlock.code,
            tokenSpans: cached.tokenSpans,
            theme: theme,
            fontScale: fontScale
        )
    }

    private static func highlightTokenSpans(
        for code: String,
        language: SyntaxHighlightLanguage
    ) -> [SyntaxHighlightTokenSpan] {
        guard let resources = loadResources(for: language) else {
            return []
        }

        let parser = Parser()
        do {
            try parser.setLanguage(resources.language)
        } catch {
            assertionFailure("Unable to configure parser for \(language.rawValue): \(error)")
            return []
        }

        guard let tree = parser.parse(code) else {
            return []
        }

        let cursor = resources.query.execute(in: tree)
        var spans: [SyntaxHighlightTokenSpan] = []
        while let capture = cursor.nextCapture() {
            guard let name = capture.name,
                  let style = SyntaxHighlightTokenStyle(captureName: name),
                  capture.range.length > 0 else {
                continue
            }
            spans.append(SyntaxHighlightTokenSpan(range: capture.range, style: style))
        }

        return spans.sorted {
            if $0.range.location != $1.range.location {
                return $0.range.location < $1.range.location
            }
            return $0.range.length > $1.range.length
        }
    }

    private static func loadResources(for language: SyntaxHighlightLanguage) -> LanguageResources? {
        resourcesLock.lock()
        defer { resourcesLock.unlock() }

        if let cached = resources[language] {
            return cached
        }

        guard let tsLanguage = treeSitterLanguage(for: language),
              let queryURL = queryURL(for: language) else {
            return nil
        }

        do {
            let query = try Query(language: tsLanguage, url: queryURL)
            let loaded = LanguageResources(language: tsLanguage, query: query)
            resources[language] = loaded
            return loaded
        } catch {
            assertionFailure("Unable to load highlight query for \(language.rawValue): \(error)")
            return nil
        }
    }

    private static func treeSitterLanguage(for language: SyntaxHighlightLanguage) -> Language? {
        switch language {
        case .swift:
            guard let pointer = tree_sitter_swift() else { return nil }
            return Language(pointer)
        case .json:
            guard let pointer = tree_sitter_json() else { return nil }
            return Language(pointer)
        case .python:
            guard let pointer = tree_sitter_python() else { return nil }
            return Language(pointer)
        case .bash:
            guard let pointer = tree_sitter_bash() else { return nil }
            return Language(pointer)
        case .javascript:
            guard let pointer = tree_sitter_javascript() else { return nil }
            return Language(pointer)
        case .typescript:
            guard let pointer = tree_sitter_typescript() else { return nil }
            return Language(pointer)
        case .c:
            guard let pointer = tree_sitter_c() else { return nil }
            return Language(pointer)
        case .cpp:
            guard let pointer = tree_sitter_cpp() else { return nil }
            return Language(pointer)
        case .csharp:
            guard let pointer = tree_sitter_c_sharp() else { return nil }
            return Language(pointer)
        case .css:
            guard let pointer = tree_sitter_css() else { return nil }
            return Language(pointer)
        case .html:
            guard let pointer = tree_sitter_html() else { return nil }
            return Language(pointer)
        case .xml:
            guard let pointer = tree_sitter_xml() else { return nil }
            return Language(pointer)
        case .go:
            guard let pointer = tree_sitter_go() else { return nil }
            return Language(pointer)
        case .regex:
            guard let pointer = tree_sitter_regex() else { return nil }
            return Language(pointer)
        case .ruby:
            guard let pointer = tree_sitter_ruby() else { return nil }
            return Language(pointer)
        case .rust:
            guard let pointer = tree_sitter_rust() else { return nil }
            return Language(pointer)
        }
    }

    private static func queryURL(for language: SyntaxHighlightLanguage) -> URL? {
        let fileName = language.queryResourceName
        let bundles = [Bundle(for: SyntaxHighlightingBundleMarker.self), Bundle.main] + Bundle.allFrameworks + Bundle.allBundles

        for bundle in bundles {
            if let direct = bundle.url(forResource: fileName, withExtension: "scm", subdirectory: "SyntaxHighlightingQueries") {
                return direct
            }
            if let direct = bundle.url(forResource: fileName, withExtension: "scm") {
                return direct
            }
            if let candidate = bundle.urls(forResourcesWithExtension: "scm", subdirectory: "SyntaxHighlightingQueries")?
                .first(where: { $0.lastPathComponent == "\(fileName).scm" }) {
                return candidate
            }
        }

        assertionFailure("Missing bundled syntax highlighting query for \(language.rawValue)")
        return nil
    }

    private static func sha256Hex(for code: String) -> String {
        let digest = SHA256.hash(data: Data(code.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func renderAttributedString(
        code: String,
        tokenSpans: [SyntaxHighlightTokenSpan],
        theme: SyntaxHighlightTheme,
        fontScale: CGFloat
    ) -> AttributedString {
        let palette = HighlightPalette(theme: theme)
        let rendered = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: monospacedBodyFont(fontScale: fontScale),
                .foregroundColor: palette.plainText,
            ]
        )

        for span in tokenSpans where NSMaxRange(span.range) <= rendered.length {
            rendered.addAttribute(.foregroundColor, value: palette.color(for: span.style), range: span.range)
        }

        return AttributedString(rendered)
    }

    private static func monospacedBodyFont(fontScale: CGFloat) -> HighlightPlatformFont {
        let pointSize = preferredBodyFont(fontScale: fontScale).pointSize
        return HighlightPlatformFont.monospacedSystemFont(ofSize: pointSize, weight: .regular)
    }

    private static func preferredBodyFont(fontScale: CGFloat) -> HighlightPlatformFont {
        let base = HighlightPlatformFont.preferredFont(forTextStyle: .body)
        return base.withSize(base.pointSize * fontScale)
    }

    static func resetCacheForTests() {
        HighlightedCodeBlockCache.shared.removeAll()
    }

    static func cachedEntryCountForTests() -> Int {
        HighlightedCodeBlockCache.shared.count
    }
}

private struct HighlightPalette {
    let plainText: HighlightPlatformColor
    let comment: HighlightPlatformColor
    let keyword: HighlightPlatformColor
    let string: HighlightPlatformColor
    let number: HighlightPlatformColor
    let type: HighlightPlatformColor
    let function: HighlightPlatformColor
    let property: HighlightPlatformColor
    let variable: HighlightPlatformColor
    let constant: HighlightPlatformColor
    let tag: HighlightPlatformColor
    let punctuation: HighlightPlatformColor
    let `operator`: HighlightPlatformColor

    init(theme: SyntaxHighlightTheme) {
        switch theme.style {
        case .light:
            plainText = HighlightPlatformColor.labelColorCompatible
            comment = .hex(0x6A737D)
            keyword = .hex(0x7C3AED)
            string = .hex(0x0F766E)
            number = .hex(0xB45309)
            type = .hex(0x1D4ED8)
            function = .hex(0xC2410C)
            property = .hex(0x0F766E)
            variable = HighlightPlatformColor.labelColorCompatible
            constant = .hex(0xBE123C)
            tag = .hex(0xB91C1C)
            punctuation = .hex(0x4B5563)
            `operator` = .hex(0x475569)
        case .dark:
            plainText = HighlightPlatformColor.labelColorCompatible
            comment = .hex(0x94A3B8)
            keyword = .hex(0xC084FC)
            string = .hex(0x5EEAD4)
            number = .hex(0xFBBF24)
            type = .hex(0x93C5FD)
            function = .hex(0xFB923C)
            property = .hex(0x67E8F9)
            variable = HighlightPlatformColor.labelColorCompatible
            constant = .hex(0xFDA4AF)
            tag = .hex(0xFCA5A5)
            punctuation = .hex(0xCBD5E1)
            `operator` = .hex(0xE2E8F0)
        }
    }

    func color(for style: SyntaxHighlightTokenStyle) -> HighlightPlatformColor {
        switch style {
        case .comment:
            return comment
        case .keyword:
            return keyword
        case .string:
            return string
        case .number:
            return number
        case .type:
            return type
        case .function:
            return function
        case .property:
            return property
        case .variable:
            return variable
        case .constant:
            return constant
        case .tag:
            return tag
        case .punctuation:
            return punctuation
        case .operator:
            return self.operator
        }
    }
}

private extension HighlightPlatformColor {
    static func hex(_ value: Int) -> HighlightPlatformColor {
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        #if os(macOS)
        return HighlightPlatformColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
        #elseif os(iOS)
        return HighlightPlatformColor(red: red, green: green, blue: blue, alpha: 1)
        #endif
    }

    static var labelColorCompatible: HighlightPlatformColor {
        #if os(macOS)
        return .labelColor
        #elseif os(iOS)
        return .label
        #endif
    }
}
