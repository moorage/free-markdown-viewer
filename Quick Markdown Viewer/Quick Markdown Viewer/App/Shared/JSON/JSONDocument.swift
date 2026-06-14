import Foundation

nonisolated enum JSONFamilyDocumentKind: String, Hashable, Codable, Sendable {
    case json
    case jsonc
    case ndjson

    nonisolated static func forPath(_ path: String) -> JSONFamilyDocumentKind? {
        switch (path as NSString).pathExtension.lowercased() {
        case "json":
            return .json
        case "jsonc":
            return .jsonc
        case "ndjson", "jsonl":
            return .ndjson
        default:
            return nil
        }
    }

    nonisolated static func forFenceInfo(_ infoString: String?) -> JSONFamilyDocumentKind? {
        guard let rawToken = infoString?
            .split(whereSeparator: \.isWhitespace)
            .first?
            .lowercased() else {
            return nil
        }
        switch rawToken {
        case "json":
            return .json
        case "jsonc":
            return .jsonc
        case "ndjson", "jsonl":
            return .ndjson
        default:
            return nil
        }
    }
}

nonisolated struct JSONSourceLocation: Hashable, Sendable {
    let line: Int
    let column: Int
}

nonisolated struct JSONSourceRange: Hashable, Sendable {
    let start: JSONSourceLocation
    let end: JSONSourceLocation
}

nonisolated enum JSONSyntaxTokenKind: String, Hashable, Sendable {
    case string
    case number
    case bool
    case null
    case comment
    case punctuation
    case error
}

nonisolated struct JSONSyntaxToken: Hashable, Sendable {
    let kind: JSONSyntaxTokenKind
    let range: JSONSourceRange
}

nonisolated enum JSONValueKind: String, Hashable, Sendable {
    case object
    case array
    case string
    case number
    case bool
    case null
    case comment
    case error
    case record
}

nonisolated struct JSONDiagnostic: Hashable, Sendable {
    let message: String
    let line: Int
    let column: Int
}

nonisolated struct JSONValueNode: Identifiable, Hashable, Sendable {
    let id: String
    let key: String?
    let kind: JSONValueKind
    let displayValue: String?
    let sourceRange: JSONSourceRange
    let children: [JSONValueNode]

    var lineNumber: Int {
        sourceRange.start.line
    }

    var isContainer: Bool {
        kind == .object || kind == .array || kind == .record
    }

    var summary: String {
        switch kind {
        case .object:
            return "{ \(children.count) }"
        case .array:
            return "[ \(children.count) ]"
        case .record:
            return "record"
        case .string, .number, .bool, .null, .comment, .error:
            return displayValue ?? ""
        }
    }
}

nonisolated struct JSONDocumentModel: Hashable, Sendable {
    let kind: JSONFamilyDocumentKind
    let source: String
    let roots: [JSONValueNode]
    let diagnostics: [JSONDiagnostic]
    let sourceLineOffset: Int
    let syntaxTokens: [JSONSyntaxToken]

    var sourceLines: [String] {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        if lines.last == "" {
            return Array(lines.dropLast())
        }
        return lines
    }

    nonisolated static func parse(
        source: String,
        kind: JSONFamilyDocumentKind,
        sourceLineOffset: Int = 0
    ) -> JSONDocumentModel {
        JSONFamilyParser(source: source, kind: kind, sourceLineOffset: sourceLineOffset).parse()
    }
}

nonisolated struct JSONViewerRow: Identifiable, Hashable, Sendable {
    let id: String
    let nodeID: String
    let lineNumber: Int
    let depth: Int
    let key: String?
    let kind: JSONValueKind
    let displayValue: String
    let hasChildren: Bool
    let isCollapsed: Bool
    let ancestorTitles: [String]
    let tableProjection: JSONTableProjection?
}

nonisolated struct JSONTableProjection: Hashable, Sendable {
    let id: String
    let depth: Int
    let columns: [String]
    let rows: [JSONTableProjectionRow]
}

nonisolated struct JSONTableProjectionRow: Identifiable, Hashable, Sendable {
    let id: String
    let lineNumber: Int
    let cells: [JSONTableProjectionCell]
}

