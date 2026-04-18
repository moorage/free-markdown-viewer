import CoreGraphics
import Foundation

enum DocumentPrintScope: String, Sendable {
    case selectedFile
    case allFiles

    var title: String {
        switch self {
        case .selectedFile:
            return "Print"
        case .allFiles:
            return "Print All"
        }
    }
}

struct DocumentPrintSection: Equatable, Sendable {
    let path: WorkspacePath
    let title: String
    let kind: WorkspaceDocumentKind
    let blocks: [MarkdownBlock]

    var plainText: String {
        switch kind {
        case .markdown:
            return DocumentPlainTextRenderer.render(blocks: blocks)
        case .csv, .tsv:
            guard let table = blocks.first?.table else { return "" }
            return DocumentPlainTextRenderer.renderTable(table)
        }
    }
}

struct DocumentPrintComposition: Equatable, Sendable {
    let scope: DocumentPrintScope
    let workspaceTitle: String
    let fontScale: Double
    let launchTheme: String?
    let tabularPresentation: TabularDocumentPresentation
    let sections: [DocumentPrintSection]

    var plainText: String {
        sections.enumerated().map { index, section in
            let heading = "=== \(section.title) ==="
            if index == 0 {
                return "\(heading)\n\n\(section.plainText)"
            }
            return "\(heading)\n\n\(section.plainText)"
        }
        .joined(separator: "\n\n\n")
    }
}

struct DocumentPrintPageLayout: Equatable, Sendable {
    let paperSize: CGSize
    let topInset: CGFloat
    let leadingInset: CGFloat
    let bottomInset: CGFloat
    let trailingInset: CGFloat

    static let letter = DocumentPrintPageLayout(
        paperSize: CGSize(width: 612, height: 792),
        topInset: 36,
        leadingInset: 36,
        bottomInset: 36,
        trailingInset: 36
    )

    var printableRect: CGRect {
        CGRect(
            x: leadingInset,
            y: topInset,
            width: paperSize.width - leadingInset - trailingInset,
            height: paperSize.height - topInset - bottomInset
        )
    }
}

enum DocumentPlainTextRenderer {
    nonisolated static func render(blocks: [MarkdownBlock]) -> String {
        blocks.enumerated().map { index, block in
            let rendered = render(block: block)
            if index == blocks.indices.last {
                return rendered
            }
            return "\(rendered)\n\n"
        }
        .joined()
    }

    nonisolated static func renderTable(_ table: MarkdownTable) -> String {
        var lines: [String] = []
        lines.append(renderRow(table.header))
        lines.append(String(repeating: "-", count: max(table.header.count * 4, 4)))
        lines.append(contentsOf: table.rows.map(renderRow))
        return lines.joined(separator: "\n")
    }

    private nonisolated static func render(block: MarkdownBlock) -> String {
        switch block.kind {
        case .heading, .paragraph:
            return block.plainText
        case .unorderedListItem:
            return listPrefix(for: block) + block.plainText + renderedChildren(for: block)
        case .orderedListItem:
            return listPrefix(for: block) + block.plainText + renderedChildren(for: block)
        case .blockquote:
            return "> " + block.plainText + renderedChildren(for: block)
        case .codeBlock, .rawHTML:
            return block.sourceText
        case .table:
            guard let table = block.table else { return block.plainText }
            return renderTable(table)
        case .image, .animatedImage:
            guard let image = block.image else { return block.plainText }
            return ["Image", image.altText, image.sourceURL]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        case .video:
            guard let video = block.video else { return block.plainText }
            return ["Video", video.altText, video.sourceURL]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        case .thematicBreak:
            return String(repeating: "-", count: 24)
        }
    }

    private nonisolated static func renderRow(_ row: [MarkdownTableCell]) -> String {
        row.map(\.plainText).joined(separator: " | ")
    }

    private nonisolated static func listPrefix(for block: MarkdownBlock) -> String {
        if block.isTaskItem {
            return block.isTaskCompleted == true ? "[x] " : "[ ] "
        }
        if block.kind == .orderedListItem {
            return "\(block.listItemIndex ?? 1). "
        }
        return "- "
    }

    private nonisolated static func renderedChildren(for block: MarkdownBlock) -> String {
        guard !block.children.isEmpty else { return "" }
        let childText = block.children.map { render(block: $0) }.joined(separator: "\n")
        return "\n" + childText
    }
}
