import Cocoa
import Quartz

final class PreviewViewController: NSViewController, QLPreviewingController {
    private enum PreviewMode: Equatable {
        case rendered
        case source
    }

    private let textView = NSTextView(frame: .zero)
    private let modeControl = NSSegmentedControl(
        labels: ["Rendered", "Source"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private var renderedPreview = NSAttributedString()
    private var sourcePreview = NSAttributedString()
    private var selectedMode: PreviewMode = .rendered

    override func loadView() {
        let rootView = NSView(frame: .zero)
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        let stackView = NSStackView(frame: .zero)
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let toolbarView = NSView(frame: .zero)
        toolbarView.translatesAutoresizingMaskIntoConstraints = false

        modeControl.target = self
        modeControl.action = #selector(modeControlChanged(_:))
        modeControl.selectedSegment = 0
        modeControl.controlSize = .small
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.addSubview(modeControl)

        let scrollView = NSScrollView(frame: .zero)
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 28, height: 28)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.linkTextAttributes = MarkdownQuickLookPreviewFormatter.linkTextAttributes

        scrollView.documentView = textView
        stackView.addArrangedSubview(toolbarView)
        stackView.addArrangedSubview(scrollView)
        rootView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: rootView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            toolbarView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: 44),
            modeControl.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor, constant: 16),
            modeControl.centerYAnchor.constraint(equalTo: toolbarView.centerYAnchor),

            scrollView.widthAnchor.constraint(equalTo: stackView.widthAnchor),
        ])

        view = rootView
        preferredContentSize = NSSize(width: 760, height: 680)
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let source = try await Task.detached(priority: .userInitiated) {
            try MarkdownQuickLookPreviewFormatter.markdownSource(at: url)
        }.value

        loadPreview(for: url, source: source)
    }

    @objc(renderPreviewForTestingAtURL:)
    func renderPreviewForTesting(at url: NSURL) -> NSAttributedString? {
        guard let source = try? MarkdownQuickLookPreviewFormatter.markdownSource(at: url as URL) else {
            return nil
        }
        return MarkdownQuickLookPreviewFormatter.attributedPreview(for: url as URL, source: source)
    }

    @objc(preparePreviewForTestingAtURL:)
    func preparePreviewForTesting(at url: NSURL) -> NSNumber {
        guard let source = try? MarkdownQuickLookPreviewFormatter.markdownSource(at: url as URL) else {
            return NSNumber(value: false)
        }
        _ = view
        loadPreview(for: url as URL, source: source)
        return NSNumber(value: true)
    }

    @objc(selectRenderedPreviewForTesting)
    func selectRenderedPreviewForTesting() {
        selectPreviewMode(.rendered)
    }

    @objc(selectSourcePreviewForTesting)
    func selectSourcePreviewForTesting() {
        selectPreviewMode(.source)
    }

    @objc(currentPreviewTextForTesting)
    func currentPreviewTextForTesting() -> NSString {
        textView.string as NSString
    }

    private func loadPreview(for url: URL, source: String) {
        title = url.lastPathComponent
        renderedPreview = MarkdownQuickLookPreviewFormatter.attributedPreview(for: url, source: source)
        sourcePreview = MarkdownQuickLookPreviewFormatter.rawSourcePreview(from: source)
        selectPreviewMode(.rendered)
    }

    @objc
    private func modeControlChanged(_ sender: NSSegmentedControl) {
        selectPreviewMode(sender.selectedSegment == 1 ? .source : .rendered)
    }

    private func selectPreviewMode(_ mode: PreviewMode) {
        selectedMode = mode
        modeControl.selectedSegment = mode == .source ? 1 : 0
        switch mode {
        case .rendered:
            textView.textStorage?.setAttributedString(renderedPreview)
        case .source:
            textView.textStorage?.setAttributedString(sourcePreview)
        }
    }
}

private enum MarkdownQuickLookPreviewFormatter {
    private enum DocumentKind {
        case markdown
        case mermaid
        case delimited(separator: Character)
        case plainText
    }

    private struct CodeFence {
        let marker: String
        let infoString: String

        var isMermaid: Bool {
            let language = infoString
                .split(whereSeparator: { $0.isWhitespace })
                .first?
                .lowercased()
            return language == "mermaid" || language == "mmd"
        }
    }

    private struct ImageReference {
        let altText: String
        let source: String
        let title: String?
    }

    private struct MermaidPreviewDiagram {
        let title: String
        let kind: String
        let direction: MermaidPreviewDirection
        let nodes: [MermaidPreviewNode]
        let edges: [MermaidPreviewEdge]
    }