nonisolated struct JSONTableProjectionCell: Identifiable, Hashable, Sendable {
    let id: String
    let column: String
    let lineNumber: Int
    let displayValue: String
    let kind: JSONValueKind
}

nonisolated enum JSONPresentationBuilder {
    nonisolated static func rows(
        for document: JSONDocumentModel,
        collapsedNodeIDs: Set<String>
    ) -> [JSONViewerRow] {
        var rows: [JSONViewerRow] = []
        for root in document.roots {
            append(
                root,
                depth: 0,
                collapsedNodeIDs: collapsedNodeIDs,
                ancestors: [],
                rows: &rows
            )
        }
        if rows.isEmpty, !document.diagnostics.isEmpty {
            rows = document.diagnostics.map { diagnostic in
                JSONViewerRow(
                    id: "diagnostic.\(diagnostic.line).\(diagnostic.column)",
                    nodeID: "diagnostic.\(diagnostic.line).\(diagnostic.column)",
                    lineNumber: diagnostic.line,
                    depth: 0,
                    key: nil,
                    kind: .error,
                    displayValue: diagnostic.message,
                    hasChildren: false,
                    isCollapsed: false,
                    ancestorTitles: [],
                    tableProjection: nil
                )
            }
        }
        return rows
    }

    private nonisolated static func append(
        _ node: JSONValueNode,
        depth: Int,
        collapsedNodeIDs: Set<String>,
        ancestors: [String],
        rows: inout [JSONViewerRow]
    ) {
        let isCollapsed = collapsedNodeIDs.contains(node.id)
        let title = rowTitle(for: node)
        let tableProjection = isCollapsed ? nil : tableProjection(for: node, depth: depth + 1)
        rows.append(
            JSONViewerRow(
                id: node.id,
                nodeID: node.id,
                lineNumber: node.lineNumber,
                depth: depth,
                key: node.key,
                kind: node.kind,
                displayValue: node.summary,
                hasChildren: !node.children.isEmpty,
                isCollapsed: isCollapsed,
                ancestorTitles: ancestors,
                tableProjection: tableProjection
            )
        )
        guard !isCollapsed else { return }
        if tableProjection != nil { return }
        let nextAncestors = node.isContainer ? ancestors + [title] : ancestors
        for child in node.children {
            append(
                child,
                depth: depth + 1,
                collapsedNodeIDs: collapsedNodeIDs,
                ancestors: nextAncestors,
                rows: &rows
            )
        }
    }

    private nonisolated static func rowTitle(for node: JSONValueNode) -> String {
        if let key = node.key {
            return key
        }
        return node.summary
    }

    private nonisolated static func tableProjection(for node: JSONValueNode, depth: Int) -> JSONTableProjection? {
        guard node.kind == .array else { return nil }
        let objectRows = node.children.filter { $0.kind == .object }
        guard objectRows.count == node.children.count, objectRows.count >= 2 else { return nil }

        var columns: [String] = []
        for row in objectRows {
            for child in row.children where child.kind != .comment && child.kind != .error {
                guard let key = child.key, !columns.contains(key) else { continue }
                columns.append(key)
            }
        }
        guard !columns.isEmpty else { return nil }

        let projectedRows = objectRows.enumerated().map { rowIndex, row in
            var childrenByKey: [String: JSONValueNode] = [:]
            for child in row.children {
                guard let key = child.key, childrenByKey[key] == nil else { continue }
                childrenByKey[key] = child
            }
            let cells = columns.map { column in
                if let child = childrenByKey[column] {
                    return JSONTableProjectionCell(
                        id: "\(row.id).cell.\(column)",
                        column: column,
                        lineNumber: child.lineNumber,
                        displayValue: child.summary,
                        kind: child.kind
                    )
                }
                return JSONTableProjectionCell(
                    id: "\(row.id).cell.\(column).missing",
                    column: column,
                    lineNumber: row.lineNumber,
                    displayValue: "",
                    kind: .null
                )
            }
            return JSONTableProjectionRow(
                id: "\(node.id).table.row.\(rowIndex)",
                lineNumber: row.lineNumber,
                cells: cells
            )
        }

        return JSONTableProjection(
            id: "\(node.id).table",
            depth: depth,
            columns: columns,
            rows: projectedRows
        )
    }
}

