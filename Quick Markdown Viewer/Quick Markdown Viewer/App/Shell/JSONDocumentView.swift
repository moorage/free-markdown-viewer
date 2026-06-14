import SwiftUI

struct JSONDocumentView: View {
    let jsonDocument: MarkdownJSONDocument
    let fontScale: CGFloat
    let isPrinting: Bool

    @State private var mode: JSONPresentationMode = .viewer
    @State private var collapsedNodeIDs: Set<String> = []
    @State private var activeAncestorTitles: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isPrinting {
                Picker("JSON Mode", selection: $mode) {
                    Text("Viewer").tag(JSONPresentationMode.viewer)
                    Text("Source").tag(JSONPresentationMode.source)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
                .padding([.top, .horizontal], 12)
                .padding(.bottom, 8)
                .accessibilityIdentifier("json.mode")
            }

            if mode == .source && !isPrinting {
                sourceRows
            } else {
                viewerRows
            }
        }
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }

    private var viewerRows: some View {
        let rows = JSONPresentationBuilder.rows(
            for: jsonDocument.document,
            collapsedNodeIDs: isPrinting ? [] : collapsedNodeIDs
        )
        let displayedRows = JSONGutterPresentationBuilder.rows(from: rows)

        return Group {
            if isPrinting {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(displayedRows) { displayedRow in
                        viewerRow(displayedRow)
                    }
                }
                .padding(12)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(displayedRows) { displayedRow in
                                viewerRow(displayedRow)
                            }
                        } header: {
                            stickyHeader()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                }
                .coordinateSpace(name: JSONAncestorPreference.coordinateSpaceName)
                .onPreferenceChange(JSONAncestorPreferenceKey.self) { preferences in
                    activeAncestorTitles = activeAncestors(from: preferences)
                }
                .frame(minHeight: 220, maxHeight: 620)
            }
        }
    }

    private var sourceRows: some View {
        let lines = jsonDocument.document.sourceLines
        return ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(Array(lines.enumerated()), id: \.offset) { offset, line in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            gutter(
                                jsonDocument.document.sourceLineOffset + offset + 1,
                                visibleLineNumber: jsonDocument.document.sourceLineOffset + offset + 1
                            )
                            sourceLineText(lineNumber: jsonDocument.document.sourceLineOffset + offset + 1, text: line)
                                .font(monospacedFont)
                            .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                    }
                } header: {
                    stickyTitle("Source")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .frame(minHeight: 220, maxHeight: 620)
    }

    private func stickyHeader() -> some View {
        let title = activeAncestorTitles.isEmpty
            ? jsonDocument.kind.rawValue.uppercased()
            : activeAncestorTitles.joined(separator: " > ")
        return stickyTitle(title)
    }

    private func stickyTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12 * fontScale, weight: .semibold, design: .monospaced))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.regularMaterial)
    }

    private func viewerRow(_ displayedRow: JSONDisplayedViewerRow) -> some View {
        let row = displayedRow.row
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                gutter(row.lineNumber, visibleLineNumber: displayedRow.visibleLineNumber)

                Button {
                    toggle(row)
                } label: {
                    Image(systemName: disclosureIcon(for: row))
                        .font(.system(size: 10 * fontScale, weight: .semibold))
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
                .disabled(!row.hasChildren || isPrinting)
                .opacity(row.hasChildren ? 1 : 0.18)
                .accessibilityIdentifier("json.disclosure.\(row.nodeID)")

                indentation(row.depth)

                if let key = row.key {
                    Text(verbatim: "\"\(key)\"")
                        .font(monospacedFont)
                        .foregroundStyle(Color.teal)
                    Text(":")
                        .font(monospacedFont)
                        .foregroundStyle(.secondary)
                }

                Text(verbatim: row.displayValue)
                    .font(monospacedFont)
                    .foregroundStyle(color(for: row.kind))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 3)

            if let tableProjection = row.tableProjection {
                tableProjectionView(
                    tableProjection,
                    displayedRows: displayedRow.tableRows
                )
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: JSONAncestorPreferenceKey.self,
                    value: [
                        JSONAncestorPreference(
                            nodeID: row.nodeID,
                            minY: proxy.frame(in: .named(JSONAncestorPreference.coordinateSpaceName)).minY,
                            ancestorTitles: row.ancestorTitles
                        ),
                    ]
                )
            }
        )
        .accessibilityIdentifier("json.row.\(row.nodeID)")
    }

    private func tableProjectionView(
        _ table: JSONTableProjection,
        displayedRows: [JSONDisplayedTableProjectionRow]
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                gutter(table.rows.first?.lineNumber ?? 1, visibleLineNumber: nil)
                    .opacity(0)
                indentation(table.depth)
                ForEach(table.columns, id: \.self) { column in
                    Text(verbatim: column)
                        .font(.system(size: 12 * fontScale, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 140, alignment: .leading)
                }
            }
            .padding(.vertical, 3)

            ForEach(displayedRows) { displayedRow in
                let projectedRow = displayedRow.row
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    gutter(
                        projectedRow.lineNumber,
                        visibleLineNumber: displayedRow.visibleLineNumber
                    )
                    indentation(table.depth)
                    ForEach(projectedRow.cells) { cell in
                        Text(verbatim: cell.displayValue)
                            .font(monospacedFont)
                            .foregroundStyle(color(for: cell.kind))
                            .lineLimit(2)
                            .frame(width: 140, alignment: .leading)
                            .accessibilityIdentifier("json.table.cell.\(cell.id)")
                    }
                }
                .padding(.vertical, 3)
            }
        }
        .padding(.bottom, 4)
        .accessibilityIdentifier("json.table.\(table.id)")
    }

    private func gutter(_ lineNumber: Int, visibleLineNumber: Int?) -> some View {
        Text(verbatim: visibleLineNumber.map(String.init) ?? "")
            .font(.system(size: 11 * fontScale, weight: .regular, design: .monospaced))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .frame(width: 44, alignment: .trailing)
            .accessibilityIdentifier(visibleLineNumber == nil ? "json.gutter.\(lineNumber).repeat" : "json.gutter.\(lineNumber)")
            .accessibilityLabel(Text("Line \(lineNumber)"))
    }

    private func indentation(_ depth: Int) -> some View {
        Color.clear
            .frame(width: CGFloat(depth) * 18 * fontScale, height: 1)
    }

    private var monospacedFont: Font {
        .system(size: 13 * fontScale, weight: .regular, design: .monospaced)
    }

    private func toggle(_ row: JSONViewerRow) {
        guard row.hasChildren else { return }
        if collapsedNodeIDs.contains(row.nodeID) {
            collapsedNodeIDs.remove(row.nodeID)
        } else {
            collapsedNodeIDs.insert(row.nodeID)
        }
    }

    private func disclosureIcon(for row: JSONViewerRow) -> String {
        row.isCollapsed ? "chevron.right" : "chevron.down"
    }

    private func activeAncestors(from preferences: [JSONAncestorPreference]) -> [String] {
        guard !preferences.isEmpty else { return [] }
        let sortedPreferences = preferences.sorted { $0.minY < $1.minY }
        let activePreference = sortedPreferences.last { $0.minY <= 28 } ?? sortedPreferences.first
        return activePreference?.ancestorTitles ?? []
    }

    private func sourceFragments(lineNumber: Int, text: String) -> [JSONSourceLineFragment] {
        var fragments: [JSONSourceLineFragment] = []
        var cursor = 0
        let lineLength = text.count
        let tokens = jsonDocument.document.syntaxTokens
            .filter { $0.range.start.line <= lineNumber && $0.range.end.line >= lineNumber }
            .sorted {
                if $0.range.start.line == $1.range.start.line {
                    return $0.range.start.column < $1.range.start.column
                }
                return $0.range.start.line < $1.range.start.line
            }

        for token in tokens {
            let startColumn = token.range.start.line == lineNumber ? token.range.start.column : 1
            let endColumn = token.range.end.line == lineNumber ? token.range.end.column : lineLength + 1
            let startOffset = max(0, min(lineLength, startColumn - 1))
            let endOffset = max(startOffset, min(lineLength, endColumn - 1))
            guard endOffset > startOffset else { continue }

            if cursor < startOffset {
                fragments.append(fragment(text: substring(text, from: cursor, to: startOffset), kind: nil))
            }
            fragments.append(fragment(text: substring(text, from: startOffset, to: endOffset), kind: token.kind))
            cursor = endOffset
        }

        if cursor < lineLength {
            fragments.append(fragment(text: substring(text, from: cursor, to: lineLength), kind: nil))
        }
        if fragments.isEmpty {
            fragments.append(fragment(text: text, kind: nil))
        }
        return fragments
    }

    private func sourceLineText(lineNumber: Int, text: String) -> Text {
        sourceFragments(lineNumber: lineNumber, text: text).reduce(Text("")) { partial, fragment in
            partial + Text(verbatim: fragment.text).foregroundColor(color(for: fragment.kind))
        }
    }

    private func fragment(text: String, kind: JSONSyntaxTokenKind?) -> JSONSourceLineFragment {
        JSONSourceLineFragment(id: UUID(), text: text, kind: kind)
    }

    private func substring(_ text: String, from startOffset: Int, to endOffset: Int) -> String {
        let start = text.index(text.startIndex, offsetBy: startOffset)
        let end = text.index(text.startIndex, offsetBy: endOffset)
        return String(text[start..<end])
    }

    private func color(for kind: JSONValueKind) -> Color {
        switch kind {
        case .object, .array, .record:
            return .primary
        case .string:
            return .teal
        case .number:
            return .orange
        case .bool, .null:
            return .purple
        case .comment:
            return .secondary
        case .error:
            return .red
        }
    }

    private func color(for kind: JSONSyntaxTokenKind?) -> Color {
        guard let kind else { return .primary }
        switch kind {
        case .string:
            return .teal
        case .number:
            return .orange
        case .bool, .null:
            return .purple
        case .comment:
            return .secondary
        case .punctuation:
            return .secondary
        case .error:
            return .red
        }
    }
}

enum JSONPresentationMode: String, Hashable {
    case viewer
    case source
}

private struct JSONSourceLineFragment: Identifiable, Hashable {
    let id: UUID
    let text: String
    let kind: JSONSyntaxTokenKind?
}

private struct JSONAncestorPreference: Equatable {
    static let coordinateSpaceName = "json-viewer-scroll"

    let nodeID: String
    let minY: CGFloat
    let ancestorTitles: [String]
}

private struct JSONAncestorPreferenceKey: PreferenceKey {
    static var defaultValue: [JSONAncestorPreference] = []

    static func reduce(value: inout [JSONAncestorPreference], nextValue: () -> [JSONAncestorPreference]) {
        value.append(contentsOf: nextValue())
    }
}
