import SwiftUI
#if os(macOS)
import AppKit
#endif

struct MermaidDiagramPreviewTarget: Identifiable, Equatable {
    let blockID: String
    let diagram: MarkdownMermaidDiagram

    var id: String { "\(blockID)|\(diagram.kind.rawValue)|\(diagram.source.hashValue)" }
}

enum MermaidPreviewZoom {
    static let minimum: CGFloat = 0.12
    static let maximum: CGFloat = 3
    static let step: CGFloat = 0.15

    static func clamped(_ zoom: CGFloat) -> CGFloat {
        min(max(zoom, minimum), maximum)
    }

    static func fitScale(canvasSize: CGSize, viewportSize: CGSize) -> CGFloat {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return 1 }

        let widthScale = max(viewportSize.width, 1) / canvasSize.width
        let heightScale = max(viewportSize.height, 1) / canvasSize.height
        return clamped(min(widthScale, heightScale))
    }
}

enum MermaidPreviewPresentation {
    case constrainedSheet
    case detachedWindow

    var maximumViewportWidth: CGFloat {
        switch self {
        case .constrainedSheet: return 980
        case .detachedWindow: return .infinity
        }
    }

    var maximumViewportHeight: CGFloat {
        switch self {
        case .constrainedSheet: return 760
        case .detachedWindow: return .infinity
        }
    }

    var maximumRootWidth: CGFloat? {
        switch self {
        case .constrainedSheet: return nil
        case .detachedWindow: return .infinity
        }
    }

    var maximumRootHeight: CGFloat? {
        switch self {
        case .constrainedSheet: return nil
        case .detachedWindow: return .infinity
        }
    }
}

struct MermaidDiagramBlockView: View {
    let diagram: MarkdownMermaidDiagram
    let blockID: String
    let fontScale: CGFloat
    let isPrinting: Bool
    let onOpenPreview: (MermaidDiagramPreviewTarget) -> Void

    var body: some View {
        let card = MermaidDiagramCard(
            diagram: diagram,
            blockID: blockID,
            fontScale: fontScale,
            compact: true,
            showsControlsHint: !isPrinting
        )

        Group {
            if isPrinting {
                card
            } else {
                Button {
                    onOpenPreview(MermaidDiagramPreviewTarget(blockID: blockID, diagram: diagram))
                } label: {
                    card
                }
                .buttonStyle(.plain)
                .accessibilityLabel(diagram.accessibilityTitle ?? diagram.presentationTitle)
                .accessibilityHint("Open diagram preview")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIDs.mermaidBlock(blockID))
    }
}

struct MermaidDiagramPreviewView: View {
    let target: MermaidDiagramPreviewTarget
    let onClose: () -> Void
    let onOpenInWindow: (() -> Void)?
    let presentation: MermaidPreviewPresentation

    @State private var zoom: CGFloat = 1
    @State private var gestureStartZoom: CGFloat = 1
    @State private var viewportSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.diagram.presentationTitle)
                        .font(.headline)
                    Text(target.diagram.kind.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                zoomControls

                if let onOpenInWindow {
                    Button("Open in Window", action: onOpenInWindow)
                        .accessibilityIdentifier(AccessibilityIDs.mermaidPreviewOpenWindowButton)
                }

                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier(AccessibilityIDs.mermaidPreviewCloseButton)
            }

