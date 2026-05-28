import Foundation

nonisolated enum MermaidMarkdownBlockCatalog {
    nonisolated static func annotate(blocks: [MarkdownBlock]) -> [MarkdownBlock] {
        blocks.map(annotate(_:))
    }

    nonisolated static func standaloneBlock(
        from source: String,
        path: WorkspacePath,
        id: String = "block.0"
    ) -> MarkdownBlock {
        let diagram = MermaidCompiler.compile(source: source, context: .file(path))
        return block(from: diagram, id: id, sourceText: source)
    }

    private nonisolated static func annotate(_ block: MarkdownBlock) -> MarkdownBlock {
        let annotatedChildren = block.children.map(annotate(_:))
        guard block.kind == .codeBlock,
              let codeBlock = block.codeBlock,
              codeBlock.isFenced,
              isMermaidFence(infoString: codeBlock.infoString, rawLanguage: codeBlock.rawLanguage) else {
            return block.replacing(children: annotatedChildren)
        }

        let diagram = MermaidCompiler.compile(source: codeBlock.code, context: .inline)
        return self.block(
            from: diagram,
            id: block.id,
            sourceText: codeBlock.code,
            indentLevel: block.indentLevel
        )
    }

    private nonisolated static func isMermaidFence(infoString: String?, rawLanguage: String?) -> Bool {
        if rawLanguage == "mermaid" || rawLanguage == "mmd" {
            return true
        }
        let normalized = infoString?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized == "mermaid" || normalized == "mmd"
    }

    private nonisolated static func block(
        from diagram: MarkdownMermaidDiagram,
        id: String,
        sourceText: String,
        indentLevel: Int = 0
    ) -> MarkdownBlock {
        MarkdownBlock(
            id: id,
            kind: .mermaidDiagram,
            plainText: diagram.plainTextSummary,
            sourceText: sourceText.trimmingCharacters(in: .newlines),
            level: nil,
            listItemIndex: nil,
            indentLevel: indentLevel,
            isTaskItem: false,
            isTaskCompleted: nil,
            table: nil,
            image: nil,
            video: nil,
            mermaidDiagram: diagram,
            attributedText: nil,
            children: [],
            codeBlock: nil
        )
    }
}
