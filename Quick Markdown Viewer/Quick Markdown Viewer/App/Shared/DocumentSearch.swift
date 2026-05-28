import Foundation

nonisolated enum DocumentSearchScope: String, CaseIterable, Sendable {
    case currentDocument
    case allDocuments

    var title: String {
        switch self {
        case .currentDocument:
            return "Document"
        case .allDocuments:
            return "All"
        }
    }
}

nonisolated struct DocumentSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let path: WorkspacePath
    let fileName: String
    let blockID: String
    let lineNumber: Int
    let snippet: String
}

nonisolated enum DocumentSearchEngine {
    static func results(
        query: String,
        path: WorkspacePath,
        fileName: String,
        documentText: String,
        blocks: [MarkdownBlock]
    ) -> [DocumentSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.isEmpty == false else { return [] }

        var results: [DocumentSearchResult] = []
        let flattenedBlocks = flattenedBlocks(blocks)
        let lineIndex = DocumentLineIndex(text: documentText)
        let blockStartLines = startLines(for: flattenedBlocks, in: documentText, lineIndex: lineIndex)

        for block in flattenedBlocks {
            let text = block.plainText
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(
                    of: normalizedQuery,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchStart..<text.endIndex
                  ) {
                let lineOffset = text[..<range.lowerBound].reduce(0) { count, character in
                    character == "\n" ? count + 1 : count
                }
                let offset = text.distance(from: text.startIndex, to: range.lowerBound)
                results.append(
                    DocumentSearchResult(
                        id: "\(path.rawValue)|\(block.id)|\(offset)",
                        path: path,
                        fileName: fileName,
                        blockID: block.id,
                        lineNumber: (blockStartLines[block.id] ?? 1) + lineOffset,
                        snippet: snippet(from: text, around: range)
                    )
                )
                searchStart = range.upperBound
            }
        }
        return results
    }

    private struct DocumentLineIndex {
        let lineStarts: [String.Index]

        init(text: String) {
            var starts = [text.startIndex]
            var index = text.startIndex
            while index < text.endIndex {
                if text[index] == "\n" {
                    starts.append(text.index(after: index))
                }
                text.formIndex(after: &index)
            }
            lineStarts = starts
        }

        func lineNumber(at index: String.Index) -> Int {
            var low = 0
            var high = lineStarts.count
            while low < high {
                let mid = (low + high) / 2
                if lineStarts[mid] <= index {
                    low = mid + 1
                } else {
                    high = mid
                }
            }
            return max(1, low)
        }
    }

    private static func startLines(
        for blocks: [MarkdownBlock],
        in documentText: String,
        lineIndex: DocumentLineIndex
    ) -> [String: Int] {
        guard documentText.isEmpty == false else { return [:] }

        var startLines: [String: Int] = [:]
        var searchStart = documentText.startIndex
        for block in blocks {
            guard let range = sourceRange(
                for: block,
                in: documentText,
                searchStart: searchStart
            ) else {
                continue
            }
            startLines[block.id] = lineIndex.lineNumber(at: range.lowerBound)
            searchStart = range.upperBound
        }
        return startLines
    }

    private static func sourceRange(
        for block: MarkdownBlock,
        in documentText: String,
        searchStart: String.Index
    ) -> Range<String.Index>? {
        let candidates = [block.sourceText, block.plainText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        for candidate in candidates {
            if let range = documentText.range(of: candidate, range: searchStart..<documentText.endIndex) {
                return range
            }
            if let range = documentText.range(of: candidate) {
                return range
            }
        }
        return nil
    }

    private static func flattenedBlocks(_ blocks: [MarkdownBlock]) -> [MarkdownBlock] {
        var flattened: [MarkdownBlock] = []
        for block in blocks {
            flattened.append(block)
            flattened.append(contentsOf: flattenedBlocks(block.children))
        }
        return flattened
    }

    private static func snippet(from text: String, around range: Range<String.Index>) -> String {
        let leadingStart = text.index(range.lowerBound, offsetBy: -48, limitedBy: text.startIndex) ?? text.startIndex
        let trailingEnd = text.index(range.upperBound, offsetBy: 72, limitedBy: text.endIndex) ?? text.endIndex
        let rawSnippet = text[leadingStart..<trailingEnd]
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return rawSnippet.isEmpty ? text : rawSnippet
    }
}
