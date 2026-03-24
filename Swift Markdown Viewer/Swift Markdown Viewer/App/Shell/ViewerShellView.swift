import AVKit
import SwiftUI

#if os(macOS)
import AppKit
import Security
#elseif os(iOS)
import UIKit
#endif

struct ViewerShellView: View {
    @ObservedObject var model: AppModel
    let onOpenFolder: (() -> Void)?
    #if os(macOS)
    @FocusState private var sidebarFocused: Bool
    #endif

    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                macNavigationControls
            }
            ToolbarItem(placement: .primaryAction) {
                macRevealInFinderButton
            }
        }
        .background(MacWindowConfiguration(title: model.windowTitle, contentSize: model.launchOptions.windowSize))
        #endif
    }

    private var sidebarContent: some View {
        List(model.files) { file in
            sidebarRow(for: file)
        }
        #if os(macOS)
        .focusable()
        .focused($sidebarFocused)
        #endif
        .listStyle(.sidebar)
        .accessibilityIdentifier(AccessibilityIDs.sidebarList)
        #if os(macOS)
        .onMoveCommand(perform: handleSidebarMove)
        .background(
            MacSidebarKeyEventBridge(
                isEnabled: sidebarFocused,
                onMoveUp: { model.selectAdjacentFile(offset: -1) },
                onMoveDown: { model.selectAdjacentFile(offset: 1) }
            )
        )
        .onAppear {
            sidebarFocused = true
        }
        #endif
    }

    private func sidebarRow(for file: MarkdownFileNode) -> some View {
        let isSelected = model.selectedPath == file.path
        return Button {
            #if os(macOS)
            sidebarFocused = true
            #endif
            model.openFile(file.path)
        } label: {
            SidebarFileRow(file: file, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
        .listRowBackground(sidebarRowBackground(isSelected: isSelected))
        .accessibilityIdentifier(AccessibilityIDs.sidebarNode(file.path.rawValue))
    }

    #if os(macOS)
    private func handleSidebarMove(_ direction: MoveCommandDirection) {
        #if os(macOS)
        guard sidebarFocused else { return }
        #endif

        switch direction {
        case .up:
            model.selectAdjacentFile(offset: -1)
        case .down:
            model.selectAdjacentFile(offset: 1)
        default:
            break
        }
    }
    #endif

    private func sidebarRowBackground(isSelected: Bool) -> some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(0.22))
                    .padding(.vertical, 1)
            } else {
                Color.clear
            }
        }
    }

    private var detailContent: some View {
        ZStack {
            if shouldShowEmptyWorkspaceState {
                emptyWorkspaceState
            } else if model.shouldRenderBlockContent {
                DocumentBlockScrollView(
                    blocks: model.documentBlocks,
                    workspaceRootURL: model.currentWorkspaceRootURL
                )
                    .padding(20)
            } else {
                SelectableDocumentTextView(blocks: model.documentBlocks)
                    .padding(20)
            }

            if model.isLoadingDocument {
                loadingOverlay
            }
        }
        #if os(macOS)
        .overlay(alignment: .topLeading) {
            Text(model.windowTitle)
                .accessibilityIdentifier(AccessibilityIDs.title)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
        #endif
        #if !os(macOS)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 12) {
                Button(action: model.navigateBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(!model.canNavigateBack)
                .accessibilityIdentifier(AccessibilityIDs.backButton)

                Button(action: model.navigateForward) {
                    Label("Forward", systemImage: "chevron.right")
                }
                .disabled(!model.canNavigateForward)
                .accessibilityIdentifier(AccessibilityIDs.forwardButton)

                Text(model.windowTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .accessibilityIdentifier(AccessibilityIDs.title)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        #endif
    }

    private var loadingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text("Loading document…")
                    .font(.headline)
            }
            .padding(24)
        }
        .frame(width: 220, height: 140)
        .allowsHitTesting(false)
    }

    private var shouldShowEmptyWorkspaceState: Bool {
        model.files.isEmpty && model.documentText == "No markdown files found."
    }

    private var emptyWorkspaceState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(.secondary)
            Text("No markdown files found.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(AccessibilityIDs.emptyStateMessage)
            if let onOpenFolder {
                Button("Open Another Folder") {
                    onOpenFolder()
                }
                .accessibilityIdentifier(AccessibilityIDs.emptyStateOpenFolderButton)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(24)
    }

    #if os(macOS)
    private var macNavigationControls: some View {
        ControlGroup {
            Button(action: model.navigateBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!model.canNavigateBack)
            .accessibilityIdentifier(AccessibilityIDs.backButton)
            .help("Back")

            Button(action: model.navigateForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!model.canNavigateForward)
            .accessibilityIdentifier(AccessibilityIDs.forwardButton)
            .help("Forward")
        }
        .controlGroupStyle(.navigation)
        .labelStyle(.iconOnly)
    }

    private var macRevealInFinderButton: some View {
        Button(action: revealSelectedDocumentInFinder) {
            Label("Show in Finder", systemImage: "folder")
        }
        .disabled(!model.canRevealSelectedFileInFinder)
        .accessibilityIdentifier(AccessibilityIDs.revealInFinderButton)
        .help("Show in Finder")
    }

    private func revealSelectedDocumentInFinder() {
        guard let selectedFileURL = model.selectedFileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selectedFileURL])
    }
    #endif
}

