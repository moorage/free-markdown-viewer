import CoreGraphics
import Foundation

nonisolated enum MermaidDiagramKind: String, CaseIterable, Hashable, Codable, Sendable {
    case flowchart
    case sequenceDiagram
    case classDiagram
    case stateDiagram
    case erDiagram
    case journey
    case gantt
    case pie
    case quadrantChart
    case requirementDiagram
    case gitGraph
    case c4
    case mindmap
    case timeline
    case zenuml
    case sankey
    case xyChart
    case block
    case packet
    case kanban
    case architecture
    case radar
    case eventModeling
    case treemap
    case venn
    case ishikawa
    case wardley
    case treeView
    case info

    var displayName: String {
        switch self {
        case .flowchart: return "Flowchart"
        case .sequenceDiagram: return "Sequence Diagram"
        case .classDiagram: return "Class Diagram"
        case .stateDiagram: return "State Diagram"
        case .erDiagram: return "Entity Relationship Diagram"
        case .journey: return "User Journey"
        case .gantt: return "Gantt Chart"
        case .pie: return "Pie Chart"
        case .quadrantChart: return "Quadrant Chart"
        case .requirementDiagram: return "Requirement Diagram"
        case .gitGraph: return "Git Graph"
        case .c4: return "C4 Diagram"
        case .mindmap: return "Mindmap"
        case .timeline: return "Timeline"
        case .zenuml: return "ZenUML"
        case .sankey: return "Sankey Diagram"
        case .xyChart: return "XY Chart"
        case .block: return "Block Diagram"
        case .packet: return "Packet Diagram"
        case .kanban: return "Kanban Board"
        case .architecture: return "Architecture Diagram"
        case .radar: return "Radar Chart"
        case .eventModeling: return "Event Modeling"
        case .treemap: return "Treemap"
        case .venn: return "Venn Diagram"
        case .ishikawa: return "Ishikawa Diagram"
        case .wardley: return "Wardley Map"
        case .treeView: return "Tree View"
        case .info: return "Mermaid Info"
        }
    }

    var supportStatus: MermaidSupportStatus {
        switch self {
        case .flowchart, .sequenceDiagram, .classDiagram, .stateDiagram, .erDiagram,
             .journey, .gantt, .pie, .quadrantChart, .requirementDiagram,
             .gitGraph, .mindmap, .timeline, .sankey, .xyChart, .block,
             .packet, .kanban:
            return .nativeCommon
        case .c4, .zenuml:
            return .partial
        case .architecture, .radar, .eventModeling, .treemap, .venn,
             .ishikawa, .wardley:
            return .betaNativeCommon
        case .treeView:
            return .diagnosticOnly
        case .info:
            return .nativeCommon
        }
    }

    static func detected(from declaration: String) -> MermaidDiagramKind? {
        let lowered = declaration
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !lowered.isEmpty else { return nil }

        if lowered.hasPrefix("flowchart") || lowered.hasPrefix("graph") { return .flowchart }
        if lowered.hasPrefix("sequencediagram") { return .sequenceDiagram }
        if lowered.hasPrefix("classdiagram") { return .classDiagram }
        if lowered.hasPrefix("statediagram") { return .stateDiagram }
        if lowered.hasPrefix("erdiagram") { return .erDiagram }
        if lowered.hasPrefix("journey") { return .journey }
        if lowered.hasPrefix("gantt") { return .gantt }
        if lowered.hasPrefix("pie") { return .pie }
        if lowered.hasPrefix("quadrantchart") { return .quadrantChart }
        if lowered.hasPrefix("requirementdiagram") { return .requirementDiagram }
        if lowered.hasPrefix("gitgraph") { return .gitGraph }
        if lowered.hasPrefix("c4") { return .c4 }
        if lowered.hasPrefix("mindmap") { return .mindmap }
        if lowered.hasPrefix("timeline") { return .timeline }
        if lowered.hasPrefix("zenuml") { return .zenuml }
        if lowered.hasPrefix("sankey") { return .sankey }
        if lowered.hasPrefix("xychart") { return .xyChart }
        if lowered.hasPrefix("block") { return .block }
        if lowered.hasPrefix("packet") { return .packet }
        if lowered.hasPrefix("kanban") { return .kanban }
        if lowered.hasPrefix("architecture") { return .architecture }
        if lowered.hasPrefix("radar") { return .radar }
        if lowered.hasPrefix("eventmodeling") { return .eventModeling }
        if lowered.hasPrefix("treemap") { return .treemap }
        if lowered.hasPrefix("venn") { return .venn }
        if lowered.hasPrefix("ishikawa") { return .ishikawa }
        if lowered.hasPrefix("wardley") { return .wardley }
        if lowered.hasPrefix("treeview") || lowered.hasPrefix("treeviewdiagram") { return .treeView }
        if lowered.hasPrefix("info") { return .info }
        return nil
    }
}

