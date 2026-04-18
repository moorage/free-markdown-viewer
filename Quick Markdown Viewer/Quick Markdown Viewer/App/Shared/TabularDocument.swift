import CoreGraphics
import Foundation

enum TabularWrapMode: String, Codable, Sendable {
    case wrap
    case clip
}

struct TabularDocumentPresentation: Equatable, Sendable {
    static let minimumColumnWidth: CGFloat = 120
    static let maximumColumnWidth: CGFloat = 360
    static let minimumRowHeight: CGFloat = 36
    static let maximumRowHeight: CGFloat = 180
    static let columnWidthStep: CGFloat = 20
    static let rowHeightStep: CGFloat = 12

    var wrapMode: TabularWrapMode = .wrap
    var columnWidth: CGFloat = 200
    var rowHeight: CGFloat = 72

    mutating func toggleWrapMode() {
        wrapMode = wrapMode == .wrap ? .clip : .wrap
    }

    mutating func increaseColumnWidth() {
        columnWidth = min(columnWidth + Self.columnWidthStep, Self.maximumColumnWidth)
    }

    mutating func decreaseColumnWidth() {
        columnWidth = max(columnWidth - Self.columnWidthStep, Self.minimumColumnWidth)
    }

    mutating func increaseRowHeight() {
        rowHeight = min(rowHeight + Self.rowHeightStep, Self.maximumRowHeight)
    }

    mutating func decreaseRowHeight() {
        rowHeight = max(rowHeight - Self.rowHeightStep, Self.minimumRowHeight)
    }
}

enum DelimitedTextDocumentParser {
    nonisolated static func markdownTable(from text: String, kind: WorkspaceDocumentKind) -> MarkdownTable? {
        guard kind.isDelimitedText else { return nil }
        let delimiter: Character = kind == .csv ? "," : "\t"
        let rows = parseRows(text, delimiter: delimiter)
        guard let headerRow = rows.first, !headerRow.isEmpty else { return nil }

        let columnCount = rows.reduce(headerRow.count) { max($0, $1.count) }
        let normalizedHeader = normalizeRow(headerRow, columnCount: columnCount)
        let normalizedRows = rows.dropFirst().map { normalizeRow($0, columnCount: columnCount) }
        let alignments = Array(repeating: MarkdownTableAlignment.leading, count: columnCount)

        return MarkdownTable(
            alignments: alignments,
            header: normalizedHeader.map(markdownCell),
            rows: normalizedRows.map { $0.map(markdownCell) }
        )
    }

    private nonisolated static func markdownCell(_ value: String) -> MarkdownTableCell {
        MarkdownTableCell(
            plainText: value,
            sourceText: value,
            attributedText: AttributedString(value)
        )
    }

    private nonisolated static func normalizeRow(_ row: [String], columnCount: Int) -> [String] {
        if row.count >= columnCount {
            return Array(row.prefix(columnCount))
        }
        return row + Array(repeating: "", count: columnCount - row.count)
    }

    private nonisolated static func parseRows(_ text: String, delimiter: Character) -> [[String]] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var isInsideQuotes = false
        var index = normalized.startIndex

        while index < normalized.endIndex {
            let character = normalized[index]

            if character == "\"" {
                let nextIndex = normalized.index(after: index)
                if isInsideQuotes, nextIndex < normalized.endIndex, normalized[nextIndex] == "\"" {
                    currentField.append("\"")
                    index = normalized.index(after: nextIndex)
                    continue
                }
                isInsideQuotes.toggle()
                index = normalized.index(after: index)
                continue
            }

            if character == delimiter, !isInsideQuotes {
                currentRow.append(currentField)
                currentField.removeAll(keepingCapacity: true)
                index = normalized.index(after: index)
                continue
            }

            if character == "\n", !isInsideQuotes {
                currentRow.append(currentField)
                rows.append(currentRow)
                currentRow.removeAll(keepingCapacity: true)
                currentField.removeAll(keepingCapacity: true)
                index = normalized.index(after: index)
                continue
            }

            currentField.append(character)
            index = normalized.index(after: index)
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows.filter { row in
            row.contains { !$0.isEmpty }
        }
    }
}