private struct DocumentBlockScrollView: View {
    let blocks: [MarkdownBlock]
    let workspaceRootURL: URL?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(blocks) { block in
                    MarkdownBlockView(block: block, workspaceRootURL: workspaceRootURL)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .accessibilityIdentifier(AccessibilityIDs.scrollView)
    }
}

private struct SidebarFileRow: View {
    let file: MarkdownFileNode
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            Text(file.name)
                .font(.body)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let workspaceRootURL: URL?

    var body: some View {
        switch block.kind {
        case .heading:
            Text(MarkdownRenderer.attributedText(for: block))
                .font(headingFont(for: block.level ?? 1))
                .fontWeight(.semibold)
        case .paragraph:
            Text(MarkdownRenderer.attributedText(for: block))
                .font(.body)
        case .unorderedListItem:
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Text(listMarker)
                    Text(MarkdownRenderer.attributedText(for: block))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !block.children.isEmpty {
                    childBlocks
                }
            }
            .padding(.leading, CGFloat(block.indentLevel) * 18)
        case .orderedListItem:
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Text(listMarker)
                        .monospacedDigit()
                    Text(MarkdownRenderer.attributedText(for: block))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !block.children.isEmpty {
                    childBlocks
                }
            }
            .padding(.leading, CGFloat(block.indentLevel) * 18)
        case .blockquote:
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 4)
                Text(MarkdownRenderer.attributedText(for: block))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .codeBlock:
            ScrollView(.horizontal, showsIndicators: false) {
                Text(verbatim: block.sourceText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .table:
            if let table = block.table {
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow {
                                ForEach(Array(table.header.enumerated()), id: \.offset) { column, cell in
                                Text(MarkdownRenderer.attributedText(for: cell))
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity, alignment: alignment(for: table.alignments[column]))
                            }
                        }
                        Divider()
                            .gridCellColumns(table.header.count)
                        ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                            GridRow {
                                    ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                                    Text(MarkdownRenderer.attributedText(for: cell))
                                        .frame(maxWidth: .infinity, alignment: alignment(for: table.alignments[column]))
                                }
                            }
                        }
                    }
                    .padding(14)
                }
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
            }
        case .image, .animatedImage:
            if let image = block.image {
                ImageBlockView(
                    image: image,
                    isAnimated: block.kind == .animatedImage,
                    blockID: block.id,
                    workspaceRootURL: workspaceRootURL
                )
            }
        case .video:
            if let video = block.video {
                InlineVideoBlockView(video: video, blockID: block.id, workspaceRootURL: workspaceRootURL)
            }
        case .rawHTML:
            Text(verbatim: block.sourceText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .thematicBreak:
            Divider()
                .padding(.vertical, 4)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1:
            return .system(size: 30, weight: .semibold, design: .default)
        case 2:
            return .system(size: 24, weight: .semibold, design: .default)
        case 3:
            return .system(size: 20, weight: .semibold, design: .default)
        default:
            return .headline
        }
    }

    private var listMarker: String {
        if block.isTaskItem {
            return block.isTaskCompleted == true ? "\u{2611}" : "\u{2610}"
        }
        if block.kind == .orderedListItem {
            return "\(block.listItemIndex ?? 1)."
        }
        return "\u{2022}"
    }

    @ViewBuilder
    private var childBlocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(block.children) { child in
                MarkdownBlockView(block: child, workspaceRootURL: workspaceRootURL)
            }
        }
        .padding(.leading, 28)
    }

    private func alignment(for alignment: MarkdownTableAlignment) -> Alignment {
        switch alignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
}

private struct ImageBlockView: View {
    let image: MarkdownImage
    let isAnimated: Bool
    let blockID: String
    let workspaceRootURL: URL?