    private struct MermaidPreviewNode: Hashable {
        let id: String
        let label: String
    }

    private struct MermaidPreviewEdge {
        let sourceID: String
        let targetID: String
        let label: String?
        let style: MermaidPreviewEdgeStyle
    }

    private enum MermaidPreviewDirection {
        case topBottom
        case bottomTop
        case leftRight
        case rightLeft
    }

    private enum MermaidPreviewEdgeStyle {
        case solid
        case dotted
        case thick
        case open
    }

    private struct MermaidPreviewLayout {
        let canvasSize: NSSize
        let nodeSize: NSSize
        let positions: [String: CGPoint]
    }

    static var linkTextAttributes: [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
    }

    nonisolated static func markdownSource(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if let source = String(data: data, encoding: .utf8) {
            return source
        }
        if let source = String(data: data, encoding: .utf16) {
            return source
        }
        if let source = String(data: data, encoding: .isoLatin1) {
            return source
        }
        return String(decoding: data, as: UTF8.self)
    }

    static func attributedPreview(for url: URL, source: String) -> NSAttributedString {
        switch documentKind(for: url) {
        case .markdown:
            return markdownPreview(from: source, documentURL: url)
        case .mermaid:
            return mermaidPreview(from: source)
        case let .delimited(separator):
            return delimitedPreview(from: source, separator: separator)
        case .plainText:
            return codeBlock(source)
        }
    }

    static func rawSourcePreview(from source: String) -> NSAttributedString {
        codeBlock(source)
    }

    private static func documentKind(for url: URL) -> DocumentKind {
        switch url.pathExtension.lowercased() {
        case "md", "markdown", "mdown", "mkd", "mkdn":
            return .markdown
        case "mermaid", "mmd":
            return .mermaid
        case "csv":
            return .delimited(separator: ",")
        case "tsv":
            return .delimited(separator: "\t")
        default:
            return .plainText
        }
    }

    private static func markdownPreview(from source: String, documentURL: URL) -> NSAttributedString {
        let rendered = NSMutableAttributedString()
        let lines = normalizedLines(from: source)
        let imageReferences = imageReferenceDefinitions(in: lines)
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }

