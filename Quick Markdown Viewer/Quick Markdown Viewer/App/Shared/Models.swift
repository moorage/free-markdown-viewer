import Foundation

nonisolated struct WorkspacePath: Hashable, Codable, Identifiable, Sendable {
    let rawValue: String

    var id: String { rawValue }
}

nonisolated enum WorkspaceDocumentKind: String, Hashable, Codable, Sendable {
    case markdown
    case csv
    case tsv

    nonisolated var isDelimitedText: Bool {
        switch self {
        case .csv, .tsv:
            return true
        case .markdown:
            return false
        }
    }

    nonisolated var iconSystemName: String {
        switch self {
        case .markdown:
            return "doc.text"
        case .csv, .tsv:
            return "tablecells"
        }
    }

    nonisolated static func forPath(_ path: String) -> WorkspaceDocumentKind? {
        let fileExtension = (path as NSString).pathExtension.lowercased()
        switch fileExtension {
        case "md", "markdown", "mdown", "mkd", "mkdn":
            return .markdown
        case "csv":
            return .csv
        case "tsv":
            return .tsv
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

enum MarkdownBlockKind: String, Hashable, Sendable {
    case heading
    case paragraph
    case unorderedListItem
    case orderedListItem
    case blockquote
    case codeBlock
    case table
    case image
    case animatedImage
    case video
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

struct MarkdownTable: Hashable, Sendable {
    let alignments: [MarkdownTableAlignment]
    let header: [MarkdownTableCell]
    let rows: [[MarkdownTableCell]]
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
    let attributedText: AttributedString?
    let children: [MarkdownBlock]
    let codeBlock: MarkdownCodeBlock?

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
        attributedText: AttributedString?,
        children: [MarkdownBlock],
        codeBlock: MarkdownCodeBlock? = nil
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
        self.attributedText = attributedText
        self.children = children
        self.codeBlock = codeBlock
    }
}

extension MarkdownBlock {
    nonisolated func replacing(
        kind: MarkdownBlockKind? = nil,
        image: MarkdownImage? = nil,
        video: MarkdownVideo? = nil,
        children: [MarkdownBlock]? = nil,
        codeBlock: MarkdownCodeBlock? = nil
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
            attributedText: attributedText,
            children: children ?? self.children,
            codeBlock: codeBlock ?? self.codeBlock
        )
    }
}