    private var imageLoadError: String? {
        mediaLoadError(
            resolvedURL: image.resolvedURL,
            sourceURL: image.sourceURL,
            kindLabel: isAnimated ? "Animated image" : "Image",
            workspaceRootURL: workspaceRootURL,
            canDecode: { url in
                #if os(macOS)
                return NSImage(contentsOf: url) != nil
                #elseif os(iOS)
                return UIImage(contentsOfFile: url.path) != nil
                #endif
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let resolvedURL = image.resolvedURL, imageLoadError == nil {
                InlineAnimatedImageSurface(url: resolvedURL)
                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 320, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 180)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: imageLoadError == nil ? "photo" : "exclamationmark.triangle")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundStyle(.secondary)
                            if let imageLoadError {
                                Text(imageLoadError)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(primaryLabel)
                    .font(.headline)
                    .accessibilityIdentifier(AccessibilityIDs.imageBlock(blockID))
                Text(image.sourceURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let title = image.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let imageLoadError {
                    Text(imageLoadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIDs.imageBlock(blockID))
    }

    private var primaryLabel: String {
        if image.altText.isEmpty {
            return isAnimated ? "Animated image" : "Image"
        }
        return image.altText
    }
}

private struct InlineVideoBlockView: View {
    let video: MarkdownVideo
    let blockID: String
    let workspaceRootURL: URL?

    @State private var player: AVPlayer?
    @State private var playerError: String?
    @State private var isPlaying = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.9))

                if let player {
                    InlineVideoSurface(player: player)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: playerError == nil ? "video" : "exclamationmark.triangle")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                        if let playerError {
                            Text(playerError)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 16)
                        }
                    }
                }

                if !isPlaying && player != nil {
                    Button {
                        togglePlayback()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.headline)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: Capsule())
                            .accessibilityIdentifier(AccessibilityIDs.videoPlayButton(blockID))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Play video")
                    .accessibilityIdentifier(AccessibilityIDs.videoPlayButton(blockID))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 280)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.altText.isEmpty ? "Video" : video.altText)
                    .font(.headline)
                    .accessibilityIdentifier(AccessibilityIDs.videoBlock(blockID))
                Text(video.sourceURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let title = video.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let playerError {
                    Text(playerError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIDs.videoBlock(blockID))
        .onAppear(perform: configurePlayerIfNeeded)
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
    }

    private func configurePlayerIfNeeded() {
        guard player == nil, playerError == nil else { return }
        guard let resolvedURL = video.resolvedURL else {
            playerError = unresolvedMediaError(sourceURL: video.sourceURL, kindLabel: "Video")
            return
        }
        guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
            playerError = missingMediaError(resolvedURL: resolvedURL, sourceURL: video.sourceURL, kindLabel: "Video")
            return
        }
        guard FileManager.default.isReadableFile(atPath: resolvedURL.path) else {
            playerError = unreadableMediaError(
                resolvedURL: resolvedURL,
                sourceURL: video.sourceURL,
                kindLabel: "Video",
                workspaceRootURL: workspaceRootURL
            )
            return
        }

        Task {
            let asset = AVURLAsset(url: resolvedURL)
            do {
                let isPlayable = try await asset.load(.isPlayable)
                let hasProtectedContent = try await asset.load(.hasProtectedContent)
                guard isPlayable, !hasProtectedContent else {
                    await MainActor.run {
                        playerError = """
                        Video is not playable.
                        source: \(video.sourceURL)
                        resolved: \(resolvedURL.path)
                        """
                    }
                    return
                }

                let playerItem = AVPlayerItem(asset: asset)
                let player = AVPlayer(playerItem: playerItem)
                player.actionAtItemEnd = .pause
                await MainActor.run {
                    player.seek(to: .zero)
                    self.player = player
                }
            } catch {
                await MainActor.run {
                    playerError = """
                    Video failed to load: \(error.localizedDescription)
                    source: \(video.sourceURL)
                    resolved: \(resolvedURL.path)
                    """
                }
            }
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            if let currentItem = player.currentItem,
               currentItem.status == .readyToPlay,
               currentItem.currentTime() >= currentItem.duration {
                player.seek(to: .zero)
            }
            player.play()
        }
        isPlaying.toggle()
    }
}

