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
    let onOpenGitHubURLPrompt: (() -> Void)?
    let onInstallCommandLineTool: (() -> Void)?
    let shouldShowCommandLineToolPrompt: Bool
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var mediaPreviewTarget: AppModel.MediaLinkTarget?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var compactShowsSidebar = true
    @State private var sidebarFilterText = ""
    @State private var hasConsumedUITestMediaPreview = false
    #if os(macOS)
    @FocusState private var sidebarFocused: Bool
    @FocusState private var sidebarFilterFocused: Bool
    #endif

    var body: some View {
        Group {
            if model.shouldShowOpenFolderPromptState {
                openFolderPromptState
            } else if isCompactPhoneLayout {
                compactPhoneContent
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    sidebarContent
                } detail: {
                    detailContent
                }
                .onAppear {
                    updatePreferredColumnVisibility()
                }
                .onChange(of: model.selectedPath) { _ in
                    updatePreferredColumnVisibility()
                }
                .onChange(of: horizontalSizeClass) { _ in
                    updatePreferredColumnVisibility()
                }
            }
        }
        .onAppear(perform: handleUITestMediaPreviewIfNeeded)
        .onChange(of: model.selectedPath) { _ in
            handleUITestMediaPreviewIfNeeded()
        }
        .sheet(item: sheetMediaPreviewBinding) { target in
            mediaPreview(for: target)
        }
        .popover(item: popoverMediaPreviewBinding) { target in
            mediaPreview(for: target)
        }
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                macNavigationControls
            }
            ToolbarItem(placement: .automatic) {
                fontSizeControls
            }
            ToolbarItem(placement: .primaryAction) {
                macRevealInFinderButton
            }
        }
        .overlay(alignment: .topLeading) {
            Text(model.windowTitle)
                .accessibilityIdentifier(AccessibilityIDs.title)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
        .background(MacWindowConfiguration(title: model.windowTitle, contentSize: model.launchOptions.windowSize))
        #endif
    }

    private var usesSheetPreview: Bool {
        #if os(macOS)
        true
        #else
        model.launchOptions.platformTarget == .ios && model.launchOptions.deviceClass == .iphone
        #endif
    }

    private var sheetMediaPreviewBinding: Binding<AppModel.MediaLinkTarget?> {
        Binding(
            get: { usesSheetPreview ? mediaPreviewTarget : nil },
            set: { newValue in
                if usesSheetPreview {
                    mediaPreviewTarget = newValue
                } else if newValue == nil {
                    mediaPreviewTarget = nil
                }
            }
        )
    }

    private var popoverMediaPreviewBinding: Binding<AppModel.MediaLinkTarget?> {
        Binding(
            get: { usesSheetPreview ? nil : mediaPreviewTarget },
            set: { newValue in
                if usesSheetPreview {
                    if newValue == nil {
                        mediaPreviewTarget = nil
                    }
                } else {
                    mediaPreviewTarget = newValue
                }
            }
        )
    }

    private var isCompactPhoneLayout: Bool {
        horizontalSizeClass == .compact && model.launchOptions.deviceClass == .iphone
    }

    private var compactPhoneContent: some View {
        Group {
            if compactShowsSidebar && !model.files.isEmpty {
                sidebarContent
            } else {
                detailContent
            }
        }
        .onAppear {
            updatePreferredColumnVisibility()
        }
        .onChange(of: model.selectedPath) { _ in
            updatePreferredColumnVisibility()
        }
        .onChange(of: horizontalSizeClass) { _ in
            updatePreferredColumnVisibility()
        }
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            sidebarFilterField

            List(filteredFiles) { file in
                sidebarRow(for: file)
            }
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
                isEnabled: sidebarFocused || sidebarFilterFocused,
                onMoveUp: { selectAdjacentSidebarFile(offset: -1) },
                onMoveDown: { selectAdjacentSidebarFile(offset: 1) },
                onQuickFilter: {
                    sidebarFilterFocused = true
                },
                onToggleFocus: {
                    toggleSidebarKeyboardFocus()
                }
            )
        )
        .onAppear {
            sidebarFocused = true
        }
        #endif
    }

    private var sidebarFilterField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Quick Filter", text: $sidebarFilterText)
                .accessibilityIdentifier(AccessibilityIDs.sidebarFilterField)
                #if os(macOS)
                .textFieldStyle(.plain)
                .focused($sidebarFilterFocused)
                #else
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                #endif

            if !sidebarFilterText.isEmpty {
                Button {
                    sidebarFilterText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Quick Filter")
                .accessibilityIdentifier(AccessibilityIDs.sidebarFilterClearButton)
            }
        }
        #if os(macOS)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
        #else
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background {
            Color(uiColor: .systemBackground)
        }
        .overlay(alignment: .bottom) {
            Divider()
        }
        #endif
    }

    private var filteredFiles: [MarkdownFileNode] {
        AppModel.filteredFiles(from: model.files, matching: sidebarFilterText)
    }

    private func sidebarRow(for file: MarkdownFileNode) -> some View {
        let isSelected = model.selectedPath == file.path
        return Button {
            #if os(macOS)
            sidebarFocused = true
            #endif
            model.openFile(file.path)
            showDetailIfNeeded()
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
            selectAdjacentSidebarFile(offset: -1)
        case .down:
            selectAdjacentSidebarFile(offset: 1)
        default:
            break
        }
    }
    #endif

    private func selectAdjacentSidebarFile(offset: Int) {
        guard let targetPath = AppModel.adjacentFilePath(
            from: model.selectedPath,
            within: filteredFiles,
            offset: offset
        ) else { return }
        model.openFile(targetPath)
        showDetailIfNeeded()
    }

    #if os(macOS)
    private func toggleSidebarKeyboardFocus() {
        if sidebarFilterFocused {
            sidebarFilterFocused = false
            sidebarFocused = true
        } else {
            sidebarFocused = false
            sidebarFilterFocused = true
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
                    workspaceRootURL: model.currentWorkspaceRootURL,
                    fontScale: model.fontScale,
                    syntaxTheme: SyntaxHighlightTheme.resolved(
                        launchTheme: model.launchOptions.theme,
                        colorScheme: colorScheme
                    )
                )
                    .padding(20)
            } else {
                SelectableDocumentTextView(
                    blocks: model.documentBlocks,
                    fontScale: model.fontScale,
                    onOpenLink: handleDocumentLink(_:)
                )
                    .padding(20)
            }

            if model.isLoadingDocument {
                loadingOverlay
            } else if model.isLoadingWorkspace {
                workspaceLoadingOverlay
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            handleDocumentLink(url)
            return .handled
        })
        #if !os(macOS)
        .safeAreaInset(edge: .top) {
            Group {
                if isCompactPhoneLayout {
                    compactPhoneTopBar
                } else {
                    regularMobileTopBar
                }
            }
        }
        #endif
    }

    #if !os(macOS)
    private var regularMobileTopBar: some View {
        HStack(spacing: 12) {
            if showsFilesButton {
                Button(action: showSidebar) {
                    Label("Files", systemImage: "sidebar.left")
                }
                .accessibilityIdentifier("\(AccessibilityIDs.openFolderButton).sidebar")
            }

            Button(action: model.navigateBack) {
                Image(systemName: "chevron.left")
            }
            .disabled(!model.canNavigateBack)
            .accessibilityIdentifier(AccessibilityIDs.backButton)

            Button(action: model.navigateForward) {
                Image(systemName: "chevron.right")
            }
            .disabled(!model.canNavigateForward)
            .accessibilityIdentifier(AccessibilityIDs.forwardButton)

            if let onOpenFolder {
                Button(action: onOpenFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .accessibilityIdentifier(AccessibilityIDs.openFolderButton)
            }

            if let onOpenGitHubURLPrompt {
                Button(action: onOpenGitHubURLPrompt) {
                    Label("Open GitHub URL", systemImage: "link")
                }
                .accessibilityIdentifier(AccessibilityIDs.openGitHubURLButton)
            }

            fontSizeControls

            Text(model.windowTitle)
                .font(ViewerFont.headline(scale: model.fontScale))
                .lineLimit(1)
                .accessibilityIdentifier(AccessibilityIDs.title)

            Spacer()
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var compactPhoneTopBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if showsFilesButton {
                    Button(action: showSidebar) {
                        Image(systemName: "sidebar.left")
                    }
                    .accessibilityIdentifier("\(AccessibilityIDs.openFolderButton).sidebar")
                }

                Button(action: model.navigateBack) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!model.canNavigateBack)
                .accessibilityIdentifier(AccessibilityIDs.backButton)

                Button(action: model.navigateForward) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!model.canNavigateForward)
                .accessibilityIdentifier(AccessibilityIDs.forwardButton)

                if let onOpenFolder {
                    Button(action: onOpenFolder) {
                        Image(systemName: "folder.badge.plus")
                    }
                    .accessibilityIdentifier(AccessibilityIDs.openFolderButton)
                }

                if let onOpenGitHubURLPrompt {
                    Button(action: onOpenGitHubURLPrompt) {
                        Image(systemName: "link")
                    }
                    .accessibilityIdentifier(AccessibilityIDs.openGitHubURLButton)
                }

                Spacer(minLength: 0)

                fontSizeControls
            }

            Text(model.windowTitle)
                .font(ViewerFont.headline(scale: model.fontScale))
                .lineLimit(1)
                .accessibilityIdentifier(AccessibilityIDs.title)
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    #endif

    private var loadingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text("Loading document…")
                    .font(ViewerFont.headline(scale: model.fontScale))
            }
            .padding(24)
        }
        .frame(width: 220, height: 140)
        .allowsHitTesting(false)
    }

    private var workspaceLoadingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text("Loading workspace…")
                    .font(ViewerFont.headline(scale: model.fontScale))
            }
            .padding(24)
        }
        .frame(width: 240, height: 140)
        .allowsHitTesting(false)
    }

    private var shouldShowEmptyWorkspaceState: Bool {
        model.shouldShowEmptyWorkspaceState
    }

    private var openFolderPromptState: some View {
        emptyStateCard(
            iconName: "folder.badge.plus",
            message: AppModel.noWorkspacePromptMessage,
            buttonTitle: "Open Folder",
            includeGitHubURLForm: true,
            secondaryMessage: shouldShowCommandLineToolPrompt ? commandLineToolInstallExplanation : nil,
            secondaryButtonTitle: shouldShowCommandLineToolPrompt ? "Install `qmv`" : nil,
            secondaryAction: shouldShowCommandLineToolPrompt ? onInstallCommandLineTool : nil
        )
    }

    private var emptyWorkspaceState: some View {
        emptyStateCard(
            iconName: "folder.badge.questionmark",
            message: AppModel.emptyWorkspaceMessage,
            buttonTitle: "Open Another Folder"
        )
    }

    private func emptyStateCard(
        iconName: String,
        message: String,
        buttonTitle: String,
        includeGitHubURLForm: Bool = false,
        secondaryMessage: String? = nil,
        secondaryButtonTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(ViewerFont.scaledSystem(size: 32, weight: .medium, scale: model.fontScale))
                .foregroundStyle(.secondary)
            Text(message)
                .font(ViewerFont.title3(scale: model.fontScale))
                .multilineTextAlignment(.center)
                .accessibilityLabel(Text(message))
                .accessibilityIdentifier(AccessibilityIDs.emptyStateMessage)
            if let onOpenFolder {
                Button(buttonTitle) {
                    onOpenFolder()
                }
                .accessibilityIdentifier(AccessibilityIDs.emptyStateOpenFolderButton)
            }
            if includeGitHubURLForm {
                Text("-or-")
                    .font(ViewerFont.body(scale: model.fontScale))
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)

                GitHubURLLoadForm(
                    model: model,
                    textFieldAccessibilityID: AccessibilityIDs.emptyStateGitHubURLField,
                    loadButtonAccessibilityID: AccessibilityIDs.emptyStateGitHubURLLoadButton,
                    errorAccessibilityID: AccessibilityIDs.emptyStateGitHubURLErrorMessage
                )
                .padding(.top, 8)
                .frame(maxWidth: 420)
            }
            if let secondaryMessage {
                Text(secondaryMessage)
                    .font(ViewerFont.footnote(scale: model.fontScale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel(Text(secondaryMessage))
                    .accessibilityIdentifier(AccessibilityIDs.emptyStateCommandLineToolMessage)
            }
            if let secondaryButtonTitle, let secondaryAction {
                Button(secondaryButtonTitle) {
                    secondaryAction()
                }
                .accessibilityIdentifier(AccessibilityIDs.emptyStateCommandLineToolButton)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(24)
    }

    private var commandLineToolInstallExplanation: String {
        #if os(macOS)
        MacCommandLineToolManager.installExplanation
        #else
        ""
        #endif
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

    private var fontSizeControls: some View {
        ControlGroup {
            Button(action: model.decreaseFontSize) {
                Image(systemName: "textformat.size.smaller")
            }
            .disabled(!model.canDecreaseFontSize)
            .accessibilityIdentifier(AccessibilityIDs.decreaseFontSizeButton)
            .help("Decrease Font Size")

            Button(action: model.increaseFontSize) {
                Image(systemName: "textformat.size.larger")
            }
            .disabled(!model.canIncreaseFontSize)
            .accessibilityIdentifier(AccessibilityIDs.increaseFontSizeButton)
            .help("Increase Font Size")
        }
        .labelStyle(.iconOnly)
    }

    private var showsFilesButton: Bool {
        isCompactPhoneLayout && !compactShowsSidebar && model.selectedPath != nil
    }

    private func showSidebar() {
        if isCompactPhoneLayout {
            compactShowsSidebar = true
            return
        }
        guard horizontalSizeClass == .compact else { return }
        columnVisibility = .all
    }

    private func showDetailIfNeeded() {
        if isCompactPhoneLayout {
            guard model.shouldPreferDetailInCompactNavigation else { return }
            compactShowsSidebar = false
            return
        }
        guard horizontalSizeClass == .compact else { return }
        guard model.shouldPreferDetailInCompactNavigation else { return }
        columnVisibility = .detailOnly
    }

    private func handleUITestMediaPreviewIfNeeded() {
        guard model.launchOptions.uiTestMode else { return }
        guard !hasConsumedUITestMediaPreview else { return }
        guard let previewURL = model.launchOptions.uiTestOpenLinkedMediaURL else { return }
        guard model.selectedPath != nil else { return }
        hasConsumedUITestMediaPreview = true
        handleDocumentLink(previewURL)
    }

    private func handleDocumentLink(_ url: URL) {
        switch model.resolvedDocumentLinkAction(for: url) {
        case let .markdown(targetPath):
            model.openFile(targetPath)
            showDetailIfNeeded()
        case let .media(target):
            mediaPreviewTarget = target
        case let .external(targetURL):
            openURL(targetURL)
        }
    }

    @ViewBuilder
    private func mediaPreview(for target: AppModel.MediaLinkTarget) -> some View {
        LinkedMediaPreviewView(
            target: target,
            onClose: { mediaPreviewTarget = nil },
            onOpenInBrowser: { openInBrowser(target.originalURL) }
        )
    }

    private func openInBrowser(_ url: URL) {
        #if os(macOS)
        if let browserApplicationURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://example.com")!) {
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: browserApplicationURL,
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
            return
        }
        #endif
        openURL(url)
    }

    private func updatePreferredColumnVisibility() {
        if isCompactPhoneLayout {
            compactShowsSidebar = !model.shouldPreferDetailInCompactNavigation
            return
        }
        guard horizontalSizeClass == .compact else {
            columnVisibility = .automatic
            return
        }
        guard model.shouldPreferDetailInCompactNavigation else { return }
        columnVisibility = .detailOnly
    }
}

private struct DocumentBlockScrollView: View {
    let blocks: [MarkdownBlock]
    let workspaceRootURL: URL?
    let fontScale: CGFloat
    let syntaxTheme: SyntaxHighlightTheme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(blocks) { block in
                    MarkdownBlockView(
                        block: block,
                        workspaceRootURL: workspaceRootURL,
                        fontScale: fontScale,
                        syntaxTheme: syntaxTheme
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .textSelection(.enabled)
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
                .font(ViewerFont.body(scale: 1))
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
    let fontScale: CGFloat
    let syntaxTheme: SyntaxHighlightTheme

    var body: some View {
        switch block.kind {
        case .heading:
            Text(MarkdownRenderer.attributedText(for: block))
                .font(headingFont(for: block.level ?? 1, scale: fontScale))
                .fontWeight(.semibold)
                .linkHoverCursor(MarkdownRenderer.attributedText(for: block))
        case .paragraph:
            Text(MarkdownRenderer.attributedText(for: block))
                .font(ViewerFont.body(scale: fontScale))
                .linkHoverCursor(MarkdownRenderer.attributedText(for: block))
        case .unorderedListItem:
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    if block.isTaskItem {
                        taskListLabel
                    } else {
                        Text(listMarker)
                            .font(ViewerFont.body(scale: fontScale))
                        Text(MarkdownRenderer.attributedText(for: block))
                            .font(ViewerFont.body(scale: fontScale))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .linkHoverCursor(MarkdownRenderer.attributedText(for: block))
                    }
                }
                if !block.children.isEmpty {
                    childBlocks
                }
            }
            .padding(.leading, CGFloat(block.indentLevel) * 18)
        case .orderedListItem:
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    if block.isTaskItem {
                        taskListLabel
                    } else {
                        Text(listMarker)
                            .font(ViewerFont.monospacedBody(scale: fontScale))
                            .monospacedDigit()
                        Text(MarkdownRenderer.attributedText(for: block))
                            .font(ViewerFont.body(scale: fontScale))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .linkHoverCursor(MarkdownRenderer.attributedText(for: block))
                    }
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
                    .font(ViewerFont.body(scale: fontScale))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .linkHoverCursor(MarkdownRenderer.attributedText(for: block))
            }
        case .codeBlock:
            ScrollView(.horizontal, showsIndicators: false) {
                if let codeBlock = block.codeBlock,
                   let highlighted = CodeBlockSyntaxHighlighter.highlightedAttributedText(
                    for: codeBlock,
                    theme: syntaxTheme,
                    fontScale: fontScale
                   ) {
                    Text(highlighted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    Text(verbatim: block.sourceText)
                        .font(ViewerFont.monospacedBody(scale: fontScale))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
            }
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .table:
            if let table = block.table {
                ScrollView(.horizontal, showsIndicators: true) {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                        GridRow {
                                ForEach(Array(table.header.enumerated()), id: \.offset) { column, cell in
                                Text(MarkdownRenderer.attributedText(for: cell))
                                    .font(ViewerFont.body(scale: fontScale))
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity, alignment: alignment(for: table.alignments[column]))
                                    .linkHoverCursor(MarkdownRenderer.attributedText(for: cell))
                            }
                        }
                        Divider()
                            .gridCellColumns(table.header.count)
                        ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                            GridRow {
                                    ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                                    Text(MarkdownRenderer.attributedText(for: cell))
                                        .font(ViewerFont.body(scale: fontScale))
                                        .frame(maxWidth: .infinity, alignment: alignment(for: table.alignments[column]))
                                        .linkHoverCursor(MarkdownRenderer.attributedText(for: cell))
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
                    workspaceRootURL: workspaceRootURL,
                    fontScale: fontScale
                )
            }
        case .video:
            if let video = block.video {
                InlineVideoBlockView(
                    video: video,
                    blockID: block.id,
                    workspaceRootURL: workspaceRootURL,
                    fontScale: fontScale
                )
            }
        case .rawHTML:
            Text(verbatim: block.sourceText)
                .font(ViewerFont.monospacedBody(scale: fontScale))
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

    private func headingFont(for level: Int, scale: CGFloat) -> Font {
        switch level {
        case 1:
            return ViewerFont.scaledSystem(size: 30, weight: .semibold, scale: scale)
        case 2:
            return ViewerFont.scaledSystem(size: 24, weight: .semibold, scale: scale)
        case 3:
            return ViewerFont.scaledSystem(size: 20, weight: .semibold, scale: scale)
        default:
            return ViewerFont.headline(scale: scale)
        }
    }

    private var listMarker: String {
        if block.kind == .orderedListItem {
            return "\(block.listItemIndex ?? 1)."
        }
        return "\u{2022}"
    }

    @ViewBuilder
    private var taskListLabel: some View {
        #if os(macOS)
        Toggle(isOn: .constant(block.isTaskCompleted == true)) {
            Text(MarkdownRenderer.attributedText(for: block))
                .font(ViewerFont.body(scale: fontScale))
                .frame(maxWidth: .infinity, alignment: .leading)
                .linkHoverCursor(MarkdownRenderer.attributedText(for: block))
        }
        .toggleStyle(.checkbox)
        .disabled(true)
        #elseif os(iOS)
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: block.isTaskCompleted == true ? "checkmark.square.fill" : "square")
                .font(ViewerFont.body(scale: fontScale))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(MarkdownRenderer.attributedText(for: block))
                .font(ViewerFont.body(scale: fontScale))
                .frame(maxWidth: .infinity, alignment: .leading)
                .linkHoverCursor(MarkdownRenderer.attributedText(for: block))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(MarkdownRenderer.attributedText(for: block)))
        .accessibilityValue(block.isTaskCompleted == true ? "Checked" : "Unchecked")
        #endif
    }

    @ViewBuilder
    private var childBlocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(block.children) { child in
                MarkdownBlockView(
                    block: child,
                    workspaceRootURL: workspaceRootURL,
                    fontScale: fontScale,
                    syntaxTheme: syntaxTheme
                )
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

#if os(macOS)
private struct LinkHoverCursorModifier: ViewModifier {
    let hasLink: Bool
    @State private var isHovering = false

    func body(content: Content) -> some View {
        guard hasLink else { return AnyView(content) }

        return AnyView(
            content
                .onHover { hovering in
                    guard hovering != isHovering else { return }
                    isHovering = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        )
    }
}

private extension View {
    func linkHoverCursor(_ attributedText: AttributedString) -> some View {
        modifier(LinkHoverCursorModifier(hasLink: attributedText.runs.contains { $0.link != nil }))
    }
}
#else
private extension View {
    func linkHoverCursor(_ attributedText: AttributedString) -> some View {
        self
    }
}
#endif

private struct ImageBlockView: View {
    let image: MarkdownImage
    let isAnimated: Bool
    let blockID: String
    let workspaceRootURL: URL?
    let fontScale: CGFloat
    @State private var downloadedRemoteURL: URL?
    @State private var remoteLoadError: String?

    private var displayURL: URL? {
        downloadedRemoteURL ?? image.resolvedURL
    }

    private var imageLoadError: String? {
        if let loadError = image.loadError ?? remoteLoadError {
            return loadError
        }
        return mediaLoadError(
            resolvedURL: displayURL,
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
            if let resolvedURL = displayURL, imageLoadError == nil {
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
                                .font(ViewerFont.scaledSystem(size: 36, weight: .medium, scale: fontScale))
                                .foregroundStyle(.secondary)
                            if let imageLoadError {
                                Text(imageLoadError)
                                    .font(ViewerFont.caption(scale: fontScale))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(primaryLabel)
                    .font(ViewerFont.headline(scale: fontScale))
                    .accessibilityIdentifier(AccessibilityIDs.imageBlock(blockID))
                Text(image.sourceURL)
                    .font(ViewerFont.caption(scale: fontScale))
                    .foregroundStyle(.secondary)
                if let title = image.title, !title.isEmpty {
                    Text(title)
                        .font(ViewerFont.caption(scale: fontScale))
                        .foregroundStyle(.secondary)
                }
                if let imageLoadError {
                    Text(imageLoadError)
                        .font(ViewerFont.caption(scale: fontScale))
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
        .task(id: image.sourceURL) {
            await loadRemoteImageIfNeeded()
        }
    }

    private var primaryLabel: String {
        if image.altText.isEmpty {
            return isAnimated ? "Animated image" : "Image"
        }
        return image.altText
    }

    private func loadRemoteImageIfNeeded() async {
        guard image.sourceKind == .remote else { return }
        guard image.resolvedURL == nil else { return }
        guard image.loadError == nil else { return }
        guard let sourceURL = URL(string: image.sourceURL) else {
            await MainActor.run {
                remoteLoadError = "Image failed to load.\nsource: \(image.sourceURL)"
            }
            return
        }

        do {
            let cachedURL = try await fetchRemoteImageToCache(remoteURL: sourceURL)
            await MainActor.run {
                downloadedRemoteURL = cachedURL
                remoteLoadError = nil
            }
        } catch {
            await MainActor.run {
                remoteLoadError = "Image failed to load: \(error.localizedDescription)\nsource: \(image.sourceURL)"
            }
        }
    }
}

private struct InlineVideoBlockView: View {
    let video: MarkdownVideo
    let blockID: String
    let workspaceRootURL: URL?
    let fontScale: CGFloat

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
                            .font(ViewerFont.scaledSystem(size: 36, weight: .medium, scale: fontScale))
                            .foregroundStyle(.white.opacity(0.85))
                        if let playerError {
                            Text(playerError)
                                .font(ViewerFont.caption(scale: fontScale))
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
                            .font(ViewerFont.headline(scale: fontScale))
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
                    .font(ViewerFont.headline(scale: fontScale))
                    .accessibilityIdentifier(AccessibilityIDs.videoBlock(blockID))
                Text(video.sourceURL)
                    .font(ViewerFont.caption(scale: fontScale))
                    .foregroundStyle(.secondary)
                if let title = video.title, !title.isEmpty {
                    Text(title)
                        .font(ViewerFont.caption(scale: fontScale))
                        .foregroundStyle(.secondary)
                }
                if let playerError {
                    Text(playerError)
                        .font(ViewerFont.caption(scale: fontScale))
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
        if let loadError = video.loadError {
            playerError = loadError
            return
        }
        guard let resolvedURL = video.resolvedURL else {
            playerError = unresolvedMediaError(sourceURL: video.sourceURL, kindLabel: "Video")
            return
        }
        if resolvedURL.isFileURL {
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
                        resolved: \(resolvedLocationDescription(resolvedURL))
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
                    resolved: \(resolvedLocationDescription(resolvedURL))
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

private struct LinkedMediaPreviewView: View {
    let target: AppModel.MediaLinkTarget
    let onClose: () -> Void
    let onOpenInBrowser: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Text(target.kind == .image ? "Image Preview" : "Video Preview")
                    .font(.headline)
                Spacer()
                Button("Open in Browser", action: onOpenInBrowser)
                    .accessibilityIdentifier(AccessibilityIDs.mediaPreviewOpenInBrowserButton)
                Button("Close", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier(AccessibilityIDs.mediaPreviewCloseButton)
            }

            if target.kind == .image {
                ImageBlockView(
                    image: MarkdownImage(
                        altText: "Linked image",
                        sourceURL: target.originalURL.absoluteString,
                        title: nil,
                        sourceKind: target.originalURL.isFileURL ? .local : .remote,
                        resolvedURL: target.originalURL.isFileURL ? target.resolvedURL : nil,
                        loadError: nil
                    ),
                    isAnimated: isAnimatedImagePreviewCandidate(target.originalURL),
                    blockID: "media-preview-image",
                    workspaceRootURL: nil,
                    fontScale: 1
                )
            } else {
                InlineVideoBlockView(
                    video: MarkdownVideo(
                        altText: "Linked video",
                        sourceURL: target.originalURL.absoluteString,
                        title: nil,
                        sourceKind: target.originalURL.isFileURL ? .local : .remote,
                        resolvedURL: target.resolvedURL,
                        loadError: nil
                    ),
                    blockID: "media-preview-video",
                    workspaceRootURL: nil,
                    fontScale: 1
                )
            }
        }
        .padding(20)
        .frame(minWidth: 420, idealWidth: 560, maxWidth: 680)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIDs.mediaPreviewContainer)
    }

    private func isAnimatedImagePreviewCandidate(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "gif"
    }
}

private func fetchRemoteImageToCache(remoteURL: URL) async throws -> URL {
    let cacheDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("qmv-remote-media-preview-cache", isDirectory: true)
    try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

    let baseName = Data(remoteURL.absoluteString.utf8)
        .base64EncodedString()
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "=", with: "")
    let fileExtension = remoteURL.pathExtension.isEmpty ? "bin" : remoteURL.pathExtension
    let destinationURL = cacheDirectory.appendingPathComponent("\(baseName).\(fileExtension)")

    if FileManager.default.fileExists(atPath: destinationURL.path) {
        return destinationURL
    }

    let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
    if let httpResponse = response as? HTTPURLResponse,
       !(200...299).contains(httpResponse.statusCode) {
        throw PreviewRemoteMediaError.httpStatus(httpResponse.statusCode)
    }

    if FileManager.default.fileExists(atPath: destinationURL.path) {
        try? FileManager.default.removeItem(at: destinationURL)
    }
    try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
    return destinationURL
}

private enum PreviewRemoteMediaError: LocalizedError {
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case let .httpStatus(statusCode):
            return "HTTP \(statusCode)"
        }
    }
}

private func resolvedLocationDescription(_ url: URL) -> String {
    url.isFileURL ? url.path : url.absoluteString
}

private enum ViewerFont {
    static func body(scale: CGFloat) -> Font {
        Font(platformFont(forTextStyle: .body, scale: scale))
    }

    static func headline(scale: CGFloat) -> Font {
        Font(platformFont(forTextStyle: .headline, scale: scale))
    }

    static func title3(scale: CGFloat) -> Font {
        Font(platformFont(forTextStyle: .title3, scale: scale))
    }

    static func caption(scale: CGFloat) -> Font {
        Font(platformFont(forTextStyle: .caption1, scale: scale))
    }

    static func footnote(scale: CGFloat) -> Font {
        Font(platformFont(forTextStyle: .footnote, scale: scale))
    }

    static func monospacedBody(scale: CGFloat) -> Font {
        let pointSize = platformFont(forTextStyle: .body, scale: scale).pointSize
        #if os(macOS)
        return Font(NSFont.monospacedSystemFont(ofSize: pointSize, weight: .regular))
        #elseif os(iOS)
        return Font(UIFont.monospacedSystemFont(ofSize: pointSize, weight: .regular))
        #endif
    }

    static func scaledSystem(size: CGFloat, weight: Font.Weight, scale: CGFloat) -> Font {
        .system(size: size * scale, weight: weight, design: .default)
    }

    private static func platformFont(forTextStyle textStyle: FontTextStyle, scale: CGFloat) -> PlatformFont {
        scaled(basePlatformFont(forTextStyle: textStyle), by: scale)
    }

    private static func scaled(_ font: PlatformFont, by scale: CGFloat) -> PlatformFont {
        font.withSize(font.pointSize * scale)
    }

    private static func basePlatformFont(forTextStyle textStyle: FontTextStyle) -> PlatformFont {
        PlatformFont.preferredFont(forTextStyle: textStyle)
    }
}

#if os(macOS)
private typealias PlatformFont = NSFont
private typealias FontTextStyle = NSFont.TextStyle
#elseif os(iOS)
private typealias PlatformFont = UIFont
private typealias FontTextStyle = UIFont.TextStyle
#endif

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
    resolved: \(resolvedLocationDescription(resolvedURL))
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
    resolved: \(resolvedLocationDescription(resolvedURL))
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

struct GitHubURLLoadForm: View {
    @ObservedObject var model: AppModel
    let textFieldAccessibilityID: String
    let loadButtonAccessibilityID: String
    let errorAccessibilityID: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Open a public GitHub repository or tree URL.")
                .font(ViewerFont.body(scale: model.fontScale))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            #if os(macOS)
            TextField("https://github.com/owner/repo/tree/ref/path", text: $model.githubURLInput)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(textFieldAccessibilityID)
                .onSubmit {
                    model.submitGitHubURLFromInput()
                }
            #else
            TextField("https://github.com/owner/repo/tree/ref/path", text: $model.githubURLInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .accessibilityIdentifier(textFieldAccessibilityID)
                .onSubmit {
                    model.submitGitHubURLFromInput()
                }
            #endif

            HStack(spacing: 10) {
                Button("Load") {
                    model.submitGitHubURLFromInput()
                }
                .disabled(model.githubURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isLoadingWorkspace)
                .accessibilityIdentifier(loadButtonAccessibilityID)

                if model.isLoadingWorkspace {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if let errorMessage = model.githubURLLoadErrorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier(errorAccessibilityID)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
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