private nonisolated enum JSONTokenKind: Equatable {
    case leftBrace
    case rightBrace
    case leftBracket
    case rightBracket
    case colon
    case comma
    case string(String)
    case number(String)
    case bool(Bool)
    case null
    case comment(String)
    case invalid(String)
    case eof
}

private nonisolated struct JSONToken: Equatable {
    let kind: JSONTokenKind
    let range: JSONSourceRange
}

private nonisolated final class JSONFamilyParser {
    private let source: String
    private let kind: JSONFamilyDocumentKind
    private let sourceLineOffset: Int
    private var tokens: [JSONToken] = []
    private var index = 0
    private var diagnostics: [JSONDiagnostic] = []

    init(source: String, kind: JSONFamilyDocumentKind, sourceLineOffset: Int) {
        self.source = source.replacingOccurrences(of: "\r\n", with: "\n")
        self.kind = kind
        self.sourceLineOffset = sourceLineOffset
    }

    func parse() -> JSONDocumentModel {
        if kind == .ndjson {
            return parseNDJSON()
        }

        tokens = JSONFamilyLexer(source: source, sourceLineOffset: sourceLineOffset).tokens()
        index = 0
        diagnostics = []
        let root = parseValue(path: "root", key: nil) ?? errorNode(
            path: "root",
            message: "Expected JSON value.",
            at: currentToken()
        )
        return JSONDocumentModel(
            kind: kind,
            source: source,
            roots: [root],
            diagnostics: diagnostics,
            sourceLineOffset: sourceLineOffset,
            syntaxTokens: Self.syntaxTokens(from: tokens)
        )
    }

    private func parseNDJSON() -> JSONDocumentModel {
        let lines = source.components(separatedBy: "\n")
        var roots: [JSONValueNode] = []
        var allDiagnostics: [JSONDiagnostic] = []
        var allSyntaxTokens: [JSONSyntaxToken] = []

        for lineOffset in lines.indices {
            let rawLine = lines[lineOffset]
            guard !rawLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let parser = JSONFamilyParser(
                source: rawLine,
                kind: .json,
                sourceLineOffset: sourceLineOffset + lineOffset
            )
            let parsed = parser.parse()
            allDiagnostics.append(contentsOf: parsed.diagnostics)
            allSyntaxTokens.append(contentsOf: parsed.syntaxTokens)
            let lineNumber = sourceLineOffset + lineOffset + 1
            if let parsedRoot = parsed.roots.first, parsed.diagnostics.isEmpty {
                let recordID = "record.\(roots.count)"
                roots.append(
                    JSONValueNode(
                        id: recordID,
                        key: nil,
                        kind: .record,
                        displayValue: "record \(roots.count + 1)",
                        sourceRange: JSONSourceRange(
                            start: JSONSourceLocation(line: lineNumber, column: 1),
                            end: JSONSourceLocation(line: lineNumber, column: max(rawLine.count, 1))
                        ),
                        children: [namespacedNode(parsedRoot, prefix: recordID)]
                    )
                )
            } else {
                roots.append(
                    JSONValueNode(
                        id: "record.\(roots.count).error",
                        key: nil,
                        kind: .error,
                        displayValue: allDiagnostics.last?.message ?? "Malformed NDJSON record.",
                        sourceRange: JSONSourceRange(
                            start: JSONSourceLocation(line: lineNumber, column: 1),
                            end: JSONSourceLocation(line: lineNumber, column: max(rawLine.count, 1))
                        ),
                        children: []
                    )
                )
            }
        }

        return JSONDocumentModel(
            kind: kind,
            source: source,
            roots: roots,
            diagnostics: allDiagnostics,
            sourceLineOffset: sourceLineOffset,
            syntaxTokens: allSyntaxTokens
        )
    }

    private func namespacedNode(_ node: JSONValueNode, prefix: String) -> JSONValueNode {
        JSONValueNode(
            id: "\(prefix).\(node.id)",
            key: node.key,
            kind: node.kind,
            displayValue: node.displayValue,
            sourceRange: node.sourceRange,
            children: node.children.map { namespacedNode($0, prefix: prefix) }
        )
    }

    private func parseValue(path: String, key: String?) -> JSONValueNode? {
        skipCommentsOutsideContainers()
        let token = currentToken()
        switch token.kind {
        case .leftBrace:
            return parseObject(path: path, key: key)
        case .leftBracket:
            return parseArray(path: path, key: key)
        case let .string(value):
            advance()
            return JSONValueNode(id: path, key: key, kind: .string, displayValue: "\"\(value)\"", sourceRange: token.range, children: [])
        case let .number(value):
            advance()
            return JSONValueNode(id: path, key: key, kind: .number, displayValue: value, sourceRange: token.range, children: [])
        case let .bool(value):
            advance()
            return JSONValueNode(id: path, key: key, kind: .bool, displayValue: value ? "true" : "false", sourceRange: token.range, children: [])
        case .null:
            advance()
            return JSONValueNode(id: path, key: key, kind: .null, displayValue: "null", sourceRange: token.range, children: [])
        case let .invalid(value):
            advance()
            addDiagnostic("Invalid token '\(value)'.", at: token)
            return JSONValueNode(id: path, key: key, kind: .error, displayValue: value, sourceRange: token.range, children: [])
        case .comment:
            let comment = parseComment(path: path, key: key)
            return comment
        case .rightBrace, .rightBracket, .colon, .comma, .eof:
            return nil
        }
    }

    private func parseObject(path: String, key: String?) -> JSONValueNode {
        let opening = currentToken()
        advance()
        var children: [JSONValueNode] = []
        var memberIndex = 0

        while !isAtEnd {
            if consume(.rightBrace) {
                return JSONValueNode(id: path, key: key, kind: .object, displayValue: nil, sourceRange: range(from: opening, to: previousToken()), children: children)
            }
            if case .comment = currentToken().kind {
                children.append(parseComment(path: "\(path).comment.\(memberIndex)", key: nil))
                memberIndex += 1
                _ = consume(.comma)
                continue
            }
            guard case let .string(memberKey) = currentToken().kind else {
                addDiagnostic("Expected object key.", at: currentToken())
                children.append(errorNode(path: "\(path).error.\(memberIndex)", message: "Expected object key.", at: currentToken()))
                recoverObjectMember()
                memberIndex += 1
                continue
            }

            advance()
            if !consume(.colon) {
                addDiagnostic("Expected ':' after object key.", at: currentToken())
            }
            let childPath = "\(path).\(safePathComponent(memberKey, fallback: memberIndex))"
            let child = parseValue(path: childPath, key: memberKey) ?? errorNode(path: childPath, message: "Expected value.", at: currentToken())
            children.append(child)
            memberIndex += 1

            if consume(.comma) {
                if case .rightBrace = currentToken().kind, kind == .json {
                    addDiagnostic("Trailing comma is not valid JSON.", at: previousToken())
                }
                continue
            }
        }

        addDiagnostic("Unclosed object.", at: opening)
        return JSONValueNode(id: path, key: key, kind: .object, displayValue: nil, sourceRange: range(from: opening, to: previousToken()), children: children)
    }

    private func parseArray(path: String, key: String?) -> JSONValueNode {
        let opening = currentToken()
        advance()
        var children: [JSONValueNode] = []
        var itemIndex = 0

        while !isAtEnd {
            if consume(.rightBracket) {
                return JSONValueNode(id: path, key: key, kind: .array, displayValue: nil, sourceRange: range(from: opening, to: previousToken()), children: children)
            }
            if case .comment = currentToken().kind {
                children.append(parseComment(path: "\(path).comment.\(itemIndex)", key: nil))
                itemIndex += 1
                _ = consume(.comma)
                continue
            }
            let childPath = "\(path).\(itemIndex)"
            let child = parseValue(path: childPath, key: nil) ?? errorNode(path: childPath, message: "Expected array item.", at: currentToken())
            children.append(child)
            itemIndex += 1
            if consume(.comma) {
                if case .rightBracket = currentToken().kind, kind == .json {
                    addDiagnostic("Trailing comma is not valid JSON.", at: previousToken())
                }
                continue
            }
        }

        addDiagnostic("Unclosed array.", at: opening)
        return JSONValueNode(id: path, key: key, kind: .array, displayValue: nil, sourceRange: range(from: opening, to: previousToken()), children: children)
    }

    private func parseComment(path: String, key: String?) -> JSONValueNode {
        let token = currentToken()
        if kind == .json {
            addDiagnostic("Comments are not valid JSON.", at: token)
        }
        advance()
        let value: String
        if case let .comment(comment) = token.kind {
            value = comment
        } else {
            value = ""
        }
        return JSONValueNode(id: path, key: key, kind: .comment, displayValue: value, sourceRange: token.range, children: [])
    }

    private func skipCommentsOutsideContainers() {
        while case .comment = currentToken().kind {
            if kind == .json {
                addDiagnostic("Comments are not valid JSON.", at: currentToken())
            }
            advance()
        }
    }

    private func recoverObjectMember() {
        while !isAtEnd {
            if consume(.comma) || matches(.rightBrace) {
                return
            }
            advance()
        }
    }

    private func safePathComponent(_ value: String, fallback: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "\(fallback)" }
        let allowed = trimmed.map { character in
            character.isLetter || character.isNumber ? character : "_"
        }
        return String(allowed)
    }

    private func errorNode(path: String, message: String, at token: JSONToken) -> JSONValueNode {
        JSONValueNode(id: path, key: nil, kind: .error, displayValue: message, sourceRange: token.range, children: [])
    }

    private var isAtEnd: Bool {
        if case .eof = currentToken().kind {
            return true
        }
        return false
    }

    private func currentToken() -> JSONToken {
        tokens[min(index, tokens.count - 1)]
    }

    private func previousToken() -> JSONToken {
        tokens[max(index - 1, 0)]
    }

    private func advance() {
        if index < tokens.count - 1 {
            index += 1
        }
    }

    private func consume(_ kind: JSONTokenKind) -> Bool {
        guard matches(kind) else { return false }
        advance()
        return true
    }

    private func matches(_ kind: JSONTokenKind) -> Bool {
        switch (currentToken().kind, kind) {
        case (.leftBrace, .leftBrace),
             (.rightBrace, .rightBrace),
             (.leftBracket, .leftBracket),
             (.rightBracket, .rightBracket),
             (.colon, .colon),
             (.comma, .comma),
             (.eof, .eof):
            return true
        default:
            return false
        }
    }

    private func range(from start: JSONToken, to end: JSONToken) -> JSONSourceRange {
        JSONSourceRange(start: start.range.start, end: end.range.end)
    }

    private func addDiagnostic(_ message: String, at token: JSONToken) {
        diagnostics.append(JSONDiagnostic(message: message, line: token.range.start.line, column: token.range.start.column))
    }

    private static func syntaxTokens(from tokens: [JSONToken]) -> [JSONSyntaxToken] {
        tokens.compactMap { token in
            let kind: JSONSyntaxTokenKind?
            switch token.kind {
            case .leftBrace, .rightBrace, .leftBracket, .rightBracket, .colon, .comma:
                kind = .punctuation
            case .string:
                kind = .string
            case .number:
                kind = .number
            case .bool:
                kind = .bool
            case .null:
                kind = .null
            case .comment:
                kind = .comment
            case .invalid:
                kind = .error
            case .eof:
                kind = nil
            }
            guard let kind else { return nil }
            return JSONSyntaxToken(kind: kind, range: token.range)
        }
    }
}