            ZStack {
                MermaidDiagramBackground(kind: target.diagram.kind)

                GeometryReader { proxy in
                    let viewportSize = proxy.size
                    let baseCanvasSize = MermaidLayout.canvasSize(
                        for: target.diagram,
                        viewportSize: viewportSize,
                        compact: false
                    )
                    let scaledCanvasSize = CGSize(
                        width: baseCanvasSize.width * zoom,
                        height: baseCanvasSize.height * zoom
                    )

                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        MermaidDiagramSurface(
                            diagram: target.diagram,
                            fontScale: 1,
                            compact: false,
                            graphViewportMode: .canvasOnly,
                            drawsGraphBackground: false
                        )
                        .frame(width: baseCanvasSize.width, height: baseCanvasSize.height)
                        .scaleEffect(zoom, anchor: .topLeading)
                        .frame(width: scaledCanvasSize.width, height: scaledCanvasSize.height, alignment: .topLeading)
                        .frame(
                            width: max(scaledCanvasSize.width, viewportSize.width),
                            height: max(scaledCanvasSize.height, viewportSize.height),
                            alignment: .center
                        )
                    }
                    .gesture(zoomGesture)
                    .onAppear {
                        self.viewportSize = viewportSize
                    }
                    .onChange(of: viewportSize) { newValue in
                        self.viewportSize = newValue
                    }
                }
            }
            .frame(
                minWidth: 560,
                idealWidth: 760,
                maxWidth: presentation.maximumViewportWidth,
                minHeight: 420,
                idealHeight: 560,
                maxHeight: presentation.maximumViewportHeight
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityIdentifier(AccessibilityIDs.mermaidPreviewContainer)
        }
        .padding(20)
        .frame(maxWidth: presentation.maximumRootWidth, maxHeight: presentation.maximumRootHeight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIDs.mermaidPreviewContainer)
    }

    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button {
                zoom = MermaidPreviewZoom.clamped(zoom - MermaidPreviewZoom.step)
                gestureStartZoom = zoom
            } label: {
                Label("Zoom Out", systemImage: "minus.magnifyingglass")
            }
            .accessibilityIdentifier(AccessibilityIDs.mermaidPreviewZoomOutButton)

            Button {
                zoom = MermaidPreviewZoom.clamped(zoom + MermaidPreviewZoom.step)
                gestureStartZoom = zoom
            } label: {
                Label("Zoom In", systemImage: "plus.magnifyingglass")
            }
            .accessibilityIdentifier(AccessibilityIDs.mermaidPreviewZoomInButton)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    zoom = fitZoom()
                    gestureStartZoom = zoom
                }
            } label: {
                Label("Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass")
            }
            .accessibilityIdentifier(AccessibilityIDs.mermaidPreviewFitButton)

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    zoom = 1
                    gestureStartZoom = 1
                }
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .accessibilityIdentifier(AccessibilityIDs.mermaidPreviewResetButton)
        }
        .labelStyle(.iconOnly)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = MermaidPreviewZoom.clamped(gestureStartZoom * value)
            }
            .onEnded { _ in
                gestureStartZoom = zoom
            }
    }

    private func fitZoom() -> CGFloat {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return 1 }

        let canvasSize = MermaidLayout.canvasSize(
            for: target.diagram,
            viewportSize: viewportSize,
            compact: false
        )
        return MermaidPreviewZoom.fitScale(canvasSize: canvasSize, viewportSize: viewportSize)
    }
}

#if os(macOS)
@MainActor
final class MermaidPreviewWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = MermaidPreviewWindowPresenter()

    private var windows: [String: NSWindow] = [:]

    func open(target: MermaidDiagramPreviewTarget) {
        if let existingWindow = windows[target.id] {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_000, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = target.diagram.presentationTitle
        window.identifier = NSUserInterfaceItemIdentifier(target.id)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(
            rootView: MermaidDiagramPreviewView(
                target: target,
                onClose: { [weak window] in
                    window?.performClose(nil)
                },
                onOpenInWindow: nil,
                presentation: .detachedWindow
            )
        )

        windows[target.id] = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let identifier = window.identifier?.rawValue else {
            return
        }
        windows[identifier] = nil
    }
}
#endif

