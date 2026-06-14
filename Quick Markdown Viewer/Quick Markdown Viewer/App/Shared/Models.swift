import Foundation

nonisolated struct WorkspacePath: Hashable, Codable, Identifiable, Sendable {
    let rawValue: String

    var id: String { rawValue }
}

nonisolated enum WorkspaceDocumentKind: String, Hashable, Codable, Sendable {
    case markdown
    case mermaid
    case csv
    case tsv
    case json
    case jsonc
    case ndjson

    nonisolated var isDelimitedText: Bool {
        switch self {
        case .csv, .tsv:
            return true
        case .markdown, .mermaid, .json, .jsonc, .ndjson:
            return false
        }
    }

    nonisolated var jsonFamilyKind: JSONFamilyDocumentKind? {
        switch self {
        case .json:
            return .json
        case .jsonc:
            return .jsonc
        case .ndjson:
            return .ndjson
        case .markdown, .mermaid, .csv, .tsv:
            return nil
        }
    }

    nonisolated var iconSystemName: String {
        switch self {
        case .markdown:
            return "doc.text"
        case .mermaid:
            return "point.3.connected.trianglepath.dotted"
        case .csv, .tsv:
            return "tablecells"
        case .json, .jsonc, .ndjson:
            return "curlybraces"
        }
    }

    nonisolated static func forPath(_ path: String) -> WorkspaceDocumentKind? {
        let fileExtension = (path as NSString).pathExtension.lowercased()
        switch fileExtension {
        case "md", "markdown", "mdown", "mkd", "mkdn":
            return .markdown
        case "mermaid", "mmd":
            return .mermaid
        case "csv":
            return .csv
        case "tsv":
            return .tsv
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

nonisolated struct MarkdownFileNode: Identifiable, Hashable, Sendable {
    let path: WorkspacePath
    let name: String
    let kind: WorkspaceDocumentKind

    var id: String { path.rawValue }
}

nonisolated struct Workspace: Sendable {
    let rootIdentifier: String
    let files: [MarkdownFileNode]
}

struct NavigationEntry: Equatable, Sendable {
    let filePath: WorkspacePath
    let scrollPosition: Double?
}

struct MarkdownOutlineTitleRun: Equatable, Sendable {
    let text: String
    let isCode: Bool
}

struct MarkdownOutlineItem: Identifiable, Equatable, Sendable {
    let blockID: String
    let title: String
    let titleRuns: [MarkdownOutlineTitleRun]
    let level: Int

    var id: String { blockID }
}

enum MarkdownBlockKind: String, Hashable, Sendable {
    case heading
    case paragraph
    case unorderedListItem
    case orderedListItem
    case blockquote
    case codeBlock
    case table
    case jsonDocument
    case image
    case animatedImage
    case video
    case mermaidDiagram
    case rawHTML
    case thematicBreak
}

enum MarkdownTableAlignment: String, Hashable, Sendable {
    case leading
    case center
    case trailing
}

struct MarkdownTableCell: Hashable, Sendable {
    let plainText: String
    let sourceText: String
    let attributedText: AttributedString?
}

enum MarkdownTableContentKind: String, Hashable, Sendable {
    case markdown
    case plainText
}

struct MarkdownTable: Hashable, Sendable {
    nonisolated static let lazyViewportRowThreshold = 200
    nonisolated static let lazyViewportCellThreshold = 1_000
    nonisolated static let lazyViewportCellCharacterThreshold = 320

    let alignments: [MarkdownTableAlignment]
    let header: [MarkdownTableCell]
    let rows: [[MarkdownTableCell]]
    let contentKind: MarkdownTableContentKind

    nonisolated var prefersLazyInteractiveViewport: Bool {
        Self.prefersLazyInteractiveViewport(
            rowCount: rows.count,
            columnCount: header.count,
            longestCellCharacterCount: longestCellCharacterCount
        )
    }

    nonisolated static func prefersLazyInteractiveViewport(
        rowCount: Int,
        columnCount: Int,
        longestCellCharacterCount: Int = 0
    ) -> Bool {
        rowCount >= lazyViewportRowThreshold ||
        (rowCount + 1) * columnCount >= lazyViewportCellThreshold ||
        longestCellCharacterCount >= lazyViewportCellCharacterThreshold
    }

    private nonisolated var longestCellCharacterCount: Int {
        ([header] + rows)
            .flatMap { $0 }
            .map(\.plainText.count)
            .max() ?? 0
    }
}

struct MarkdownImage: Hashable, Sendable {
    let altText: String
    let sourceURL: String
    let title: String?
    let sourceKind: MarkdownMediaSourceKind
    let resolvedURL: URL?
    let loadError: String?
}

struct MarkdownVideo: Hashable, Sendable {
    let altText: String
    let sourceURL: String
    let title: String?
    let sourceKind: MarkdownMediaSourceKind
    let resolvedURL: URL?
    let loadError: String?
}

enum MarkdownMediaSourceKind: String, Hashable, Sendable {
    case local
    case remote
}

struct MarkdownCodeBlock: Hashable, Sendable {
    let code: String
    let infoString: String?
    let rawLanguage: String?
    let language: SyntaxHighlightLanguage?
    let isFenced: Bool
    let contentStartLine: Int?
}

struct MarkdownJSONDocument: Hashable, Sendable {
    let kind: JSONFamilyDocumentKind
    let document: JSONDocumentModel
}

struct MarkdownBlock: Identifiable, Hashable, Sendable {
    let id: String
    let kind: MarkdownBlockKind
    let plainText: String
    let sourceText: String
    let level: Int?
    let listItemIndex: Int?
    let indentLevel: Int
    let isTaskItem: Bool
    let isTaskCompleted: Bool?
    let table: MarkdownTable?
    let image: MarkdownImage?
    let video: MarkdownVideo?
    let mermaidDiagram: MarkdownMermaidDiagram?
    let attributedText: AttributedString?
    let children: [MarkdownBlock]
    let codeBlock: MarkdownCodeBlock?
    let jsonDocument: MarkdownJSONDocument?

    nonisolated init(
        id: String,
        kind: MarkdownBlockKind,
        plainText: String,
        sourceText: String,
        level: Int?,
        listItemIndex: Int?,
        indentLevel: Int,
        isTaskItem: Bool,
        isTaskCompleted: Bool?,
        table: MarkdownTable?,
        image: MarkdownImage?,
        video: MarkdownVideo?,
        mermaidDiagram: MarkdownMermaidDiagram? = nil,
        attributedText: AttributedString?,
        children: [MarkdownBlock],
        codeBlock: MarkdownCodeBlock? = nil,
        jsonDocument: MarkdownJSONDocument? = nil
    ) {
        self.id = id
        self.kind = kind
        self.plainText = plainText
        self.sourceText = sourceText
        self.level = level
        self.listItemIndex = listItemIndex
        self.indentLevel = indentLevel
        self.isTaskItem = isTaskItem
        self.isTaskCompleted = isTaskCompleted
        self.table = table
        self.image = image
        self.video = video
        self.mermaidDiagram = mermaidDiagram
        self.attributedText = attributedText
        self.children = children
        self.codeBlock = codeBlock
        self.jsonDocument = jsonDocument
    }
}

extension MarkdownBlock {
    nonisolated func replacing(
        kind: MarkdownBlockKind? = nil,
        image: MarkdownImage? = nil,
        video: MarkdownVideo? = nil,
        mermaidDiagram: MarkdownMermaidDiagram? = nil,
        children: [MarkdownBlock]? = nil,
        codeBlock: MarkdownCodeBlock? = nil,
        jsonDocument: MarkdownJSONDocument? = nil
    ) -> MarkdownBlock {
        MarkdownBlock(
            id: id,
            kind: kind ?? self.kind,
            plainText: plainText,
            sourceText: sourceText,
            level: level,
            listItemIndex: listItemIndex,
            indentLevel: indentLevel,
            isTaskItem: isTaskItem,
            isTaskCompleted: isTaskCompleted,
            table: table,
            image: image ?? self.image,
            video: video ?? self.video,
            mermaidDiagram: mermaidDiagram ?? self.mermaidDiagram,
            attributedText: attributedText,
            children: children ?? self.children,
            codeBlock: codeBlock ?? self.codeBlock,
            jsonDocument: jsonDocument ?? self.jsonDocument
        )
    }
}