private nonisolated final class JSONFamilyLexer {
    private let characters: [Character]
    private let sourceLineOffset: Int
    private var index = 0
    private var line = 1
    private var column = 1

    init(source: String, sourceLineOffset: Int) {
        self.characters = Array(source)
        self.sourceLineOffset = sourceLineOffset
    }

    func tokens() -> [JSONToken] {
        var result: [JSONToken] = []
        while let character = peek() {
            if character == " " || character == "\t" || character == "\n" {
                advance()
                continue
            }
            let start = location
            switch character {
            case "{":
                advance()
                result.append(token(.leftBrace, start: start))
            case "}":
                advance()
                result.append(token(.rightBrace, start: start))
            case "[":
                advance()
                result.append(token(.leftBracket, start: start))
            case "]":
                advance()
                result.append(token(.rightBracket, start: start))
            case ":":
                advance()
                result.append(token(.colon, start: start))
            case ",":
                advance()
                result.append(token(.comma, start: start))
            case "\"":
                result.append(stringToken(start: start))
            case "/":
                result.append(commentOrInvalidToken(start: start))
            case "-", "0"..."9":
                result.append(numberToken(start: start))
            default:
                if let keyword = keywordToken(start: start) {
                    result.append(keyword)
                } else {
                    advance()
                    result.append(token(.invalid(String(character)), start: start))
                }
            }
        }
        result.append(JSONToken(kind: .eof, range: JSONSourceRange(start: location, end: location)))
        return result
    }

    private var location: JSONSourceLocation {
        JSONSourceLocation(line: sourceLineOffset + line, column: column)
    }

    private func stringToken(start: JSONSourceLocation) -> JSONToken {
        advance()
        var value = ""
        var escaped = false
        while let character = peek() {
            advance()
            if escaped {
                value.append(character)
                escaped = false
                continue
            }
            if character == "\\" {
                escaped = true
                continue
            }
            if character == "\"" {
                return JSONToken(kind: .string(value), range: JSONSourceRange(start: start, end: location))
            }
            value.append(character)
        }
        return JSONToken(kind: .invalid("Unterminated string"), range: JSONSourceRange(start: start, end: location))
    }

    private func commentOrInvalidToken(start: JSONSourceLocation) -> JSONToken {
        advance()
        guard let next = peek() else {
            return token(.invalid("/"), start: start)
        }
        if next == "/" {
            advance()
            var value = "//"
            while let character = peek(), character != "\n" {
                value.append(character)
                advance()
            }
            return JSONToken(kind: .comment(value), range: JSONSourceRange(start: start, end: location))
        }
        if next == "*" {
            advance()
            var value = "/*"
            var previous: Character?
            while let character = peek() {
                value.append(character)
                advance()
                if previous == "*", character == "/" {
                    return JSONToken(kind: .comment(value), range: JSONSourceRange(start: start, end: location))
                }
                previous = character
            }
            return JSONToken(kind: .invalid("Unterminated comment"), range: JSONSourceRange(start: start, end: location))
        }
        return token(.invalid("/"), start: start)
    }

    private func numberToken(start: JSONSourceLocation) -> JSONToken {
        var value = ""
        while let character = peek(),
              character == "-" || character == "+" || character == "." || character == "e" || character == "E" || character.isNumber {
            value.append(character)
            advance()
        }
        return JSONToken(kind: .number(value), range: JSONSourceRange(start: start, end: location))
    }

    private func keywordToken(start: JSONSourceLocation) -> JSONToken? {
        let remaining = String(characters[index...])
        for (keyword, kind) in [
            ("true", JSONTokenKind.bool(true)),
            ("false", JSONTokenKind.bool(false)),
            ("null", JSONTokenKind.null),
        ] {
            if remaining.hasPrefix(keyword) {
                for _ in keyword {
                    advance()
                }
                return JSONToken(kind: kind, range: JSONSourceRange(start: start, end: location))
            }
        }
        return nil
    }

    private func token(_ kind: JSONTokenKind, start: JSONSourceLocation) -> JSONToken {
        JSONToken(kind: kind, range: JSONSourceRange(start: start, end: location))
    }

    private func peek() -> Character? {
        guard characters.indices.contains(index) else { return nil }
        return characters[index]
    }

    @discardableResult
    private func advance() -> Character? {
        guard let character = peek() else { return nil }
        index += 1
        if character == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        return character
    }
}