private struct MermaidDiagramCard: View {
    let diagram: MarkdownMermaidDiagram
    let blockID: String
    let fontScale: CGFloat
    let compact: Bool
    let showsControlsHint: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(diagram.presentationTitle)
                        .font(.system(size: 16 * fontScale, weight: .semibold, design: .default))
                    Text(diagram.kind.displayName)
                        .font(.system(size: 12 * fontScale, weight: .medium, design: .default))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
            }

            MermaidDiagramSurface(diagram: diagram, fontScale: fontScale, compact: compact)
                .frame(maxWidth: .infinity, minHeight: compact ? 220 : 420, idealHeight: compact ? 260 : 520, maxHeight: compact ? 340 : 720)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !diagram.diagnostics.isEmpty {
                diagnostics
            }

            if showsControlsHint {
                Label("Click to zoom and pan", systemImage: "hand.tap")
                    .font(.system(size: 12 * fontScale, weight: .medium, design: .default))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.secondary.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.055), radius: 12, y: 5)
        .accessibilityIdentifier(AccessibilityIDs.mermaidBlock(blockID))
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(diagram.diagnostics.prefix(3).enumerated()), id: \.offset) { _, diagnostic in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: diagnostic.severity == .warning ? "exclamationmark.triangle" : "info.circle")
                    Text(diagnostic.message)
                }
                .font(.system(size: 11 * fontScale, weight: .regular, design: .default))
                .foregroundStyle(diagnostic.severity == .warning ? Color.orange : Color.secondary)
            }
        }
    }
}

private struct MermaidDiagramSurface: View {
    enum GraphViewportMode {
        case scrollable
        case canvasOnly
    }

    let diagram: MarkdownMermaidDiagram
    let fontScale: CGFloat
    let compact: Bool
    let graphViewportMode: GraphViewportMode
    let drawsGraphBackground: Bool

    init(
        diagram: MarkdownMermaidDiagram,
        fontScale: CGFloat,
        compact: Bool,
        graphViewportMode: GraphViewportMode = .scrollable,
        drawsGraphBackground: Bool = true
    ) {
        self.diagram = diagram
        self.fontScale = fontScale
        self.compact = compact
        self.graphViewportMode = graphViewportMode
        self.drawsGraphBackground = drawsGraphBackground
    }

    var body: some View {
        GeometryReader { proxy in
            switch presentationKind {
            case .graph:
                graphView(size: proxy.size)
            case .sequence:
                ZStack {
                    MermaidDiagramBackground(kind: diagram.kind)
                    sequenceView(size: proxy.size)
                }
            case .metrics:
                ZStack {
                    MermaidDiagramBackground(kind: diagram.kind)
                    metricView(size: proxy.size)
                }
            case .sections:
                ZStack {
                    MermaidDiagramBackground(kind: diagram.kind)
                    sectionView(size: proxy.size)
                }
            }
        }
    }

    private var presentationKind: MermaidPresentationKind {
        if !diagram.scene.edges.isEmpty || !diagram.scene.nodes.isEmpty {
            if diagram.kind == .sequenceDiagram || diagram.kind == .zenuml {
                return .sequence
            }
            return .graph
        }
        if !diagram.scene.metrics.isEmpty {
            return .metrics
        }
        return .sections
    }

    @ViewBuilder
    private func graphView(size: CGSize) -> some View {
        let nodes = diagram.scene.nodes.isEmpty
            ? [MermaidSceneNode(id: "empty", label: diagram.kind.displayName, shape: .rounded, lane: nil)]
            : diagram.scene.nodes
        let layout = MermaidLayout.graphLayout(
            for: nodes,
            edges: diagram.scene.edges,
            direction: diagram.scene.direction ?? .topBottom,
            viewportSize: size,
            compact: compact
        )

        switch graphViewportMode {
        case .scrollable:
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                graphCanvas(nodes: nodes, layout: layout)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        case .canvasOnly:
            graphCanvas(nodes: nodes, layout: layout)
        }
    }

