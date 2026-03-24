import Foundation
import SwiftUI

nonisolated enum MarkdownRenderer {
    private struct ResolvedContainer {
        let identity: String
        let kind: ContainerKind
    }

    private enum ContainerKind {
        case root
        case unorderedList(indentLevel: Int)
        case orderedList(indentLevel: Int)
        case blockquote(indentLevel: Int)
        case listItem(kind: MarkdownBlockKind, ordinal: Int?, indentLevel: Int)
        case paragraph
        case heading(level: Int)
        case codeBlock
        case thematicBreak
    }

    private final class BlockBuilder {
        let identity: String
        let kind: MarkdownBlockKind
        let indentLevel: Int
        var level: Int?
        var listItemIndex: Int?
        var isTaskItem = false
        var isTaskCompleted: Bool?
        var table: MarkdownTable?
        var image: MarkdownImage?
        var video: MarkdownVideo?
        var attributedText = AttributedString()
        var sourceText = ""
        var children: [BlockBuilder] = []

        init(
            identity: String,
            kind: MarkdownBlockKind,
            indentLevel: Int,
            level: Int? = nil,
            listItemIndex: Int? = nil,
            table: MarkdownTable? = nil,
            image: MarkdownImage? = nil,
            video: MarkdownVideo? = nil
        ) {
            self.identity = identity
            self.kind = kind
            self.indentLevel = indentLevel
            self.level = level
            self.listItemIndex = listItemIndex
            self.table = table
            self.image = image
            self.video = video
        }

        var canAbsorbParagraphText: Bool {
            kind == .unorderedListItem || kind == .orderedListItem || kind == .blockquote
        }
    }

    nonisolated static func blocks(from markdown: String) -> [MarkdownBlock] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        if let segmentedBlocks = segmentedBlocks(from: normalized) {
            return segmentedBlocks
        }
        return coreBlocks(from: normalized)
    }

    private nonisolated static func coreBlocks(from markdown: String) -> [MarkdownBlock] {
        let normalized = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        if let specialBlocks = standaloneSpecialBlocks(from: normalized, lines: lines) {
            return specialBlocks
        }

        let attributedInput = markdownRemovingInlineImages(normalized)
        if normalized.contains("!["),
           attributedInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || normalized.contains("!["),
               containsOnlyReferenceDefinitionsOrWhitespace(in: attributedInput) {
            return [emptyParagraph()]
        }
        if let attributed = try? AttributedString(markdown: attributedInput) {
            let parsed = attributedBlocks(from: attributed)
            if !parsed.isEmpty {
                return parsed
            }
        }

        return legacyBlocks(from: normalized)
    }

    nonisolated static func attributedText(for block: MarkdownBlock) -> AttributedString {
        if let attributedText = block.attributedText {
            return attributedText
        }
        return attributedText(for: block.sourceText)
    }

    nonisolated static func attributedText(for sourceText: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: sourceText,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(sourceText)
    }

    private nonisolated static func attributedBlocks(from attributed: AttributedString) -> [MarkdownBlock] {
        var roots: [BlockBuilder] = []
        var fallbackIndex = 0

        for run in attributed.runs {
            let substring = AttributedString(attributed[run.range])
            let text = String(substring.characters)

            if let intent = run.presentationIntent {
                appendRun(
                    substring,
                    text: text,
                    presentationIntent: intent,
                    roots: &roots
                )
                continue
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let fallback = BlockBuilder(identity: "fallback.\(fallbackIndex)", kind: .paragraph, indentLevel: 0)
            appendText(text, attributed: substring, to: fallback)
            roots.append(fallback)
            fallbackIndex += 1
        }

        var blockIndex = 0
        let blocks = roots.compactMap { buildBlock(from: $0, blockIndex: &blockIndex) }
        return blocks
    }

    private nonisolated static func appendRun(
        _ substring: AttributedString,
        text: String,
        presentationIntent: PresentationIntent,
        roots: inout [BlockBuilder]
    ) {
        let containers = resolvedContainers(from: presentationIntent)
        guard !containers.isEmpty else { return }

        var leafBuilder: BlockBuilder?
        var currentParent: BlockBuilder?

        for container in containers {
            switch container.kind {
            case .root:
                continue
            case .unorderedList, .orderedList:
                continue
            case let .listItem(kind, ordinal, indentLevel):
                let builder = findOrCreate(
                    identity: container.identity,
                    kind: kind,
                    indentLevel: indentLevel,
                    level: nil,
                    listItemIndex: kind == .orderedListItem ? ordinal : nil,
                    parent: currentParent,
                    roots: &roots
                )
                currentParent = builder
                leafBuilder = builder
            case let .blockquote(indentLevel):
                let builder = findOrCreate(
                    identity: container.identity,
                    kind: .blockquote,
                    indentLevel: indentLevel,
                    level: nil,
                    listItemIndex: nil,
                    parent: currentParent,
                    roots: &roots
                )
                currentParent = builder
                leafBuilder = builder
            case .paragraph:
                if let currentParent,
                   currentParent.canAbsorbParagraphText,
                   currentParent.children.isEmpty {
                    leafBuilder = currentParent
                    continue
                }
                let builder = findOrCreate(
                    identity: container.identity,
                    kind: .paragraph,
                    indentLevel: currentParent?.indentLevel ?? 0,
                    level: nil,
                    listItemIndex: nil,
                    parent: currentParent,
                    roots: &roots
                )
                currentParent = builder
                leafBuilder = builder
            case let .heading(level):
                let builder = findOrCreate(
                    identity: container.identity,
                    kind: .heading,
                    indentLevel: currentParent?.indentLevel ?? 0,
                    level: level,
                    listItemIndex: nil,
                    parent: currentParent,
                    roots: &roots
                )
                currentParent = builder
                leafBuilder = builder
            case .codeBlock:
                let builder = findOrCreate(
                    identity: container.identity,
                    kind: .codeBlock,
                    indentLevel: currentParent?.indentLevel ?? 0,
                    level: nil,
                    listItemIndex: nil,
                    parent: currentParent,
                    roots: &roots
                )
                currentParent = builder
                leafBuilder = builder
            case .thematicBreak:
                leafBuilder = findOrCreate(
                    identity: container.identity,
                    kind: .thematicBreak,
                    indentLevel: currentParent?.indentLevel ?? 0,
                    level: nil,
                    listItemIndex: nil,
                    parent: currentParent,
                    roots: &roots
                )
            }
        }

        guard let leafBuilder else { return }
        appendText(text, attributed: substring, to: leafBuilder)
    }

    private nonisolated static func resolvedContainers(from presentationIntent: PresentationIntent) -> [ResolvedContainer] {
        var containers: [ResolvedContainer] = [ResolvedContainer(identity: "root", kind: .root)]
        var pendingList: [ResolvedContainer] = []
        var listDepth = 0

        for component in Array(presentationIntent.components).reversed() {
            switch component.kind {
            case .unorderedList:
                pendingList.append(
                    ResolvedContainer(
                        identity: "unorderedList.\(component.identity)",
                        kind: .unorderedList(indentLevel: listDepth)
                    )
                )
            case .orderedList:
                pendingList.append(
                    ResolvedContainer(
                        identity: "orderedList.\(component.identity)",
                        kind: .orderedList(indentLevel: listDepth)
                    )
                )
            case let .listItem(ordinal):
                let listContainer = pendingList.popLast() ?? ResolvedContainer(
                    identity: "unorderedList.synthetic.\(component.identity)",
                    kind: .unorderedList(indentLevel: listDepth)
                )
                let kind: MarkdownBlockKind
                let indentLevel: Int
                switch listContainer.kind {
                case let .orderedList(level):
                    kind = .orderedListItem
                    indentLevel = level
                case let .unorderedList(level):
                    kind = .unorderedListItem
                    indentLevel = level
                default:
                    kind = .unorderedListItem
                    indentLevel = listDepth
                }
                containers.append(
                    ResolvedContainer(
                        identity: "listItem.\(component.identity)",
                        kind: .listItem(kind: kind, ordinal: ordinal, indentLevel: indentLevel)
                    )
                )
                listDepth += 1
            case .blockQuote:
                containers.append(
                    ResolvedContainer(
                        identity: "blockquote.\(component.identity)",
                        kind: .blockquote(indentLevel: max(0, listDepth - 1))
                    )
                )
            case .paragraph:
                containers.append(
                    ResolvedContainer(
                        identity: "paragraph.\(component.identity)",
                        kind: .paragraph
                    )
                )
            case let .header(level):
                containers.append(
                    ResolvedContainer(
                        identity: "heading.\(component.identity)",
                        kind: .heading(level: level)
                    )
                )
            case .codeBlock:
                containers.append(
                    ResolvedContainer(
                        identity: "codeBlock.\(component.identity)",
                        kind: .codeBlock
                    )
                )
            case .thematicBreak:
                containers.append(
                    ResolvedContainer(
                        identity: "thematicBreak.\(component.identity)",
                        kind: .thematicBreak
                    )
                )
            default:
                break
            }
        }

        return containers
    }

    private nonisolated static func findOrCreate(
        identity: String,
        kind: MarkdownBlockKind,
        indentLevel: Int,
        level: Int?,
        listItemIndex: Int?,
        parent: BlockBuilder?,
        roots: inout [BlockBuilder]
    ) -> BlockBuilder {
        if let parent {
            if let existing = parent.children.first(where: { $0.identity == identity }) {
                return existing
            }
            let created = BlockBuilder(
                identity: identity,
                kind: kind,
                indentLevel: indentLevel,
                level: level,
                listItemIndex: listItemIndex
            )
            parent.children.append(created)
            return created
        }

        if let existing = roots.first(where: { $0.identity == identity }) {
            return existing
        }

        let created = BlockBuilder(
            identity: identity,
            kind: kind,
            indentLevel: indentLevel,
            level: level,
            listItemIndex: listItemIndex
        )
        roots.append(created)
        return created
    }

    private nonisolated static func appendText(_ text: String, attributed: AttributedString, to builder: BlockBuilder) {
        switch builder.kind {
        case .codeBlock:
            builder.sourceText += text
        case .thematicBreak:
            return
        default:
            builder.attributedText.append(attributed)
            builder.sourceText += text
        }
    }

    private nonisolated static func buildBlock(from builder: BlockBuilder, blockIndex: inout Int) -> MarkdownBlock? {
        let sourceText: String
        let plainText: String
        let attributedText: AttributedString?
        let children = builder.children.compactMap { buildBlock(from: $0, blockIndex: &blockIndex) }

        switch builder.kind {
        case .codeBlock:
            sourceText = builder.sourceText.trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
            plainText = sourceText
            attributedText = nil
        case .thematicBreak:
            sourceText = ""
            plainText = ""
            attributedText = nil
        case .image, .animatedImage, .video:
            sourceText = builder.sourceText
            plainText = ""
            attributedText = nil
        case .rawHTML:
            sourceText = builder.sourceText
            plainText = htmlVisibleText(from: sourceText)
            attributedText = nil
        default:
            sourceText = builder.sourceText
            attributedText = builder.attributedText.characters.isEmpty ? nil : builder.attributedText
            plainText = visibleText(from: sourceText, attributedText: attributedText)
        }

        let taskState: (Bool, Bool?, AttributedString, String)
        if builder.kind == .unorderedListItem || builder.kind == .orderedListItem {
            taskState = parseTaskMarker(in: sourceText)
        } else {
            taskState = (false, nil, attributedText ?? AttributedString(sourceText), sourceText)
        }

        let effectiveSourceText = taskState.3
        let effectivePlainText: String
        if builder.kind == .rawHTML {
            effectivePlainText = plainText
        } else if builder.kind == .image || builder.kind == .animatedImage || builder.kind == .video || builder.kind == .thematicBreak {
            effectivePlainText = plainText
        } else if taskState.0 {
            effectivePlainText = normalizeVisibleText(String(taskState.2.characters))
        } else {
            effectivePlainText = plainText
        }

        let effectiveAttributedText: AttributedString?
        if taskState.0 {
            effectiveAttributedText = taskState.2
        } else {
            effectiveAttributedText = attributedText
        }

        defer { blockIndex += 1 }
        return MarkdownBlock(
            id: "block.\(blockIndex)",
            kind: builder.kind,
            plainText: effectivePlainText,
            sourceText: effectiveSourceText,
            level: builder.level,
            listItemIndex: builder.listItemIndex,
            indentLevel: builder.indentLevel,
            isTaskItem: taskState.0,
            isTaskCompleted: taskState.1,
            table: builder.table,
            image: builder.image,
            video: builder.video,
            attributedText: effectiveAttributedText,
            children: children
        )
    }

    private nonisolated static func normalizedPlainText(from sourceText: String) -> String {
        let normalized = normalizeVisibleText(sourceText)
        return normalized == "⸻" ? "" : normalized
    }

    private nonisolated static func visibleText(from sourceText: String, attributedText: AttributedString?) -> String {
        if sourceText.contains("<!") || sourceText.contains("<?") {
            return htmlVisibleText(from: sourceText)
        }

        if sourceText.contains("&"),
           let attributedText,
           String(attributedText.characters).contains("\u{FFFD}") {
            return normalizedPlainText(from: sourceText)
        }

        if let attributedText {
            let normalized = normalizeVisibleText(String(attributedText.characters))
            if !normalized.isEmpty || sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return normalized == "⸻" ? "" : normalized
            }
        }

        if sourceText.contains("<"), containsHTMLTag(in: sourceText) {
            return htmlVisibleText(from: sourceText)
        }

        return normalizedPlainText(from: sourceText)
    }

    private nonisolated static func standaloneSpecialBlocks(from markdown: String, lines: [String]) -> [MarkdownBlock]? {
        let imageReferences = imageReferenceDefinitions(from: lines)
        let meaningfulLines = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !isReferenceDefinitionLine($0) }

        if meaningfulLines.count == 1,
           let image = imageBlock(from: meaningfulLines[0], references: imageReferences) {
            return [
                MarkdownBlock(
                    id: "block.0",
                    kind: .image,
                    plainText: "",
                    sourceText: meaningfulLines[0],
                    level: nil,
                    listItemIndex: nil,
                    indentLevel: 0,
                    isTaskItem: false,
                    isTaskCompleted: nil,
                    table: nil,
                    image: image,
                    video: nil,
                    attributedText: nil,
                    children: []
                )
            ]
        }

        if meaningfulLines.count == 1,
           let video = videoBlock(from: meaningfulLines[0]) {
            return [
                MarkdownBlock(
                    id: "block.0",
                    kind: .video,
                    plainText: "",
                    sourceText: meaningfulLines[0],
                    level: nil,
                    listItemIndex: nil,
                    indentLevel: 0,
                    isTaskItem: false,
                    isTaskCompleted: nil,
                    table: nil,
                    image: nil,
                    video: video,
                    attributedText: nil,
                    children: []
                )
            ]
        }

        if isHTMLOnlyDocument(markdown) {
            return [
                MarkdownBlock(
                    id: "block.0",
                    kind: .rawHTML,
                    plainText: htmlVisibleText(from: markdown),
                    sourceText: markdown.trimmingCharacters(in: .newlines),
                    level: nil,
                    listItemIndex: nil,
                    indentLevel: 0,
                    isTaskItem: false,
                    isTaskCompleted: nil,
                    table: nil,
                    image: nil,
                    video: nil,
                    attributedText: nil,
                    children: []
                )
            ]
        }

        return nil
    }

    private nonisolated static func segmentedBlocks(from markdown: String) -> [MarkdownBlock]? {
        let lines = markdown.components(separatedBy: "\n")
        let imageReferences = imageReferenceDefinitions(from: lines)
        var foundSpecialBlock = false
        var blocks: [MarkdownBlock] = []
        var markdownBuffer: [String] = []
        var blockIndex = 0
        var lineIndex = 0

        func appendCoreBlocks(from bufferedLines: [String]) {
            guard !bufferedLines.isEmpty else { return }
            let chunk = bufferedLines.joined(separator: "\n")
            let chunkBlocks = coreBlocks(from: chunk)
            for block in chunkBlocks where !(block.kind == .paragraph && block.plainText.isEmpty && block.children.isEmpty) {
                blocks.append(
                    MarkdownBlock(
                        id: "block.\(blockIndex)",
                        kind: block.kind,
                        plainText: block.plainText,
                        sourceText: block.sourceText,
                        level: block.level,
                        listItemIndex: block.listItemIndex,
                        indentLevel: block.indentLevel,
                        isTaskItem: block.isTaskItem,
                        isTaskCompleted: block.isTaskCompleted,
                        table: block.table,
                        image: block.image,
                        video: block.video,
                        attributedText: block.attributedText,
                        children: block.children
                    )
                )
                blockIndex += 1
            }
        }

        while lineIndex < lines.count {
            if let referenceRange = potentialReferenceDefinitionRange(in: lines, at: lineIndex) {
                markdownBuffer.append(contentsOf: lines[lineIndex..<referenceRange])
                lineIndex = referenceRange
                continue
            }

            if let htmlBlock = htmlBlock(in: lines, at: lineIndex) {
                foundSpecialBlock = true
                appendCoreBlocks(from: markdownBuffer)
                markdownBuffer.removeAll()
                let sourceText = htmlBlock.lines.joined(separator: "\n")
                blocks.append(
                    MarkdownBlock(
                        id: "block.\(blockIndex)",
                        kind: .rawHTML,
                        plainText: htmlVisibleText(from: sourceText),
                        sourceText: sourceText,
                        level: nil,
                        listItemIndex: nil,
                        indentLevel: 0,
                        isTaskItem: false,
                        isTaskCompleted: nil,
                        table: nil,
                        image: nil,
                        video: nil,
                        attributedText: nil,
                        children: []
                    )
                )
                blockIndex += 1
                lineIndex = htmlBlock.nextIndex
                continue
            }

            let trimmed = lines[lineIndex].trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty,
               let image = imageBlock(from: trimmed, references: imageReferences) {
                foundSpecialBlock = true
                appendCoreBlocks(from: markdownBuffer)
                markdownBuffer.removeAll()
                blocks.append(
                    MarkdownBlock(
                        id: "block.\(blockIndex)",
                        kind: .image,
                        plainText: "",
                        sourceText: trimmed,
                        level: nil,
                        listItemIndex: nil,
                        indentLevel: 0,
                        isTaskItem: false,
                        isTaskCompleted: nil,
                        table: nil,
                        image: image,
                        video: nil,
                        attributedText: nil,
                        children: []
                    )
                )
                blockIndex += 1
                lineIndex += 1
                continue
            }

            if !trimmed.isEmpty,
               let video = videoBlock(from: trimmed) {
                foundSpecialBlock = true
                appendCoreBlocks(from: markdownBuffer)
                markdownBuffer.removeAll()
                blocks.append(
                    MarkdownBlock(
                        id: "block.\(blockIndex)",
                        kind: .video,
                        plainText: "",
                        sourceText: trimmed,
                        level: nil,
                        listItemIndex: nil,
                        indentLevel: 0,
                        isTaskItem: false,
                        isTaskCompleted: nil,
                        table: nil,
                        image: nil,
                        video: video,
                        attributedText: nil,
                        children: []
                    )
                )
                blockIndex += 1
                lineIndex += 1
                continue
            }

            if let tableMatch = table(from: lines, at: lineIndex) {
                foundSpecialBlock = true
                appendCoreBlocks(from: markdownBuffer)
                markdownBuffer.removeAll()
                blocks.append(tableBlock(from: tableMatch, id: "block.\(blockIndex)"))
                blockIndex += 1
                lineIndex = tableMatch.nextIndex
                continue
            }

            markdownBuffer.append(lines[lineIndex])
            lineIndex += 1
        }

        guard foundSpecialBlock else { return nil }
        appendCoreBlocks(from: markdownBuffer)
        return blocks
    }

    private nonisolated static func emptyParagraph() -> MarkdownBlock {
        MarkdownBlock(
            id: "block.0",
            kind: .paragraph,
            plainText: "",
            sourceText: "",
            level: nil,
            listItemIndex: nil,
            indentLevel: 0,
            isTaskItem: false,
            isTaskCompleted: nil,
            table: nil,
            image: nil,
            video: nil,
            attributedText: nil,
            children: []
        )
    }

    private nonisolated static func normalizeVisibleText(_ text: String) -> String {
        text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func containsHTMLTag(in source: String) -> Bool {
        source.range(
            of: #"<(?:/?[A-Za-z][A-Za-z0-9-]*(?=[\s>/])[^>]*|![A-Za-z-]+[^>]*|\?[A-Za-z][^>]*|!--[^>]*--)>"#,
            options: .regularExpression
        ) != nil
    }

    private nonisolated static func isHTMLOnlyDocument(_ markdown: String) -> Bool {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !lines.isEmpty,
              lines.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).hasPrefix("<") }),
              trimmed.hasPrefix("<"),
              trimmed.hasSuffix(">") || trimmed.contains("\n") else {
            return false
        }
        return containsHTMLTag(in: trimmed)
    }

    private nonisolated static func htmlBlock(in lines: [String], at startIndex: Int) -> (lines: [String], nextIndex: Int)? {
        let line = lines[startIndex]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("<!--") {
            return collectHTMLBlock(in: lines, at: startIndex, until: "-->")
        }
        if trimmed.hasPrefix("<?") {
            return collectHTMLBlock(in: lines, at: startIndex, until: "?>")
        }
        if trimmed.hasPrefix("<![CDATA[") {
            return collectHTMLBlock(in: lines, at: startIndex, until: "]]>")
        }
        if trimmed.hasPrefix("<!"),
           containsHTMLTag(in: trimmed) {
            return ([line], startIndex + 1)
        }

        let lowercased = trimmed.lowercased()
        for rawTag in ["script", "pre", "style", "textarea"] {
            let tag = "<\(rawTag)"
            if lowercased.hasPrefix(tag) {
                return collectHTMLBlock(in: lines, at: startIndex, untilClosingTag: rawTag)
            }
        }

        if lowercased.range(of: #"^</?[a-z][a-z0-9-]*(?=[\s>/])[^>]*>$"#, options: .regularExpression) != nil {
            var endIndex = startIndex + 1
            while endIndex < lines.count,
                  !lines[endIndex].trimmingCharacters(in: .whitespaces).isEmpty {
                endIndex += 1
            }
            return (Array(lines[startIndex..<endIndex]), endIndex)
        }

        return nil
    }

    private nonisolated static func collectHTMLBlock(in lines: [String], at startIndex: Int, until terminator: String) -> (lines: [String], nextIndex: Int) {
        var endIndex = startIndex
        while endIndex < lines.count {
            if lines[endIndex].contains(terminator) {
                return (Array(lines[startIndex...endIndex]), endIndex + 1)
            }
            endIndex += 1
        }
        return (Array(lines[startIndex..<lines.count]), lines.count)
    }

    private nonisolated static func collectHTMLBlock(in lines: [String], at startIndex: Int, untilClosingTag tagName: String) -> (lines: [String], nextIndex: Int) {
        let terminator = "</\(tagName)"
        var endIndex = startIndex
        while endIndex < lines.count {
            if lines[endIndex].lowercased().contains(terminator) {
                return (Array(lines[startIndex...endIndex]), endIndex + 1)
            }
            endIndex += 1
        }
        return (Array(lines[startIndex..<lines.count]), lines.count)
    }

    private nonisolated static func htmlVisibleText(from source: String) -> String {
        let stripped = source
            .replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<\?[\s\S]*?\?>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<!\[CDATA\[[\s\S]*?\]\]>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<!DOCTYPE[^>]*>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<![^>]*>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        return normalizeVisibleText(stripped)
    }

    private nonisolated static func parseTaskMarker(in text: String) -> (Bool, Bool?, AttributedString, String) {
        guard text.count >= 4 else {
            return (false, nil, AttributedString(text), text)
        }
        let characters = Array(text)
        guard characters[0] == "[",
              characters[2] == "]",
              characters[3] == " " else {
            return (false, nil, AttributedString(text), text)
        }
        let remainder = String(characters.dropFirst(4))
        switch characters[1].lowercased() {
        case " ":
            return (true, false, AttributedString(remainder), remainder)
        case "x":
            return (true, true, AttributedString(remainder), remainder)
        default:
            return (false, nil, AttributedString(text), text)
        }
    }

    private nonisolated static func isReferenceDefinitionLine(_ line: String) -> Bool {
        let pattern = #"^\[[^\]]+\]:"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    private nonisolated static func potentialReferenceDefinitionRange(in lines: [String], at startIndex: Int) -> Int? {
        let line = lines[startIndex]
        let indentation = line.prefix { $0 == " " || $0 == "\t" }.count
        guard indentation < 4 else { return nil }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard isReferenceDefinitionLine(trimmed) else { return nil }

        var index = startIndex + 1
        while index < lines.count {
            let continuation = lines[index]
            let continuationTrimmed = continuation.trimmingCharacters(in: .whitespaces)
            if continuationTrimmed.isEmpty {
                break
            }
            if continuation.hasPrefix(" ") || continuation.hasPrefix("\t") || continuationTrimmed.hasPrefix("<") || continuationTrimmed.hasPrefix("'") || continuationTrimmed.hasPrefix("\"") || !continuationTrimmed.hasPrefix("[") {
                index += 1
                continue
            }
            break
        }

        return index
    }

    private nonisolated static func containsOnlyReferenceDefinitionsOrWhitespace(in markdown: String) -> Bool {
        let lines = markdown.components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }
            guard let nextIndex = potentialReferenceDefinitionRange(in: lines, at: index) else {
                return false
            }
            index = nextIndex
        }

        return true
    }

    private nonisolated static func imageReferenceDefinitions(from lines: [String]) -> [String: MarkdownImage] {
        var definitions: [String: MarkdownImage] = [:]
        let pattern = #"^\[([^\]]+)\]:\s+(\S+)(?:\s+"([^"]*)")?\s*$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            guard let match = regex?.firstMatch(in: line, range: range),
                  match.numberOfRanges >= 3,
                  let labelRange = Range(match.range(at: 1), in: line),
                  let sourceRange = Range(match.range(at: 2), in: line) else {
                continue
            }
            let titleRange = Range(match.range(at: 3), in: line)
            let label = normalizedInlineText(String(line[labelRange])).lowercased()
            definitions[label] = MarkdownImage(
                altText: "",
                sourceURL: String(line[sourceRange]),
                title: titleRange.map { String(line[$0]) },
                resolvedURL: nil
            )
        }
        return definitions
    }

    private nonisolated static func imageBlock(from line: String, references: [String: MarkdownImage]) -> MarkdownImage? {
        if let direct = directImage(from: line) {
            return direct
        }

        let pattern = #"^!\[([^\]]*)\](?:(?:\[\])|(?:\[([^\]]*)\]))?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, range: range),
              let altRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let rawAlt = String(line[altRange])
        let altText = normalizedInlineText(rawAlt)
        let label: String
        if let explicitLabelRange = Range(match.range(at: 2), in: line) {
            label = normalizedInlineText(String(line[explicitLabelRange])).lowercased()
        } else {
            label = altText.lowercased()
        }
        guard let definition = references[label] else {
            return nil
        }
        return MarkdownImage(
            altText: altText,
            sourceURL: definition.sourceURL,
            title: definition.title,
            resolvedURL: nil
        )
    }

    private nonisolated static func directImage(from line: String) -> MarkdownImage? {
        let pattern = #"^!\[([^\]]*)\]\((\S+?)(?:\s+"([^"]*)")?\)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, range: range),
              let altRange = Range(match.range(at: 1), in: line),
              let sourceRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        let titleRange = Range(match.range(at: 3), in: line)
        return MarkdownImage(
            altText: normalizedInlineText(String(line[altRange])),
            sourceURL: String(line[sourceRange]),
            title: titleRange.map { String(line[$0]) },
            resolvedURL: nil
        )
    }

    private nonisolated static func videoBlock(from line: String) -> MarkdownVideo? {
        let pattern = #"^!video\[([^\]]*)\]\((\S+?)(?:\s+"([^"]*)")?\)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, range: range),
              let altRange = Range(match.range(at: 1), in: line),
              let sourceRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let sourceURL = String(line[sourceRange])
        guard isLocalMediaReference(sourceURL) else { return nil }

        let titleRange = Range(match.range(at: 3), in: line)
        return MarkdownVideo(
            altText: normalizedInlineText(String(line[altRange])),
            sourceURL: sourceURL,
            title: titleRange.map { String(line[$0]) },
            resolvedURL: nil
        )
    }

    private nonisolated static func isLocalMediaReference(_ sourceURL: String) -> Bool {
        !(sourceURL.contains("://") || sourceURL.lowercased().hasPrefix("data:"))
    }

    private nonisolated static func normalizedInlineText(_ source: String) -> String {
        if let attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            let rendered = String(attributed.characters)
            if source.contains("&"), rendered.contains("\u{FFFD}") {
                return normalizeVisibleText(source)
            }
            return normalizeVisibleText(rendered)
        }
        return normalizeVisibleText(source)
    }

    private nonisolated static func markdownRemovingInlineImages(_ source: String) -> String {
        let patterns = [
            #"\[\!\[[^\]]*\]\([^)]+\)\]\([^)]+\)"#,
            #"\[\!\[[^\]]*\]\([^)]+\)\]\[[^\]]+\]"#,
            #"!\[[^\]]*\]\([^)\n]*\)"#,
            #"!\[[^\]]*\]\[\]"#,
            #"!\[[^\]]*\]\[[^\]]*\]"#
        ]
        return patterns.reduce(source) { partial, pattern in
            partial.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
    }

    private nonisolated static func legacyBlocks(from markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: "\n")
        let imageReferences = imageReferenceDefinitions(from: lines)
        var blocks: [MarkdownBlock] = []
        var index = 0
        var blockIndex = 0

        func nextID() -> String {
            defer { blockIndex += 1 }
            return "block.\(blockIndex)"
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || isReferenceDefinitionLine(trimmed) {
                index += 1
                continue
            }

            if let image = imageBlock(from: trimmed, references: imageReferences) {
                blocks.append(
                    MarkdownBlock(
                        id: nextID(),
                        kind: .image,
                        plainText: "",
                        sourceText: trimmed,
                        level: nil,
                        listItemIndex: nil,
                        indentLevel: 0,
                        isTaskItem: false,
                        isTaskCompleted: nil,
                        table: nil,
                        image: image,
                        video: nil,
                        attributedText: nil,
                        children: []
                    )
                )
                index += 1
                continue
            }

            if let video = videoBlock(from: trimmed) {
                blocks.append(
                    MarkdownBlock(
                        id: nextID(),
                        kind: .video,
                        plainText: "",
                        sourceText: trimmed,
                        level: nil,
                        listItemIndex: nil,
                        indentLevel: 0,
                        isTaskItem: false,
                        isTaskCompleted: nil,
                        table: nil,
                        image: nil,
                        video: video,
                        attributedText: nil,
                        children: []
                    )
                )
                index += 1
                continue
            }

            if let tableMatch = table(from: lines, at: index) {
                blocks.append(tableBlock(from: tableMatch, id: nextID()))
                index = tableMatch.nextIndex
                continue
            }

            let normalizedText: String
            if trimmed.hasPrefix("<"), containsHTMLTag(in: trimmed) {
                normalizedText = htmlVisibleText(from: trimmed)
            } else {
                normalizedText = normalizedInlineText(trimmed)
            }

            blocks.append(
                MarkdownBlock(
                    id: nextID(),
                    kind: trimmed.hasPrefix("<") && containsHTMLTag(in: trimmed) ? .rawHTML : .paragraph,
                    plainText: normalizedText,
                    sourceText: trimmed,
                    level: nil,
                    listItemIndex: nil,
                    indentLevel: 0,
                    isTaskItem: false,
                    isTaskCompleted: nil,
                    table: nil,
                    image: nil,
                    video: nil,
                    attributedText: trimmed.hasPrefix("<") ? nil : attributedText(for: trimmed),
                    children: []
                )
            )
            index += 1
        }

        return blocks.isEmpty ? [emptyParagraph()] : blocks
    }

    private nonisolated static func table(from lines: [String], at index: Int) -> (header: [String], alignments: [MarkdownTableAlignment], rows: [[String]], nextIndex: Int)? {
        guard index + 1 < lines.count else { return nil }
        guard let header = splitTableRow(lines[index]), !header.isEmpty else { return nil }
        guard let alignments = parseTableDivider(lines[index + 1]), alignments.count == header.count else { return nil }

        var rows: [[String]] = []
        var cursor = index + 2
        while cursor < lines.count {
            guard let row = splitTableRow(lines[cursor]), row.count == header.count else { break }
            rows.append(row)
            cursor += 1
        }
        return (header, alignments, rows, cursor)
    }

    private nonisolated static func splitTableRow(_ line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return nil }
        var content = trimmed
        if content.hasPrefix("|") {
            content.removeFirst()
        }
        if content.hasSuffix("|") {
            content.removeLast()
        }
        let cells = content.split(separator: "|", omittingEmptySubsequences: false).map {
            normalizedInlineText(String($0).trimmingCharacters(in: .whitespaces))
        }
        return cells.contains(where: { !$0.isEmpty }) ? cells : nil
    }

    private nonisolated static func parseTableDivider(_ line: String) -> [MarkdownTableAlignment]? {
        guard let cells = splitTableRow(line) else { return nil }
        var alignments: [MarkdownTableAlignment] = []
        for cell in cells {
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 3 else { return nil }
            let core = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            guard !core.isEmpty, core.allSatisfy({ $0 == "-" }) else { return nil }
            let alignment: MarkdownTableAlignment
            switch (trimmed.hasPrefix(":"), trimmed.hasSuffix(":")) {
            case (true, true):
                alignment = .center
            case (false, true):
                alignment = .trailing
            default:
                alignment = .leading
            }
            alignments.append(alignment)
        }
        return alignments
    }

    private nonisolated static func tableBlock(
        from tableMatch: (header: [String], alignments: [MarkdownTableAlignment], rows: [[String]], nextIndex: Int),
        id: String
    ) -> MarkdownBlock {
        let tableText = ([tableMatch.header] + tableMatch.rows)
            .flatMap { $0 }
            .joined(separator: " ")
        return MarkdownBlock(
            id: id,
            kind: .table,
            plainText: normalizeVisibleText(tableText),
            sourceText: "",
            level: nil,
            listItemIndex: nil,
            indentLevel: 0,
            isTaskItem: false,
            isTaskCompleted: nil,
            table: MarkdownTable(
                alignments: tableMatch.alignments,
                header: tableMatch.header,
                rows: tableMatch.rows
            ),
            image: nil,
            video: nil,
            attributedText: nil,
            children: []
        )
    }
}