nonisolated enum MermaidSupportStatus: String, Hashable, Codable, Sendable {
    case nativeCommon
    case betaNativeCommon
    case partial
    case diagnosticOnly

    var summary: String {
        switch self {
        case .nativeCommon:
            return "Native common syntax"
        case .betaNativeCommon:
            return "Native beta/common syntax"
        case .partial:
            return "Native partial syntax"
        case .diagnosticOnly:
            return "Diagnostic fallback"
        }
    }
}

nonisolated enum MermaidDiagnosticSeverity: String, Hashable, Codable, Sendable {
    case info
    case warning
    case error
}

nonisolated struct MermaidDiagnostic: Hashable, Codable, Sendable {
    let severity: MermaidDiagnosticSeverity
    let line: Int?
    let message: String
}

nonisolated struct MermaidSceneNode: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let label: String
    let shape: MermaidNodeShape
    let lane: String?
}

nonisolated enum MermaidNodeShape: String, Hashable, Codable, Sendable {
    case rounded
    case rectangle
    case decision
    case circle
    case stadium
    case database
    case person
}

nonisolated struct MermaidSceneEdge: Hashable, Codable, Sendable {
    let sourceID: String
    let targetID: String
    let label: String?
    let style: MermaidEdgeStyle
}

nonisolated enum MermaidEdgeStyle: String, Hashable, Codable, Sendable {
    case solid
    case dotted
    case thick
    case open
}

nonisolated struct MermaidSceneSection: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let title: String
    let items: [String]
}

nonisolated struct MermaidSceneMetric: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let label: String
    let value: Double
}

nonisolated struct MermaidScene: Hashable, Codable, Sendable {
    let kind: MermaidDiagramKind
    let title: String?
    let subtitle: String?
    let direction: MermaidGraphDirection?
    let nodes: [MermaidSceneNode]
    let edges: [MermaidSceneEdge]
    let sections: [MermaidSceneSection]
    let metrics: [MermaidSceneMetric]
}

nonisolated enum MermaidGraphDirection: String, Hashable, Codable, Sendable {
    case topBottom
    case bottomTop
    case leftRight
    case rightLeft
}

nonisolated struct MermaidDiagramConfig: Hashable, Codable, Sendable {
    let title: String?
    let theme: String?
    let layout: String?
    let fontFamily: String?
    let fontSize: Double?
}

nonisolated enum MermaidSourceContext: Hashable, Sendable {
    case inline
    case file(WorkspacePath)

    var displayName: String {
        switch self {
        case .inline:
            return "Inline Mermaid diagram"
        case let .file(path):
            return path.rawValue
        }
    }
}

nonisolated struct MarkdownMermaidDiagram: Hashable, Sendable {
    let source: String
    let context: MermaidSourceContext
    let kind: MermaidDiagramKind
    let config: MermaidDiagramConfig
    let accessibilityTitle: String?
    let accessibilityDescription: String?
    let diagnostics: [MermaidDiagnostic]
    let scene: MermaidScene

    var displayTitle: String {
        if let title = config.title, !title.isEmpty {
            return title
        }
        if let accessibilityTitle, !accessibilityTitle.isEmpty {
            return accessibilityTitle
        }
        return kind.displayName
    }

    var presentationTitle: String {
        if hasAuthoredTitle {
            return displayTitle
        }
        return "Mermaid Diagram"
    }

    private var hasAuthoredTitle: Bool {
        if let title = config.title, !title.isEmpty {
            return true
        }
        if let accessibilityTitle, !accessibilityTitle.isEmpty {
            return true
        }
        return false
    }

    var plainTextSummary: String {
        let sourceLabel = context.displayName
        let diagnosticsText = diagnostics.map { diagnostic in
            let prefix = diagnostic.line.map { "line \($0): " } ?? ""
            return "\(diagnostic.severity.rawValue): \(prefix)\(diagnostic.message)"
        }
        let body = [
            "Mermaid Diagram",
            displayTitle,
            kind.displayName,
            kind.supportStatus.summary,
            sourceLabel
        ] + diagnosticsText
        return body.filter { !$0.isEmpty }.joined(separator: "\n")
    }
}