    private func graphCanvas(nodes: [MermaidSceneNode], layout: MermaidGraphLayout) -> some View {
        ZStack {
            if drawsGraphBackground {
                MermaidDiagramBackground(kind: diagram.kind)
            }

            Canvas { context, _ in
                for edge in diagram.scene.edges {
                    guard let start = layout.positions[edge.sourceID],
                          let end = layout.positions[edge.targetID] else { continue }
                    let endpoints = MermaidLayout.edgeEndpoints(
                        from: start,
                        to: end,
                        nodeSize: layout.nodeSize
                    )
                    let path = edgePath(from: endpoints.start, to: endpoints.end, direction: layout.direction)
                    context.stroke(path, with: .color(edgeColor(for: edge.style)), style: StrokeStyle(lineWidth: edge.style == .thick ? 3 : 1.8, dash: edge.style == .dotted ? [6, 5] : []))
                    drawArrowhead(context: context, from: endpoints.start, to: endpoints.end, color: edgeColor(for: edge.style))
                    if let label = edge.label, !label.isEmpty {
                        context.draw(
                            Text(label)
                                .font(.system(size: 11 * fontScale, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary),
                            at: CGPoint(x: (endpoints.start.x + endpoints.end.x) / 2, y: (endpoints.start.y + endpoints.end.y) / 2 - 10),
                            anchor: .center
                        )
                    }
                }
            }
            .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)

            ForEach(nodes) { node in
                MermaidNodeCard(node: node, fontScale: fontScale)
                    .frame(width: layout.nodeSize.width, height: layout.nodeSize.height)
                    .position(layout.positions[node.id] ?? .zero)
            }
        }
        .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
    }

