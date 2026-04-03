import Foundation

struct WorkspacePath: Hashable, Codable, Identifiable, Sendable {
    let rawValue: String

    var id: String { rawValue }
}

struct MarkdownFileNode: Identifiable, Hashable, Sendable {
    let path: WorkspacePath
    let name: String

    var id: String { path.rawValue }
}

struct Workspace: Sendable {
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
    let resolvedURL: URL?
}

struct MarkdownVideo: Hashable, Sendable {
    let altText: String
    let sourceURL: String
    let title: String?
    let resolvedURL: URL?
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
}

extension MarkdownBlock {
    nonisolated func replacing(
        kind: MarkdownBlockKind? = nil,
        image: MarkdownImage? = nil,
        video: MarkdownVideo? = nil,
        children: [MarkdownBlock]? = nil
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
            children: children ?? self.children
        )
    }
}
