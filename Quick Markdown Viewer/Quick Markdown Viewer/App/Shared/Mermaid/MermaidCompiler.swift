import Foundation

nonisolated enum MermaidCompiler {
    private struct SourceLine {
        let number: Int
        let text: String
    }

    nonisolated static func compile(
        source: String,
        context: MermaidSourceContext
    ) -> MarkdownMermaidDiagram {
        let normalized = source.replacingOccurrences(of: "\r\n", with: "\n")
        let frontmatter = parseFrontmatter(from: normalized)
        let strippedSource = frontmatter.body
        var diagnostics = frontmatter.diagnostics
        let rawLines = strippedSource.components(separatedBy: "\n")
        let parsedLines = sanitizedLines(from: rawLines, diagnostics: &diagnostics)
        let declaration = parsedLines.first?.text ?? ""
        let kind = MermaidDiagramKind.detected(from: declaration) ?? .info

        if MermaidDiagramKind.detected(from: declaration) == nil {
            diagnostics.append(
                MermaidDiagnostic(
                    severity: .warning,
                    line: parsedLines.first?.number,
                    message: "Unsupported or missing Mermaid declaration. Showing a native diagnostic diagram."
                )
            )
        }

        if kind.supportStatus == .diagnosticOnly {
            diagnostics.append(
                MermaidDiagnostic(
                    severity: .warning,
                    line: parsedLines.first?.number,
                    message: "\(kind.displayName) is represented in the compatibility matrix, but Mermaid does not currently publish enough stable syntax for full native rendering."
                )
            )
        } else if kind.supportStatus == .partial || kind.supportStatus == .betaNativeCommon {
            diagnostics.append(
                MermaidDiagnostic(
                    severity: .info,
                    line: parsedLines.first?.number,
                    message: "\(kind.displayName) uses native common-syntax rendering; Mermaid.js-only styling and beta edge cases may be simplified."
                )
            )
        }

        appendSafetyDiagnostics(from: parsedLines, diagnostics: &diagnostics)

        let accTitle = accessibilityValue(prefix: "acctitle", in: parsedLines)
        let accDescription = accessibilityValue(prefix: "accdescr", in: parsedLines)
        let title = explicitTitle(in: parsedLines) ?? frontmatter.title ?? accTitle
        let config = MermaidDiagramConfig(
            title: title,
            theme: frontmatter.theme,
            layout: frontmatter.layout,
            fontFamily: frontmatter.fontFamily,
            fontSize: frontmatter.fontSize
        )
        let contentLines = Array(parsedLines.dropFirst())
        let scene = scene(
            kind: kind,
            title: title,
            context: context,
            declaration: declaration,
            contentLines: contentLines,
            diagnostics: diagnostics
        )

        return MarkdownMermaidDiagram(
            source: normalized.trimmingCharacters(in: .newlines),
            context: context,
            kind: kind,
            config: config,
            accessibilityTitle: accTitle,
            accessibilityDescription: accDescription,
            diagnostics: diagnostics,
            scene: scene
        )
    }

    private nonisolated static func parseFrontmatter(
        from source: String
    ) -> (body: String, title: String?, theme: String?, layout: String?, fontFamily: String?, fontSize: Double?, diagnostics: [MermaidDiagnostic]) {
        let lines = source.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return (source, nil, nil, nil, nil, nil, [])
        }

        guard let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return (
                source,
                nil,
                nil,
                nil,
                nil,
                nil,
                [MermaidDiagnostic(severity: .warning, line: 1, message: "Mermaid frontmatter was opened but not closed.")]
            )
        }

        let frontmatterLines = Array(lines[1..<closingIndex])
        let body = lines[(closingIndex + 1)..<lines.count].joined(separator: "\n")
        let values = simpleFrontmatterValues(from: frontmatterLines)
        let unsafeKeys = values.keys.filter { key in
            ["themecss", "htmlLabels", "callback", "securitylevel"].contains(key.lowercased())
        }
        let diagnostics = unsafeKeys.map { key in
            MermaidDiagnostic(
                severity: .warning,
                line: nil,
                message: "Ignored unsafe or web-only Mermaid frontmatter key '\(key)'."
            )
        }

        return (
            body,
            values["title"],
            values["theme"],
            values["layout"],
            values["fontFamily"],
            values["fontSize"].flatMap(Double.init),
            diagnostics
        )
    }

    private nonisolated static func simpleFrontmatterValues(from lines: [String]) -> [String: String] {
        var values: [String: String] = [:]
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let separator = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !key.isEmpty, !value.isEmpty else { continue }
            values[key] = value
        }
        return values
    }

    private nonisolated static func sanitizedLines(
        from rawLines: [String],
        diagnostics: inout [MermaidDiagnostic]
    ) -> [SourceLine] {
        var lines: [SourceLine] = []
        for (offset, line) in rawLines.enumerated() {
            let lineNumber = offset + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("%%{"), trimmed.hasSuffix("}%%") {
                appendDirectiveDiagnostics(trimmed, lineNumber: lineNumber, diagnostics: &diagnostics)
                continue
            }

            if trimmed.hasPrefix("%%") {
                continue
            }

            lines.append(SourceLine(number: lineNumber, text: trimmed))
        }
        return lines
    }

    private nonisolated static func appendDirectiveDiagnostics(
        _ directive: String,
        lineNumber: Int,
        diagnostics: inout [MermaidDiagnostic]
    ) {
        let lowered = directive.lowercased()
        if lowered.contains("themecss") || lowered.contains("htmllabels") || lowered.contains("callback") {
            diagnostics.append(
                MermaidDiagnostic(
                    severity: .warning,
                    line: lineNumber,
                    message: "Ignored web-only Mermaid directive content. Native rendering does not execute CSS, HTML, or callbacks."
                )
            )
        } else {
            diagnostics.append(
                MermaidDiagnostic(
                    severity: .info,
                    line: lineNumber,
                    message: "Parsed Mermaid directive for compatibility; unsupported keys are ignored by native rendering."
                )
            )
        }
    }

    private nonisolated static func appendSafetyDiagnostics(
        from lines: [SourceLine],
        diagnostics: inout [MermaidDiagnostic]
    ) {
        for line in lines {
            let lowered = line.text.lowercased()
            if lowered.contains("callback") || lowered.contains("javascript:") {
                diagnostics.append(
                    MermaidDiagnostic(
                        severity: .warning,
                        line: line.number,
                        message: "Ignored JavaScript callback behavior. Only safe native URL opening is supported."
                    )
                )
            }
            if lowered.contains("htmllabels") || lowered.contains("themecss") || containsHTMLTag(in: line.text) {
                diagnostics.append(
                    MermaidDiagnostic(
                        severity: .warning,
                        line: line.number,
                        message: "Rendered label as safe native text instead of Mermaid HTML/CSS."
                    )
                )
            }
            if lowered.contains("registericon") || lowered.contains("iconpacks") || lowered.contains("cdn.") {
                diagnostics.append(
                    MermaidDiagnostic(
                        severity: .warning,
                        line: line.number,
                        message: "Remote icon loading is disabled. Built-in native symbols are used when possible."
                    )
                )
            }
        }
    }

    private nonisolated static func containsHTMLTag(in text: String) -> Bool {
        text.range(of: #"<[A-Za-z][A-Za-z0-9-]*(?:\s[^>]*)?>"#, options: .regularExpression) != nil
    }

    private nonisolated static func accessibilityValue(prefix: String, in lines: [SourceLine]) -> String? {
        let prefixWithColon = "\(prefix):"
        for line in lines {
            let lowered = line.text.lowercased()
            if lowered.hasPrefix(prefixWithColon) {
                return String(line.text.dropFirst(prefixWithColon.count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private nonisolated static func explicitTitle(in lines: [SourceLine]) -> String? {
        for line in lines {
            let lowered = line.text.lowercased()
            if lowered.hasPrefix("title ") {
                return String(line.text.dropFirst("title ".count)).trimmingCharacters(in: .whitespaces)
            }
            if lowered.hasPrefix("title:") {
                return String(line.text.dropFirst("title:".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private nonisolated static func scene(
        kind: MermaidDiagramKind,
        title: String?,
        context: MermaidSourceContext,
        declaration: String,
        contentLines: [SourceLine],
        diagnostics: [MermaidDiagnostic]
    ) -> MermaidScene {
        switch kind {
        case .flowchart, .classDiagram, .stateDiagram, .erDiagram, .requirementDiagram,
             .block, .architecture, .c4:
            return graphScene(kind: kind, title: title, declaration: declaration, contentLines: contentLines)
        case .sequenceDiagram, .zenuml:
            return sequenceScene(kind: kind, title: title, contentLines: contentLines)
        case .pie, .quadrantChart, .xyChart, .sankey, .packet, .radar, .treemap, .venn,
             .wardley:
            return metricScene(kind: kind, title: title, contentLines: contentLines)
        case .journey, .gantt, .timeline, .gitGraph, .eventModeling, .mindmap, .kanban,
             .ishikawa:
            return sectionScene(kind: kind, title: title, contentLines: contentLines)
        case .treeView, .info:
            return diagnosticScene(kind: kind, title: title, context: context, diagnostics: diagnostics)
        }
    }

    private nonisolated static func graphScene(
        kind: MermaidDiagramKind,
        title: String?,
        declaration: String,
        contentLines: [SourceLine]
    ) -> MermaidScene {
        var nodesByID: [String: MermaidSceneNode] = [:]
        var nodeOrder: [String] = []
        var edges: [MermaidSceneEdge] = []
        var sections: [MermaidSceneSection] = []
        var currentSectionItems: [String] = []
        var currentSectionTitle: String?

        func storeSectionIfNeeded() {
            guard let currentSectionTitle, !currentSectionItems.isEmpty else { return }
            sections.append(
                MermaidSceneSection(
                    id: stableID("section-\(sections.count)-\(currentSectionTitle)"),
                    title: currentSectionTitle,
                    items: currentSectionItems
                )
            )
            currentSectionItems.removeAll()
        }

        func addNode(_ node: MermaidSceneNode) {
            if nodesByID[node.id] == nil {
                nodesByID[node.id] = node
                nodeOrder.append(node.id)
            }
        }

        for line in contentLines {
            let text = line.text
            let lowered = text.lowercased()
            if lowered.hasPrefix("subgraph ") || lowered.hasPrefix("namespace ") {
                storeSectionIfNeeded()
                currentSectionTitle = cleanLabel(String(text.dropFirst(text.firstIndex(of: " ").map { text.distance(from: text.startIndex, to: $0) + 1 } ?? 0)))
                continue
            }
            if lowered == "end" {
                storeSectionIfNeeded()
                currentSectionTitle = nil
                continue
            }
            if shouldSkipMetadataLine(text) { continue }

            if let edge = parseEdgeLine(text) {
                addNode(edge.source)
                addNode(edge.target)
                edges.append(edge.edge)
                currentSectionItems.append(edge.edge.label ?? "\(edge.source.label) to \(edge.target.label)")
                continue
            }

            if let node = parseNodeToken(text) {
                addNode(node)
                currentSectionItems.append(node.label)
            } else if !text.isEmpty {
                let node = MermaidSceneNode(
                    id: stableID(text),
                    label: cleanLabel(text),
                    shape: kind == .classDiagram ? .rectangle : .rounded,
                    lane: currentSectionTitle
                )
                addNode(node)
                currentSectionItems.append(node.label)
            }
        }

        storeSectionIfNeeded()
        let nodes = nodeOrder.compactMap { nodesByID[$0] }
        return MermaidScene(
            kind: kind,
            title: title,
            subtitle: kind.supportStatus.summary,
            direction: graphDirection(from: declaration),
            nodes: nodes.isEmpty ? fallbackNodes(from: contentLines, kind: kind) : nodes,
            edges: edges,
            sections: sections,
            metrics: []
        )
    }

    private nonisolated static func sequenceScene(
        kind: MermaidDiagramKind,
        title: String?,
        contentLines: [SourceLine]
    ) -> MermaidScene {
        var participantsByID: [String: MermaidSceneNode] = [:]
        var edges: [MermaidSceneEdge] = []
        var sections: [MermaidSceneSection] = []
        var currentSectionTitle: String?
        var currentItems: [String] = []

        func addParticipant(_ rawID: String, label: String? = nil) {
            let id = stableID(rawID)
            if participantsByID[id] == nil {
                participantsByID[id] = MermaidSceneNode(
                    id: id,
                    label: cleanLabel(label ?? rawID),
                    shape: .person,
                    lane: nil
                )
            }
        }

        func flushSection() {
            guard let currentSectionTitle, !currentItems.isEmpty else { return }
            sections.append(
                MermaidSceneSection(
                    id: stableID("sequence-\(sections.count)-\(currentSectionTitle)"),
                    title: currentSectionTitle,
                    items: currentItems
                )
            )
            currentItems.removeAll()
        }

        for line in contentLines {
            let text = line.text
            let lowered = text.lowercased()
            if lowered.hasPrefix("participant ") || lowered.hasPrefix("actor ") {
                let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
                let body = parts.count > 1 ? parts[1] : text
                let aliasParts = body.components(separatedBy: " as ")
                addParticipant(aliasParts[0], label: aliasParts.count > 1 ? aliasParts[1] : nil)
                continue
            }
            if let message = parseMessageLine(text) {
                addParticipant(message.sourceID)
                addParticipant(message.targetID)
                edges.append(message.edge)
                currentItems.append(message.edge.label ?? "\(message.sourceID) to \(message.targetID)")
                continue
            }
            if ["loop", "alt", "opt", "par", "critical", "break", "rect", "box"].contains(where: lowered.hasPrefix) {
                flushSection()
                currentSectionTitle = cleanLabel(text)
                continue
            }
            if lowered == "end" {
                flushSection()
                currentSectionTitle = nil
                continue
            }
            if lowered.hasPrefix("note") || lowered.hasPrefix("activate") || lowered.hasPrefix("deactivate") {
                currentItems.append(cleanLabel(text))
            }
        }

        flushSection()
        return MermaidScene(
            kind: kind,
            title: title,
            subtitle: kind.supportStatus.summary,
            direction: nil,
            nodes: Array(participantsByID.values).sorted { $0.label < $1.label },
            edges: edges,
            sections: sections,
            metrics: []
        )
    }

    private nonisolated static func metricScene(
        kind: MermaidDiagramKind,
        title: String?,
        contentLines: [SourceLine]
    ) -> MermaidScene {
        var metrics: [MermaidSceneMetric] = []
        var sections: [MermaidSceneSection] = []

        for line in contentLines where !shouldSkipMetadataLine(line.text) {
            if let metric = parseMetric(line.text, index: metrics.count) {
                metrics.append(metric)
            } else {
                sections.append(
                    MermaidSceneSection(
                        id: stableID("metric-\(sections.count)-\(line.text)"),
                        title: cleanLabel(line.text),
                        items: []
                    )
                )
            }
        }

        return MermaidScene(
            kind: kind,
            title: title,
            subtitle: kind.supportStatus.summary,
            direction: nil,
            nodes: [],
            edges: [],
            sections: sections,
            metrics: metrics.isEmpty ? fallbackMetrics(from: contentLines) : metrics
        )
    }

    private nonisolated static func sectionScene(
        kind: MermaidDiagramKind,
        title: String?,
        contentLines: [SourceLine]
    ) -> MermaidScene {
        var sections: [MermaidSceneSection] = []
        var currentTitle = kind.displayName
        var currentItems: [String] = []

        func flush() {
            if !currentItems.isEmpty {
                sections.append(
                    MermaidSceneSection(
                        id: stableID("section-\(sections.count)-\(currentTitle)"),
                        title: currentTitle,
                        items: currentItems
                    )
                )
                currentItems.removeAll()
            }
        }

        for line in contentLines {
            let text = line.text
            let lowered = text.lowercased()
            if shouldSkipMetadataLine(text) { continue }
            if lowered.hasPrefix("section ") {
                flush()
                currentTitle = cleanLabel(String(text.dropFirst("section ".count)))
                continue
            }
            if kind == .gitGraph, lowered.hasPrefix("branch ") {
                flush()
                currentTitle = cleanLabel(text)
                continue
            }
            currentItems.append(cleanLabel(text))
        }
        flush()

        return MermaidScene(
            kind: kind,
            title: title,
            subtitle: kind.supportStatus.summary,
            direction: nil,
            nodes: [],
            edges: [],
            sections: sections.isEmpty ? fallbackSections(from: contentLines, kind: kind) : sections,
            metrics: []
        )
    }

    private nonisolated static func diagnosticScene(
        kind: MermaidDiagramKind,
        title: String?,
        context: MermaidSourceContext,
        diagnostics: [MermaidDiagnostic]
    ) -> MermaidScene {
        let items = diagnostics.isEmpty
            ? ["Native Mermaid compatibility report for \(context.displayName)."]
            : diagnostics.map(\.message)
        return MermaidScene(
            kind: kind,
            title: title ?? kind.displayName,
            subtitle: kind.supportStatus.summary,
            direction: nil,
            nodes: [],
            edges: [],
            sections: [
                MermaidSceneSection(
                    id: "diagnostics",
                    title: "Diagnostics",
                    items: items
                )
            ],
            metrics: []
        )
    }

    private nonisolated static func parseEdgeLine(
        _ text: String
    ) -> (source: MermaidSceneNode, target: MermaidSceneNode, edge: MermaidSceneEdge)? {
        let operators = ["-->", "==>", "-.->", "---", "--x", "--o", "<-->", "<--", "o--o", "x--x", "--"]
        guard let match = operators.compactMap({ op -> (String, Range<String.Index>)? in
            guard let range = text.range(of: op) else { return nil }
            return (op, range)
        }).min(by: { text.distance(from: text.startIndex, to: $0.1.lowerBound) < text.distance(from: text.startIndex, to: $1.1.lowerBound) }) else {
            return nil
        }

        let rawLeft = String(text[..<match.1.lowerBound]).trimmingCharacters(in: .whitespaces)
        let rightAndLabel = String(text[match.1.upperBound...]).trimmingCharacters(in: .whitespaces)
        let labelSplit = rightAndLabel.components(separatedBy: "|")
        let rawRight = labelSplit.last?.trimmingCharacters(in: .whitespaces) ?? rightAndLabel
        let label = labelSplit.count >= 3 ? cleanLabel(labelSplit[1]) : nil
        guard let source = parseNodeToken(rawLeft),
              let target = parseNodeToken(rawRight) else {
            return nil
        }

        let style: MermaidEdgeStyle
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
            MermaidSceneEdge(
                sourceID: source.id,
                targetID: target.id,
                label: label,
                style: style
            )
        )
    }

    private nonisolated static func graphDirection(from declaration: String) -> MermaidGraphDirection {
        let tokens = declaration
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.lowercased() }
        guard tokens.count > 1 else { return .topBottom }

        switch tokens[1] {
        case "tb", "td":
            return .topBottom
        case "bt":
            return .bottomTop
        case "lr":
            return .leftRight
        case "rl":
            return .rightLeft
        default:
            return .topBottom
        }
    }

    private nonisolated static func parseMessageLine(_ text: String) -> (sourceID: String, targetID: String, edge: MermaidSceneEdge)? {
        let operators = ["->>", "-->>", "-x", "--x", "-)", "--)", "->", "-->"]
        guard let match = operators.compactMap({ op -> (String, Range<String.Index>)? in
            guard let range = text.range(of: op) else { return nil }
            return (op, range)
        }).min(by: { lhs, rhs in
            let lhsPosition = text.distance(from: text.startIndex, to: lhs.1.lowerBound)
            let rhsPosition = text.distance(from: text.startIndex, to: rhs.1.lowerBound)
            if lhsPosition == rhsPosition {
                return lhs.0.count > rhs.0.count
            }
            return lhsPosition < rhsPosition
        }) else {
            return nil
        }

        let source = String(text[..<match.1.lowerBound]).trimmingCharacters(in: .whitespaces)
        let remainder = String(text[match.1.upperBound...])
        let parts = remainder.split(separator: ":", maxSplits: 1).map(String.init)
        let target = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !source.isEmpty, !target.isEmpty else { return nil }
        let label = parts.count > 1 ? cleanLabel(parts[1]) : nil
        return (
            source,
            target,
            MermaidSceneEdge(
                sourceID: stableID(source),
                targetID: stableID(target),
                label: label,
                style: match.0.contains("--") ? .dotted : .solid
            )
        )
    }

    private nonisolated static func parseNodeToken(_ rawValue: String) -> MermaidSceneNode? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ";"))
        if cleaned.contains("[") || cleaned.contains("(") || cleaned.contains("{") {
            let id = cleaned.prefix { character in
                character != "[" && character != "(" && character != "{"
            }
            let label = labelBody(from: cleaned) ?? String(id)
            return MermaidSceneNode(
                id: stableID(String(id)),
                label: cleanLabel(label),
                shape: nodeShape(from: cleaned),
                lane: nil
            )
        }
        let token = cleaned.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? cleaned
        guard token.range(of: #"^[A-Za-z0-9_./:-]+$"#, options: .regularExpression) != nil else {
            return nil
        }
        return MermaidSceneNode(
            id: stableID(token),
            label: cleanLabel(token),
            shape: .rounded,
            lane: nil
        )
    }

    private nonisolated static func labelBody(from value: String) -> String? {
        let pairs: [(Character, Character)] = [("[", "]"), ("(", ")"), ("{", "}")]
        for (opening, closing) in pairs {
            guard let start = value.firstIndex(of: opening),
                  let end = value.lastIndex(of: closing),
                  start < end else { continue }
            return String(value[value.index(after: start)..<end])
        }
        return nil
    }

    private nonisolated static func nodeShape(from value: String) -> MermaidNodeShape {
        if value.contains("{") { return .decision }
        if value.contains("((") { return .circle }
        if value.contains("[(") || value.contains(")]") { return .database }
        if value.contains("([") || value.contains("])") { return .stadium }
        if value.contains("(") { return .rounded }
        return .rectangle
    }

    private nonisolated static func parseMetric(_ text: String, index: Int) -> MermaidSceneMetric? {
        let separators = [":", ","]
        for separator in separators {
            let parts = text.split(separator: Character(separator), maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let label = cleanLabel(parts[0])
            let numberText = parts[1].trimmingCharacters(in: .whitespaces)
                .split(whereSeparator: \.isWhitespace)
                .first
                .map(String.init) ?? ""
            if let value = Double(numberText) {
                return MermaidSceneMetric(id: stableID("\(index)-\(label)"), label: label, value: value)
            }
        }
        if let numberRange = text.range(of: #"-?\d+(?:\.\d+)?"#, options: .regularExpression),
           let value = Double(text[numberRange]) {
            return MermaidSceneMetric(id: stableID("\(index)-\(text)"), label: cleanLabel(text), value: value)
        }
        return nil
    }

    private nonisolated static func shouldSkipMetadataLine(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return lowered.hasPrefix("title")
            || lowered.hasPrefix("acctitle")
            || lowered.hasPrefix("accdescr")
            || lowered.hasPrefix("direction")
            || lowered.hasPrefix("autonumber")
            || lowered.hasPrefix("dateformat")
            || lowered.hasPrefix("axisformat")
            || lowered.hasPrefix("tickinterval")
    }

    private nonisolated static func fallbackNodes(from contentLines: [SourceLine], kind: MermaidDiagramKind) -> [MermaidSceneNode] {
        let labels = contentLines
            .map(\.text)
            .filter { !shouldSkipMetadataLine($0) }
            .prefix(8)
        return labels.enumerated().map { index, label in
            MermaidSceneNode(
                id: stableID("fallback-\(index)-\(label)"),
                label: cleanLabel(label),
                shape: kind == .classDiagram ? .rectangle : .rounded,
                lane: nil
            )
        }
    }

    private nonisolated static func fallbackMetrics(from contentLines: [SourceLine]) -> [MermaidSceneMetric] {
        let labels = contentLines
            .map(\.text)
            .filter { !shouldSkipMetadataLine($0) }
            .prefix(8)
        return labels.enumerated().map { index, label in
            MermaidSceneMetric(id: stableID("fallback-metric-\(index)-\(label)"), label: cleanLabel(label), value: Double(index + 1))
        }
    }

    private nonisolated static func fallbackSections(from contentLines: [SourceLine], kind: MermaidDiagramKind) -> [MermaidSceneSection] {
        let items = contentLines
            .map(\.text)
            .filter { !shouldSkipMetadataLine($0) }
            .prefix(12)
            .map(cleanLabel)
        return [
            MermaidSceneSection(
                id: stableID("fallback-section-\(kind.rawValue)"),
                title: kind.displayName,
                items: Array(items)
            )
        ]
    }

    private nonisolated static func cleanLabel(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: #":::[A-Za-z0-9_-]+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[\[\]\{\}\(\);]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func stableID(_ rawValue: String) -> String {
        let cleaned = rawValue
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return cleaned.isEmpty ? "item" : cleaned
    }
}