    private func sequenceView(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(diagram.scene.nodes) { node in
                        VStack(spacing: 8) {
                            MermaidNodeCard(node: node, fontScale: fontScale)
                                .frame(width: compact ? 116 : 140)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.26))
                                .frame(width: 2, height: compact ? 92 : 170)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(diagram.scene.edges.enumerated()), id: \.offset) { _, edge in
                    HStack(spacing: 8) {
                        Text(edge.sourceID)
                            .font(.system(size: 11 * fontScale, weight: .semibold, design: .rounded))
                        Image(systemName: edge.style == .dotted ? "arrow.right" : "arrow.right.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text(edge.targetID)
                            .font(.system(size: 11 * fontScale, weight: .semibold, design: .rounded))
                        if let label = edge.label {
                            Text(label)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 12 * fontScale, weight: .regular, design: .default))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func metricView(size: CGSize) -> some View {
        let metrics = diagram.scene.metrics
        let maxValue = max(metrics.map(\.value).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            if diagram.kind == .pie {
                MermaidPieChart(metrics: metrics, fontScale: fontScale)
                    .frame(height: min(size.height * 0.48, compact ? 120 : 220))
            }

            ForEach(metrics.prefix(compact ? 6 : 12)) { metric in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(metric.label)
                            .font(.system(size: 12 * fontScale, weight: .semibold, design: .default))
                        Spacer()
                        Text(metric.value.formatted())
                            .font(.system(size: 12 * fontScale, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.secondary.opacity(0.13))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(metricGradient)
                                    .frame(width: max(8, proxy.size.width * CGFloat(metric.value / maxValue)))
                            }
                    }
                    .frame(height: 10)
                }
            }
        }
        .padding(20)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func sectionView(size: CGSize) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(diagram.scene.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.system(size: 14 * fontScale, weight: .semibold, design: .default))
                        ForEach(Array(section.items.prefix(compact ? 5 : 14).enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.85))
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 5)
                                Text(item)
                                    .font(.system(size: 12 * fontScale, weight: .regular, design: .default))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(16)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private var metricGradient: LinearGradient {
        LinearGradient(
            colors: [Color.accentColor, Color.accentColor.opacity(0.56)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func edgeColor(for style: MermaidEdgeStyle) -> Color {
        switch style {
        case .solid, .thick:
            return Color.accentColor.opacity(0.82)
        case .dotted, .open:
            return Color.secondary.opacity(0.65)
        }
    }

    private func edgePath(from start: CGPoint, to end: CGPoint, direction: MermaidGraphDirection) -> Path {
        var path = Path()
        path.move(to: start)
        switch direction {
        case .leftRight, .rightLeft:
            let controlX = (start.x + end.x) / 2
            path.addCurve(
                to: end,
                control1: CGPoint(x: controlX, y: start.y),
                control2: CGPoint(x: controlX, y: end.y)
            )
        case .topBottom, .bottomTop:
            let controlY = (start.y + end.y) / 2
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x, y: controlY),
                control2: CGPoint(x: end.x, y: controlY)
            )
        }
        return path
    }

    private func drawArrowhead(context: GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color) {
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
        var path = Path()
        path.move(to: end)
        path.addLine(to: left)
        path.move(to: end)
        path.addLine(to: right)
        context.stroke(path, with: .color(color), lineWidth: 1.8)
    }
}

private enum MermaidPresentationKind {
    case graph
    case sequence
    case metrics
    case sections
}

private struct MermaidDiagramBackground: View {
    let kind: MermaidDiagramKind

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(baseGradient)
            Canvas { context, size in
                let spacing: CGFloat = 28
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(path, with: .color(Color.secondary.opacity(0.07)), lineWidth: 0.7)
            }
        }
    }

    private var baseGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(kind.supportStatus == .betaNativeCommon ? 0.12 : 0.08),
                Color.secondary.opacity(0.035)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct MermaidNodeCard: View {
    let node: MermaidSceneNode
    let fontScale: CGFloat

    var body: some View {
        Text(node.label.isEmpty ? node.id : node.label)
            .font(.system(size: 12 * fontScale, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.74)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(nodeBackground)
            .overlay(nodeStroke)
            .shadow(color: Color.black.opacity(0.06), radius: 7, y: 3)
    }

    @ViewBuilder
    private var nodeBackground: some View {
        switch node.shape {
        case .decision:
            DiamondShape()
                .fill(.regularMaterial)
        case .circle:
            Circle()
                .fill(.regularMaterial)
        default:
            RoundedRectangle(cornerRadius: node.shape == .rectangle ? 8 : 13, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    @ViewBuilder
    private var nodeStroke: some View {
        switch node.shape {
        case .decision:
            DiamondShape()
                .stroke(Color.accentColor.opacity(0.38), lineWidth: 1)
        case .circle:
            Circle()
                .stroke(Color.accentColor.opacity(0.38), lineWidth: 1)
        default:
            RoundedRectangle(cornerRadius: node.shape == .rectangle ? 8 : 13, style: .continuous)
                .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct MermaidPieChart: View {
    let metrics: [MermaidSceneMetric]
    let fontScale: CGFloat

    var body: some View {
        Canvas { context, size in
            let total = max(metrics.map(\.value).reduce(0, +), 1)
            let radius = min(size.width, size.height) / 2 - 8
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            var startAngle = Angle(degrees: -90)
            for (index, metric) in metrics.enumerated() {
                let sweep = Angle(degrees: 360 * metric.value / total)
                var path = Path()
                path.move(to: center)
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: startAngle + sweep,
                    clockwise: false
                )
                path.closeSubpath()
                context.fill(path, with: .color(paletteColor(index)))
                startAngle += sweep
            }
        }
        .overlay(alignment: .bottomTrailing) {
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(Array(metrics.prefix(4).enumerated()), id: \.element.id) { index, metric in
                    HStack(spacing: 5) {
                        Circle().fill(paletteColor(index)).frame(width: 8, height: 8)
                        Text(metric.label)
                            .font(.system(size: 10 * fontScale, weight: .medium, design: .default))
                            .lineLimit(1)
                    }
                }
            }
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(8)
        }
    }

    private func paletteColor(_ index: Int) -> Color {
        let colors: [Color] = [.accentColor, .orange, .teal, .pink, .indigo, .green, .yellow, .red]
        return colors[index % colors.count]
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct MermaidGraphLayout {
    let canvasSize: CGSize
    let nodeSize: CGSize
    let positions: [String: CGPoint]
    let direction: MermaidGraphDirection
}

private enum MermaidLayout {
    static func canvasSize(
        for diagram: MarkdownMermaidDiagram,
        viewportSize: CGSize,
        compact: Bool
    ) -> CGSize {
        let nodes = diagram.scene.nodes.isEmpty
            ? [MermaidSceneNode(id: "empty", label: diagram.kind.displayName, shape: .rounded, lane: nil)]
            : diagram.scene.nodes
        if diagram.scene.edges.isEmpty && diagram.scene.nodes.isEmpty {
            return viewportSize
        }
        if diagram.kind == .sequenceDiagram || diagram.kind == .zenuml {
            return viewportSize
        }
        return graphLayout(
            for: nodes,
            edges: diagram.scene.edges,
            direction: diagram.scene.direction ?? .topBottom,
            viewportSize: viewportSize,
            compact: compact
        ).canvasSize
    }

    static func graphLayout(
        for nodes: [MermaidSceneNode],
        edges: [MermaidSceneEdge],
        direction: MermaidGraphDirection,
        viewportSize: CGSize,
        compact: Bool
    ) -> MermaidGraphLayout {
        let nodeSize = Self.nodeSize(compact: compact)
        guard !nodes.isEmpty else {
            return MermaidGraphLayout(
                canvasSize: viewportSize,
                nodeSize: nodeSize,
                positions: [:],
                direction: direction
            )
        }
        let ranks = Self.ranks(for: nodes, edges: edges)
        let rankValues = Array(Set(ranks.values)).sorted()
        let groups = rankValues.map { rank in
            nodes.filter { ranks[$0.id] == rank }
        }
        let rankCount = max(groups.count, 1)
        let maxLaneCount = max(groups.map(\.count).max() ?? 1, 1)
        let horizontalInset: CGFloat = compact ? 70 : 90
        let verticalInset: CGFloat = compact ? 48 : 58
        let rankGap: CGFloat = compact ? 48 : 74
        let laneGap: CGFloat = compact ? 18 : 26
        let positions: [String: CGPoint]
        let canvasSize: CGSize

        switch direction {
        case .leftRight, .rightLeft:
            canvasSize = CGSize(
                width: max(
                    viewportSize.width,
                    horizontalInset * 2
                        + CGFloat(rankCount) * nodeSize.width
                        + CGFloat(max(rankCount - 1, 0)) * rankGap
                ),
                height: max(
                    viewportSize.height,
                    verticalInset * 2
                        + CGFloat(maxLaneCount) * nodeSize.height
                        + CGFloat(max(maxLaneCount - 1, 0)) * laneGap
                )
            )
            positions = positionsForHorizontalLayout(
                groups: groups,
                direction: direction,
                canvasSize: canvasSize,
                nodeSize: nodeSize,
                horizontalInset: horizontalInset,
                rankGap: rankGap,
                laneGap: laneGap
            )
        case .topBottom, .bottomTop:
            canvasSize = CGSize(
                width: max(
                    viewportSize.width,
                    horizontalInset * 2
                        + CGFloat(maxLaneCount) * nodeSize.width
                        + CGFloat(max(maxLaneCount - 1, 0)) * laneGap
                ),
                height: max(
                    viewportSize.height,
                    verticalInset * 2
                        + CGFloat(rankCount) * nodeSize.height
                        + CGFloat(max(rankCount - 1, 0)) * rankGap
                )
            )
            positions = positionsForVerticalLayout(
                groups: groups,
                direction: direction,
                canvasSize: canvasSize,
                nodeSize: nodeSize,
                verticalInset: verticalInset,
                rankGap: rankGap,
                laneGap: laneGap
            )
        }

        return MermaidGraphLayout(
            canvasSize: canvasSize,
            nodeSize: nodeSize,
            positions: positions,
            direction: direction
        )
    }

    static func edgeEndpoints(
        from start: CGPoint,
        to end: CGPoint,
        nodeSize: CGSize
    ) -> (start: CGPoint, end: CGPoint) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        guard dx != 0 || dy != 0 else { return (start, end) }
        let startOffset = boundaryOffset(dx: dx, dy: dy, nodeSize: nodeSize)
        let endOffset = boundaryOffset(dx: -dx, dy: -dy, nodeSize: nodeSize)
        return (
            CGPoint(x: start.x + startOffset.dx, y: start.y + startOffset.dy),
            CGPoint(x: end.x + endOffset.dx, y: end.y + endOffset.dy)
        )
    }

    private static func nodeSize(compact: Bool) -> CGSize {
        CGSize(width: compact ? 138 : 178, height: compact ? 60 : 70)
    }

    private static func ranks(
        for nodes: [MermaidSceneNode],
        edges: [MermaidSceneEdge]
    ) -> [String: Int] {
        let nodeIDs = nodes.map(\.id)
        let nodeIDSet = Set(nodeIDs)
        var ranks = Dictionary(uniqueKeysWithValues: nodeIDs.map { ($0, 0) })
        var incomingCounts = Dictionary(uniqueKeysWithValues: nodeIDs.map { ($0, 0) })
        var outgoing: [String: [String]] = [:]

        for edge in edges where nodeIDSet.contains(edge.sourceID) && nodeIDSet.contains(edge.targetID) && edge.sourceID != edge.targetID {
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

    private static func positionsForHorizontalLayout(
        groups: [[MermaidSceneNode]],
        direction: MermaidGraphDirection,
        canvasSize: CGSize,
        nodeSize: CGSize,
        horizontalInset: CGFloat,
        rankGap: CGFloat,
        laneGap: CGFloat
    ) -> [String: CGPoint] {
        var result: [String: CGPoint] = [:]
        let rankCount = groups.count
        for (rankIndex, group) in groups.enumerated() {
            let visualRankIndex = direction == .rightLeft ? rankCount - 1 - rankIndex : rankIndex
            let x = horizontalInset + nodeSize.width / 2 + CGFloat(visualRankIndex) * (nodeSize.width + rankGap)
            let groupHeight = CGFloat(group.count) * nodeSize.height + CGFloat(max(group.count - 1, 0)) * laneGap
            let top = (canvasSize.height - groupHeight) / 2
            for (laneIndex, node) in group.enumerated() {
                result[node.id] = CGPoint(
                    x: x,
                    y: top + nodeSize.height / 2 + CGFloat(laneIndex) * (nodeSize.height + laneGap)
                )
            }
        }
        return result
    }

    private static func positionsForVerticalLayout(
        groups: [[MermaidSceneNode]],
        direction: MermaidGraphDirection,
        canvasSize: CGSize,
        nodeSize: CGSize,
        verticalInset: CGFloat,
        rankGap: CGFloat,
        laneGap: CGFloat
    ) -> [String: CGPoint] {
        var result: [String: CGPoint] = [:]
        let rankCount = groups.count
        for (rankIndex, group) in groups.enumerated() {
            let visualRankIndex = direction == .bottomTop ? rankCount - 1 - rankIndex : rankIndex
            let y = verticalInset + nodeSize.height / 2 + CGFloat(visualRankIndex) * (nodeSize.height + rankGap)
            let groupWidth = CGFloat(group.count) * nodeSize.width + CGFloat(max(group.count - 1, 0)) * laneGap
            let left = (canvasSize.width - groupWidth) / 2
            for (laneIndex, node) in group.enumerated() {
                result[node.id] = CGPoint(
                    x: left + nodeSize.width / 2 + CGFloat(laneIndex) * (nodeSize.width + laneGap),
                    y: y
                )
            }
        }
        return result
    }

    private static func boundaryOffset(dx: CGFloat, dy: CGFloat, nodeSize: CGSize) -> CGVector {
        let halfWidth = nodeSize.width / 2
        let halfHeight = nodeSize.height / 2
        let xScale = dx == 0 ? CGFloat.greatestFiniteMagnitude : halfWidth / abs(dx)
        let yScale = dy == 0 ? CGFloat.greatestFiniteMagnitude : halfHeight / abs(dy)
        let scale = min(xScale, yScale)
        return CGVector(dx: dx * scale, dy: dy * scale)
    }
}