private func mediaLoadError(
    resolvedURL: URL?,
    sourceURL: String,
    kindLabel: String,
    workspaceRootURL: URL?,
    canDecode: (URL) -> Bool
) -> String? {
    guard let resolvedURL else {
        return unresolvedMediaError(sourceURL: sourceURL, kindLabel: kindLabel)
    }
    guard FileManager.default.fileExists(atPath: resolvedURL.path) else {
        return missingMediaError(resolvedURL: resolvedURL, sourceURL: sourceURL, kindLabel: kindLabel)
    }
    guard FileManager.default.isReadableFile(atPath: resolvedURL.path) else {
        return unreadableMediaError(
            resolvedURL: resolvedURL,
            sourceURL: sourceURL,
            kindLabel: kindLabel,
            workspaceRootURL: workspaceRootURL
        )
    }
    guard canDecode(resolvedURL) else {
        return """
        \(kindLabel) failed to decode.
        source: \(sourceURL)
        resolved: \(resolvedURL.path)
        """
    }
    return nil
}

private func unresolvedMediaError(sourceURL: String, kindLabel: String) -> String {
    """
    \(kindLabel) path could not be resolved.
    source: \(sourceURL)
    """
}

private func missingMediaError(resolvedURL: URL, sourceURL: String, kindLabel: String) -> String {
    """
    \(kindLabel) file is missing.
    source: \(sourceURL)
    resolved: \(resolvedURL.path)
    """
}

func unreadableMediaError(
    resolvedURL: URL,
    sourceURL: String,
    kindLabel: String,
    workspaceRootURL: URL?
) -> String {
    if let sandboxMessage = sandboxEscapeMediaError(
        resolvedURL: resolvedURL,
        sourceURL: sourceURL,
        kindLabel: kindLabel,
        workspaceRootURL: workspaceRootURL
    ) {
        return sandboxMessage
    }

    return """
    \(kindLabel) file is not readable.
    source: \(sourceURL)
    resolved: \(resolvedURL.path)
    """
}

func sandboxEscapeMediaError(
    resolvedURL: URL,
    sourceURL: String,
    kindLabel: String,
    workspaceRootURL: URL?
) -> String? {
    #if os(macOS)
    guard let workspaceRootURL else { return nil }
    guard isAppSandboxEnabled() else { return nil }

    let canonicalRootPath = workspaceRootURL.resolvingSymlinksInPath().standardizedFileURL.path
    let canonicalResolvedPath = resolvedURL.resolvingSymlinksInPath().standardizedFileURL.path
    let escapedWorkspaceRoot =
        canonicalResolvedPath != canonicalRootPath &&
        !canonicalResolvedPath.hasPrefix(canonicalRootPath + "/")

    guard escapedWorkspaceRoot else { return nil }

    return """
    \(kindLabel) is outside the opened folder and macOS sandbox access is blocked.
    Open the parent folder that contains both the markdown file and the media file.
    source: \(sourceURL)
    opened root: \(canonicalRootPath)
    resolved: \(canonicalResolvedPath)
    """
    #else
    return nil
    #endif
}

func isAppSandboxEnabled() -> Bool {
    #if os(macOS)
    guard let task = SecTaskCreateFromSelf(nil) else { return false }
    let key = "com.apple.security.app-sandbox" as CFString
    guard let value = SecTaskCopyValueForEntitlement(task, key, nil) else { return false }
    guard CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
    return CFBooleanGetValue(unsafeBitCast(value, to: CFBoolean.self))
    #else
    return false
    #endif
}

private struct InlineAnimatedImageSurface: View {
    let url: URL

    var body: some View {
        PlatformAnimatedImageView(url: url)
            .frame(maxWidth: .infinity, maxHeight: 320, alignment: .leading)
    }
}

private struct InlineVideoSurface: View {
    let player: AVPlayer

    var body: some View {
        PlatformInlineVideoView(player: player)
    }
}

#if os(macOS)
private struct PlatformAnimatedImageView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.animates = true
        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        return imageView
    }

    func updateNSView(_ imageView: NSImageView, context: Context) {
        imageView.image = NSImage(contentsOf: url)
    }
}

private struct PlatformInlineVideoView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .none
        playerView.showsFullScreenToggleButton = false
        playerView.videoGravity = .resizeAspect
        return playerView
    }

    func updateNSView(_ playerView: AVPlayerView, context: Context) {
        if playerView.player !== player {
            playerView.player = player
        }
    }
}
#elseif os(iOS)
private struct PlatformAnimatedImageView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }

    func updateUIView(_ imageView: UIImageView, context: Context) {
        imageView.image = UIImage(contentsOfFile: url.path)
    }
}

private struct PlatformInlineVideoView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}
#endif