            if let fence = codeFence(in: trimmed) {
                var codeLines: [String] = []
                index += 1
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    if candidate.hasPrefix(fence.marker) {
                        index += 1
                        break
                    }
                    codeLines.append(lines[index])
                    index += 1
                }
                let code = codeLines.joined(separator: "\n")
                append(fence.isMermaid ? mermaidPreview(from: code) : codeBlock(code), to: rendered)
                continue
            }

            if isImageReferenceDefinition(trimmed) {
                index += 1
                continue
            }

            if let table = tableRows(in: lines, at: index) {
                append(tableBlock(header: table.header, rows: table.rows), to: rendered)
                index = table.nextIndex
                continue
            }

            if let heading = heading(in: trimmed) {
                append(inlineText(heading.text, attributes: headingAttributes(level: heading.level)), to: rendered)
                index += 1
                continue
            }

            if let listItem = listItem(in: trimmed) {
                append(inlineText("\(listItem.marker) \(listItem.text)", attributes: bodyAttributes()), to: rendered)
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                let text = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                append(inlineText("> \(text)", attributes: quoteAttributes()), to: rendered)
                index += 1
                continue
            }

            if let image = imageReference(in: trimmed, references: imageReferences) {
                append(imagePreview(image, relativeTo: documentURL), to: rendered)
                index += 1
                continue
            }

            if isThematicBreak(trimmed) {
                append(NSAttributedString(string: String(repeating: "-", count: 28), attributes: secondaryAttributes()), to: rendered)
                index += 1
                continue
            }

            var paragraphLines = [trimmed]
            index += 1
            while index < lines.count {
                let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                if candidate.isEmpty || startsSpecialMarkdownBlock(candidate, lines: lines, index: index) {
                    break
                }
                paragraphLines.append(candidate)
                index += 1
            }
            append(inlineText(paragraphLines.joined(separator: " "), attributes: bodyAttributes()), to: rendered)
        }

        return rendered
    }

    private static func mermaidPreview(from source: String) -> NSAttributedString {
        let rendered = NSMutableAttributedString()
        append(NSAttributedString(string: "Mermaid Diagram", attributes: headingAttributes(level: 1)), to: rendered)

        let diagram = compileMermaidPreview(from: source)
        let subtitle = diagram.title == "Mermaid Diagram" ? diagram.kind : "\(diagram.title)\n\(diagram.kind)"
        rendered.append(NSAttributedString(string: "\n\(subtitle)", attributes: secondaryAttributes()))

        let attachment = NSTextAttachment()
        attachment.image = renderMermaidPreviewImage(diagram)
        rendered.append(NSAttributedString(string: "\n"))
        rendered.append(NSAttributedString(attachment: attachment))

        return rendered
    }

    private static func compileMermaidPreview(from source: String) -> MermaidPreviewDiagram {
        let parsedSource = mermaidSourceLines(from: source)
        let lines = parsedSource.lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
        let declaration = lines.first ?? ""
        let direction = mermaidDirection(from: declaration)
        let kind = mermaidKind(from: declaration)
        var title = parsedSource.title ?? "Mermaid Diagram"
        var nodesByID: [String: MermaidPreviewNode] = [:]
        var nodeOrder: [String] = []
        var edges: [MermaidPreviewEdge] = []

        func addNode(_ node: MermaidPreviewNode) {
            if nodesByID[node.id] == nil {
                nodesByID[node.id] = node
                nodeOrder.append(node.id)
            }
        }

        for line in lines.dropFirst() {
            let lowered = line.lowercased()
            if lowered.hasPrefix("title ") {
                title = String(line.dropFirst("title ".count)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if lowered.hasPrefix("acctitle:") {
                title = String(line.dropFirst("acctitle:".count)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if lowered == "end" ||
                lowered.hasPrefix("subgraph ") ||
                lowered.hasPrefix("accdescr:") ||
                lowered.hasPrefix("theme:") ||
                lowered.hasPrefix("layout:") {
                continue
            }
            if let parsed = mermaidEdge(in: line) {
                addNode(parsed.source)
                addNode(parsed.target)
                edges.append(parsed.edge)
            } else if let node = mermaidNode(in: line) {
                addNode(node)
            }
        }

        let nodes = nodeOrder.compactMap { nodesByID[$0] }
        return MermaidPreviewDiagram(
            title: title,
            kind: kind,
            direction: direction,
            nodes: nodes.isEmpty ? [MermaidPreviewNode(id: "diagram", label: kind)] : nodes,
            edges: edges
        )
    }

    private static func mermaidSourceLines(from source: String) -> (lines: [String], title: String?) {
        let lines = normalizedLines(from: source)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return (lines, nil)
        }

        guard let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return (lines, nil)
        }

        let frontmatterLines = Array(lines[1..<closingIndex])
        let bodyLines = Array(lines[(closingIndex + 1)..<lines.count])
        let title = frontmatterLines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().hasPrefix("title:") else { return nil }
            return String(trimmed.dropFirst("title:".count))
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }.first
        return (bodyLines, title)
    }

    private static func mermaidKind(from declaration: String) -> String {
        let lowered = declaration.lowercased()
        if lowered.hasPrefix("flowchart") || lowered.hasPrefix("graph") {
            return "Flowchart"
        }
        if lowered.hasPrefix("sequencediagram") {
            return "Sequence Diagram"
        }
        return "Mermaid Diagram"
    }

    private static func mermaidDirection(from declaration: String) -> MermaidPreviewDirection {
        let tokens = declaration
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.lowercased() }
        guard tokens.count > 1 else { return .topBottom }
        switch tokens[1] {
        case "lr":
            return .leftRight
        case "rl":
            return .rightLeft
        case "bt":
            return .bottomTop
        default:
            return .topBottom
        }
    }

    private static func mermaidEdge(
        in line: String
    ) -> (source: MermaidPreviewNode, target: MermaidPreviewNode, edge: MermaidPreviewEdge)? {
        let operators = ["<-->", "-->", "==>", "-.->", "<--", "---", "--x", "--o", "--"]
        guard let match = operators.compactMap({ operation -> (String, Range<String.Index>)? in
            guard let range = line.range(of: operation) else { return nil }
            return (operation, range)
        }).min(by: { line.distance(from: line.startIndex, to: $0.1.lowerBound) < line.distance(from: line.startIndex, to: $1.1.lowerBound) }) else {
            return nil
        }

        let rawLeft = String(line[..<match.1.lowerBound]).trimmingCharacters(in: .whitespaces)
        let rightAndLabel = String(line[match.1.upperBound...]).trimmingCharacters(in: .whitespaces)
        let labelSplit = rightAndLabel.components(separatedBy: "|")
        let rawRight = labelSplit.last?.trimmingCharacters(in: .whitespaces) ?? rightAndLabel
        let label = labelSplit.count >= 3 ? normalizedMermaidLabel(labelSplit[1]) : nil
        guard let source = mermaidNode(in: rawLeft),
              let target = mermaidNode(in: rawRight) else {
            return nil
        }

        let style: MermaidPreviewEdgeStyle
        if match.0.contains("==") {
            style = .thick
        } else if match.0.contains(".") {
            style = .dotted
        } else if !match.0.contains(">") && !match.0.contains("<") {
            style = .open
        } else {
            style = .solid
        }

        return (
            source,
            target,
            MermaidPreviewEdge(sourceID: source.id, targetID: target.id, label: label, style: style)
        )
    }

    private static func mermaidNode(in token: String) -> MermaidPreviewNode? {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let pattern = #"^([A-Za-z0-9_.:-]+)(?:\[(.*?)\]|\((.*?)\)|\{(.*?)\})?.*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)),
              let idRange = Range(match.range(at: 1), in: trimmed) else {
            return nil
        }

        let rawID = String(trimmed[idRange])
        let label = (2...4).compactMap { index -> String? in
            guard let range = Range(match.range(at: index), in: trimmed) else { return nil }
            return normalizedMermaidLabel(String(trimmed[range]))
        }.first
        return MermaidPreviewNode(id: rawID.lowercased(), label: label ?? normalizedMermaidLabel(rawID))
    }

    private static func normalizedMermaidLabel(_ label: String) -> String {
        label
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func renderMermaidPreviewImage(_ diagram: MermaidPreviewDiagram) -> NSImage {
        let layout = mermaidLayout(for: diagram)
        let image = NSImage(size: layout.canvasSize)
        image.lockFocus()
        defer { image.unlockFocus() }

        let canvas = NSRect(origin: .zero, size: layout.canvasSize)
        NSColor.controlBackgroundColor.setFill()
        canvas.fill()
        drawMermaidGrid(in: canvas)

        for edge in diagram.edges {
            guard let start = layout.positions[edge.sourceID],
                  let end = layout.positions[edge.targetID] else {
                continue
            }
            let endpoints = mermaidEdgeEndpoints(from: start, to: end, nodeSize: layout.nodeSize)
            drawMermaidEdge(edge, from: endpoints.start, to: endpoints.end, direction: diagram.direction)
        }

        for node in diagram.nodes {
            guard let position = layout.positions[node.id] else { continue }
            drawMermaidNode(node, at: position, size: layout.nodeSize)
        }

        return image
    }

    private static func drawMermaidGrid(in rect: NSRect) {
        NSColor.separatorColor.withAlphaComponent(0.18).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 0.6
        var x = rect.minX
        while x <= rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.line(to: CGPoint(x: x, y: rect.maxY))
            x += 28
        }
        var y = rect.minY
        while y <= rect.maxY {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.line(to: CGPoint(x: rect.maxX, y: y))
            y += 28
        }
        path.stroke()
    }

    private static func drawMermaidEdge(
        _ edge: MermaidPreviewEdge,
        from start: CGPoint,
        to end: CGPoint,
        direction: MermaidPreviewDirection
    ) {
        let path = NSBezierPath()
        path.move(to: start)
        switch direction {
        case .leftRight, .rightLeft:
            let controlX = (start.x + end.x) / 2
            path.curve(
                to: end,
                controlPoint1: CGPoint(x: controlX, y: start.y),
                controlPoint2: CGPoint(x: controlX, y: end.y)
            )
        case .topBottom, .bottomTop:
            let controlY = (start.y + end.y) / 2
            path.curve(
                to: end,
                controlPoint1: CGPoint(x: start.x, y: controlY),
                controlPoint2: CGPoint(x: end.x, y: controlY)
            )
        }
        path.lineWidth = edge.style == .thick ? 3 : 1.8
        if edge.style == .dotted {
            path.setLineDash([6, 5], count: 2, phase: 0)
        }
        NSColor.controlAccentColor.withAlphaComponent(edge.style == .open ? 0.56 : 0.86).setStroke()
        path.stroke()
        drawMermaidArrowhead(from: start, to: end)

        if let label = edge.label, !label.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
            let textSize = label.size(withAttributes: attributes)
            label.draw(
                at: CGPoint(
                    x: (start.x + end.x - textSize.width) / 2,
                    y: (start.y + end.y - textSize.height) / 2 + 8
                ),
                withAttributes: attributes
            )
        }
    }

    private static func drawMermaidArrowhead(from start: CGPoint, to end: CGPoint) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let length: CGFloat = 9
        let left = CGPoint(
            x: end.x - length * cos(angle - .pi / 6),
            y: end.y - length * sin(angle - .pi / 6)
        )
        let right = CGPoint(
            x: end.x - length * cos(angle + .pi / 6),
            y: end.y - length * sin(angle + .pi / 6)
        )
        let path = NSBezierPath()
        path.move(to: end)
        path.line(to: left)
        path.move(to: end)
        path.line(to: right)
        path.lineWidth = 1.8
        NSColor.controlAccentColor.withAlphaComponent(0.86).setStroke()
        path.stroke()
    }

    private static func drawMermaidNode(_ node: MermaidPreviewNode, at position: CGPoint, size: NSSize) {
        let rect = NSRect(
            x: position.x - size.width / 2,
            y: position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        let background = NSBezierPath(roundedRect: rect, xRadius: 13, yRadius: 13)
        NSColor.textBackgroundColor.withAlphaComponent(0.94).setFill()
        background.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.35).setStroke()
        background.lineWidth = 1
        background.stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        let textRect = rect.insetBy(dx: 10, dy: 16)
        node.label.draw(in: textRect, withAttributes: attributes)
    }

    private static func mermaidLayout(for diagram: MermaidPreviewDiagram) -> MermaidPreviewLayout {
        let nodeSize = NSSize(width: 156, height: 62)
        let ranks = mermaidRanks(for: diagram)
        let rankValues = Array(Set(ranks.values)).sorted()
        let groups = rankValues.map { rank in
            diagram.nodes.filter { ranks[$0.id] == rank }
        }
        let rankCount = max(groups.count, 1)
        let maxLaneCount = max(groups.map(\.count).max() ?? 1, 1)
        let horizontalInset: CGFloat = 62
        let verticalInset: CGFloat = 48
        let rankGap: CGFloat = 54
        let laneGap: CGFloat = 18
        let canvasSize: NSSize
        var positions: [String: CGPoint] = [:]

        switch diagram.direction {
        case .leftRight, .rightLeft:
            canvasSize = NSSize(
                width: max(620, horizontalInset * 2 + CGFloat(rankCount) * nodeSize.width + CGFloat(max(rankCount - 1, 0)) * rankGap),
                height: max(260, verticalInset * 2 + CGFloat(maxLaneCount) * nodeSize.height + CGFloat(max(maxLaneCount - 1, 0)) * laneGap)
            )
            for (rankIndex, group) in groups.enumerated() {
                let visualRankIndex = diagram.direction == .rightLeft ? rankCount - 1 - rankIndex : rankIndex
                let x = horizontalInset + nodeSize.width / 2 + CGFloat(visualRankIndex) * (nodeSize.width + rankGap)
                let groupHeight = CGFloat(group.count) * nodeSize.height + CGFloat(max(group.count - 1, 0)) * laneGap
                let top = (canvasSize.height - groupHeight) / 2
                for (laneIndex, node) in group.enumerated() {
                    positions[node.id] = CGPoint(
                        x: x,
                        y: top + nodeSize.height / 2 + CGFloat(laneIndex) * (nodeSize.height + laneGap)
                    )
                }
            }
        case .topBottom, .bottomTop:
            canvasSize = NSSize(
                width: max(620, horizontalInset * 2 + CGFloat(maxLaneCount) * nodeSize.width + CGFloat(max(maxLaneCount - 1, 0)) * laneGap),
                height: max(260, verticalInset * 2 + CGFloat(rankCount) * nodeSize.height + CGFloat(max(rankCount - 1, 0)) * rankGap)
            )
            for (rankIndex, group) in groups.enumerated() {
                let visualRankIndex = diagram.direction == .bottomTop ? rankCount - 1 - rankIndex : rankIndex
                let y = verticalInset + nodeSize.height / 2 + CGFloat(visualRankIndex) * (nodeSize.height + rankGap)
                let groupWidth = CGFloat(group.count) * nodeSize.width + CGFloat(max(group.count - 1, 0)) * laneGap
                let left = (canvasSize.width - groupWidth) / 2
                for (laneIndex, node) in group.enumerated() {
                    positions[node.id] = CGPoint(
                        x: left + nodeSize.width / 2 + CGFloat(laneIndex) * (nodeSize.width + laneGap),
                        y: y
                    )
                }
            }
        }

        return MermaidPreviewLayout(canvasSize: canvasSize, nodeSize: nodeSize, positions: positions)
    }

    private static func mermaidRanks(for diagram: MermaidPreviewDiagram) -> [String: Int] {
        let nodeIDs = diagram.nodes.map(\.id)
        let nodeIDSet = Set(nodeIDs)
        var ranks = Dictionary(uniqueKeysWithValues: nodeIDs.map { ($0, 0) })
        var incomingCounts = Dictionary(uniqueKeysWithValues: nodeIDs.map { ($0, 0) })
        var outgoing: [String: [String]] = [:]

        for edge in diagram.edges where nodeIDSet.contains(edge.sourceID) && nodeIDSet.contains(edge.targetID) && edge.sourceID != edge.targetID {
            outgoing[edge.sourceID, default: []].append(edge.targetID)
            incomingCounts[edge.targetID, default: 0] += 1
        }

        var queue = nodeIDs.filter { incomingCounts[$0, default: 0] == 0 }
        var processed: Set<String> = []
        while !queue.isEmpty {
            let sourceID = queue.removeFirst()
            guard processed.insert(sourceID).inserted else { continue }
            for targetID in outgoing[sourceID] ?? [] {
                ranks[targetID] = max(ranks[targetID, default: 0], ranks[sourceID, default: 0] + 1)
                incomingCounts[targetID, default: 0] -= 1
                if incomingCounts[targetID, default: 0] == 0 {
                    queue.append(targetID)
                }
            }
        }

        var fallbackRank = (ranks.values.max() ?? 0) + 1
        for nodeID in nodeIDs where !processed.contains(nodeID) {
            ranks[nodeID] = max(ranks[nodeID, default: 0], fallbackRank)
            fallbackRank += 1
        }
        return ranks
    }

    private static func mermaidEdgeEndpoints(
        from start: CGPoint,
        to end: CGPoint,
        nodeSize: NSSize
    ) -> (start: CGPoint, end: CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        guard dx != 0 || dy != 0 else { return (start, end) }
        let startOffset = mermaidBoundaryOffset(dx: dx, dy: dy, nodeSize: nodeSize)
        let endOffset = mermaidBoundaryOffset(dx: -dx, dy: -dy, nodeSize: nodeSize)
        return (
            CGPoint(x: start.x + startOffset.dx, y: start.y + startOffset.dy),
            CGPoint(x: end.x + endOffset.dx, y: end.y + endOffset.dy)
        )
    }

    private static func mermaidBoundaryOffset(dx: CGFloat, dy: CGFloat, nodeSize: NSSize) -> CGVector {
        let halfWidth = nodeSize.width / 2
        let halfHeight = nodeSize.height / 2
        let xScale = dx == 0 ? CGFloat.greatestFiniteMagnitude : halfWidth / abs(dx)
        let yScale = dy == 0 ? CGFloat.greatestFiniteMagnitude : halfHeight / abs(dy)
        let scale = min(xScale, yScale)
        return CGVector(dx: dx * scale, dy: dy * scale)
    }

    private static func delimitedPreview(from source: String, separator: Character) -> NSAttributedString {
        let rows = normalizedLines(from: source)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { splitDelimitedRow($0, separator: separator) }
        guard let header = rows.first else { return codeBlock(source) }
        return tableBlock(header: header, rows: Array(rows.dropFirst()))
    }

    private static func append(_ block: NSAttributedString, to rendered: NSMutableAttributedString) {
        if rendered.length > 0 {
            rendered.append(NSAttributedString(string: "\n\n"))
        }
        rendered.append(block)
    }

    private static func inlineText(_ text: String, attributes: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        let parsed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        let rendered = NSMutableAttributedString(parsed ?? AttributedString(text))
        rendered.addAttributes(attributes, range: NSRange(location: 0, length: rendered.length))
        applyLinkStyling(to: rendered)
        return rendered
    }

    private static func codeBlock(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: codeAttributes())
    }

    private static func tableBlock(header: [String], rows: [[String]]) -> NSAttributedString {
        let columnCount = max(header.count, rows.map(\.count).max() ?? 0)
        guard columnCount > 0 else { return NSAttributedString(string: "", attributes: bodyAttributes()) }

        var widths = Array(repeating: 0, count: columnCount)
        for row in [header] + rows {
            for index in 0..<columnCount {
                widths[index] = max(widths[index], index < row.count ? row[index].count : 0)
            }
        }

        func padded(_ row: [String]) -> String {
            (0..<columnCount)
                .map { index in
                    let value = index < row.count ? row[index] : ""
                    return value.padding(toLength: widths[index], withPad: " ", startingAt: 0)
                }
                .joined(separator: "  ")
        }

        let divider = widths.map { String(repeating: "-", count: max($0, 3)) }.joined(separator: "  ")
        let lines = [padded(header), divider] + rows.map(padded)
        return NSAttributedString(string: lines.joined(separator: "\n"), attributes: codeAttributes())
    }

    private static func normalizedLines(from source: String) -> [String] {
        source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    private static func heading(in line: String) -> (level: Int, text: String)? {
        let level = line.prefix { $0 == "#" }.count
        guard (1...6).contains(level), line.dropFirst(level).first == " " else { return nil }
        return (level, String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces))
    }

    private static func listItem(in line: String) -> (marker: String, text: String)? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            let text = String(line.dropFirst(marker.count))
            if let task = taskItem(in: text) {
                return task
            }
            return ("-", text)
        }

        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return ("\(digits).", String(rest.dropFirst(2)))
    }

    private static func taskItem(in text: String) -> (marker: String, text: String)? {
        if text.hasPrefix("[ ] ") {
            return ("[ ]", String(text.dropFirst(4)))
        }
        if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") {
            return ("[x]", String(text.dropFirst(4)))
        }
        return nil
    }

    private static func isThematicBreak(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3, let first = compact.first else { return false }
        return [Character("-"), Character("*"), Character("_")].contains(first) && compact.allSatisfy { $0 == first }
    }

    private static func codeFence(in line: String) -> CodeFence? {
        if line.hasPrefix("```") {
            return CodeFence(
                marker: "```",
                infoString: String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            )
        }
        if line.hasPrefix("~~~") {
            return CodeFence(
                marker: "~~~",
                infoString: String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            )
        }
        return nil
    }

    private static func startsSpecialMarkdownBlock(_ line: String, lines: [String], index: Int) -> Bool {
        heading(in: line) != nil ||
            listItem(in: line) != nil ||
            line.hasPrefix(">") ||
            imageReference(in: line, references: imageReferenceDefinitions(in: lines)) != nil ||
            isThematicBreak(line) ||
            codeFence(in: line) != nil ||
            tableRows(in: lines, at: index) != nil
    }

    private static func imagePreview(_ image: ImageReference, relativeTo documentURL: URL) -> NSAttributedString {
        let rendered = NSMutableAttributedString()
        if let resolvedURL = localImageURL(from: image.source, relativeTo: documentURL),
           let previewImage = scaledImage(at: resolvedURL) {
            let attachment = NSTextAttachment()
            attachment.image = previewImage
            rendered.append(NSAttributedString(attachment: attachment))
        } else {
            rendered.append(NSAttributedString(string: "Image preview unavailable", attributes: secondaryAttributes()))
        }

        let label = image.altText.isEmpty ? "Image" : image.altText
        let title = image.title.map { "\nTitle: \($0)" } ?? ""
        rendered.append(NSAttributedString(string: "\n\(label)\nSource: \(image.source)\(title)", attributes: secondaryAttributes()))
        return rendered
    }

    private static func localImageURL(from source: String, relativeTo documentURL: URL) -> URL? {
        let normalizedSource = source.removingPercentEncoding ?? source
        guard !normalizedSource.contains("://"),
              !normalizedSource.lowercased().hasPrefix("data:"),
              isPreviewableImageSource(normalizedSource) else {
            return nil
        }

        let url: URL
        if normalizedSource.hasPrefix("/") {
            url = URL(fileURLWithPath: normalizedSource)
        } else {
            url = documentURL.deletingLastPathComponent()
                .appendingPathComponent(normalizedSource)
                .standardizedFileURL
        }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func scaledImage(at url: URL) -> NSImage? {
        guard let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              fileSize <= 10 * 1024 * 1024,
              let image = NSImage(contentsOf: url),
              image.size.width > 0,
              image.size.height > 0 else {
            return nil
        }

        let maxSize = NSSize(width: 540, height: 320)
        let scale = min(1, maxSize.width / image.size.width, maxSize.height / image.size.height)
        let targetSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let scaled = NSImage(size: targetSize)
        scaled.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize))
        scaled.unlockFocus()
        return scaled
    }

    private static func isPreviewableImageSource(_ source: String) -> Bool {
        switch URL(fileURLWithPath: source).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "tif", "tiff":
            return true
        default:
            return false
        }
    }

    private static func imageReferenceDefinitions(in lines: [String]) -> [String: ImageReference] {
        var references: [String: ImageReference] = [:]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let definition = imageReferenceDefinition(in: trimmed) else { continue }
            references[definition.label] = definition.image
        }
        return references
    }

    private static func imageReference(in line: String, references: [String: ImageReference]) -> ImageReference? {
        if let direct = directImageReference(in: line) {
            return direct
        }

        let pattern = #"^!\[([^\]]*)\](?:(?:\[\])|(?:\[([^\]]*)\]))?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, range: range),
              let altRange = Range(match.range(at: 1), in: line) else {
            return nil
        }

        let altText = normalizedInlineText(String(line[altRange]))
        let label: String
        if let explicitLabelRange = Range(match.range(at: 2), in: line) {
            label = normalizedInlineText(String(line[explicitLabelRange])).lowercased()
        } else {
            label = altText.lowercased()
        }
        guard let referenced = references[label] else { return nil }
        return ImageReference(altText: altText, source: referenced.source, title: referenced.title)
    }

    private static func directImageReference(in line: String) -> ImageReference? {
        let pattern = #"^!\[([^\]]*)\]\((\S+?)(?:\s+"([^"]*)")?\)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, range: range),
              let altRange = Range(match.range(at: 1), in: line),
              let sourceRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let titleRange = Range(match.range(at: 3), in: line)
        return ImageReference(
            altText: normalizedInlineText(String(line[altRange])),
            source: String(line[sourceRange]),
            title: titleRange.map { String(line[$0]) }
        )
    }

    private static func imageReferenceDefinition(in line: String) -> (label: String, image: ImageReference)? {
        let pattern = #"^\[([^\]]+)\]:\s+(\S+)(?:\s+"([^"]*)")?\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: line.utf16.count)
        guard let match = regex.firstMatch(in: line, range: range),
              let labelRange = Range(match.range(at: 1), in: line),
              let sourceRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let titleRange = Range(match.range(at: 3), in: line)
        let label = normalizedInlineText(String(line[labelRange])).lowercased()
        let image = ImageReference(
            altText: "",
            source: String(line[sourceRange]),
            title: titleRange.map { String(line[$0]) }
        )
        return (label, image)
    }

    private static func isImageReferenceDefinition(_ line: String) -> Bool {
        imageReferenceDefinition(in: line) != nil
    }

    private static func normalizedInlineText(_ source: String) -> String {
        if let attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return String(attributed.characters)
        }
        return source
    }

    private static func tableRows(in lines: [String], at index: Int) -> (header: [String], rows: [[String]], nextIndex: Int)? {
        guard index + 1 < lines.count else { return nil }
        let header = splitMarkdownTableRow(lines[index])
        let divider = splitMarkdownTableRow(lines[index + 1])
        guard header.count > 1, divider.count == header.count else { return nil }
        guard divider.allSatisfy({ cell in
            let compact = cell.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
            return compact.count >= 3 && compact.allSatisfy { $0 == "-" }
        }) else { return nil }

        var rows: [[String]] = []
        var nextIndex = index + 2
        while nextIndex < lines.count {
            let row = splitMarkdownTableRow(lines[nextIndex])
            guard row.count == header.count else { break }
            rows.append(row)
            nextIndex += 1
        }
        return (header, rows, nextIndex)
    }

    private static func splitMarkdownTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func splitDelimitedRow(_ line: String, separator: Character) -> [String] {
        line.split(separator: separator, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func bodyAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.preferredFont(forTextStyle: .body),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(spacing: 7),
        ]
    }

    private static func secondaryAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.preferredFont(forTextStyle: .body),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraphStyle(spacing: 7),
        ]
    }

    private static func quoteAttributes() -> [NSAttributedString.Key: Any] {
        let style = paragraphStyle(spacing: 7)
        style.firstLineHeadIndent = 14
        style.headIndent = 14
        return [
            .font: NSFontManager.shared.convert(NSFont.preferredFont(forTextStyle: .body), toHaveTrait: .italicFontMask),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style,
        ]
    }

    private static func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        let bodySize = NSFont.preferredFont(forTextStyle: .body).pointSize
        let multiplier: CGFloat
        switch level {
        case 1:
            multiplier = 1.9
        case 2:
            multiplier = 1.5
        case 3:
            multiplier = 1.25
        default:
            multiplier = 1
        }
        return [
            .font: NSFont.systemFont(ofSize: bodySize * multiplier, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(spacing: level == 1 ? 12 : 9),
        ]
    }

    private static func codeAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .backgroundColor: NSColor.textBackgroundColor,
            .paragraphStyle: paragraphStyle(spacing: 5),
        ]
    }

    private static func paragraphStyle(spacing: CGFloat) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        style.paragraphSpacing = spacing
        style.lineBreakMode = .byWordWrapping
        return style
    }

    private static func applyLinkStyling(to text: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: text.length)
        text.enumerateAttribute(.link, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            text.addAttributes(linkTextAttributes, range: range)
        }
    }
}
