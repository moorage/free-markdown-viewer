import AVKit
import SwiftUI

#if os(macOS)
import AppKit
import Security
#elseif os(iOS)
import UIKit
#endif

private enum SidebarPane: String, Hashable {
    case files
    case search
}

struct ViewerShellView: View {
    @ObservedObject var model: AppModel
    let onOpenFolder: (() -> Void)?
    let onOpenGitHubURLPrompt: (() -> Void)?
    let onPrintSelectedDocument: (() -> Void)?
    let onPrintAllDocuments: (() -> Void)?
    let onCancelPrintPreparation: (() -> Void)?
    let onInstallCommandLineTool: (() -> Void)?
    let shouldShowCommandLineToolPrompt: Bool
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @State private var mediaPreviewTarget: AppModel.MediaLinkTarget?
    @State private var mermaidPreviewTarget: MermaidDiagramPreviewTarget?
    @State private var isPresentingIgnorePatterns = false
    @State private var isOutlinePresented = false
    @State private var documentScrollTargetID: String?
    @State private var activeOutlineBlockID: String?
    @State private var outlinePaneWidth = OutlinePaneMetrics.defaultWidth
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var compactShowsSidebar = true
    @State private var sidebarPane: SidebarPane = .files
    @State private var sidebarFilterText = ""
    @State private var sidebarTreeSnapshot = SidebarFileTree.Snapshot(files: [])
    @State private var visibleSidebarRowsCache: [SidebarFileTree.Row] = []
    @State private var visibleSidebarRowIDsCache: Set<String> = []
    @State private var expandedSidebarFolderIDs: Set<String> = []
    @State private var activeSidebarRowID: String?
    @State private var hasConsumedUITestMediaPreview = false
    @State private var hasAppliedUITestPresentationOptions = false
    #if os(macOS)
    @FocusState private var sidebarFocused: Bool
    @FocusState private var sidebarFilterFocused: Bool
    @FocusState private var searchFieldFocused: Bool
    @State private var searchCommandHandlerID = UUID()
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
        .onAppear(perform: applyUITestPresentationOptionsIfNeeded)
        .onChange(of: model.selectedPath) { _ in
            handleUITestMediaPreviewIfNeeded()
            applyUITestPresentationOptionsIfNeeded()
        }
        .onChange(of: model.files) { _ in
            applyUITestPresentationOptionsIfNeeded()
        }
        #if os(macOS)
        .onAppear(perform: installMacSearchCommandHandler)
        .onDisappear(perform: uninstallMacSearchCommandHandler)
        #endif
        .onChange(of: model.outlineItems) { outlineItems in
            if outlineItems.isEmpty {
                isOutlinePresented = false
                activeOutlineBlockID = nil
            } else if activeOutlineBlockID.map({ blockID in !outlineItems.contains { $0.blockID == blockID } }) ?? true {
                activeOutlineBlockID = outlineItems.first?.blockID
            }
            applyUITestPresentationOptionsIfNeeded()
        }
        .sheet(item: sheetMediaPreviewBinding) { target in
            mediaPreview(for: target)
        }
        .sheet(item: sheetMermaidPreviewBinding) { target in
            mermaidPreview(for: target)
        }
        .sheet(isPresented: $isPresentingIgnorePatterns) {
            WorkspaceIgnorePatternsSheet(model: model)
        }
        .popover(item: popoverMediaPreviewBinding) { target in
            mediaPreview(for: target)
        }
        .popover(item: popoverMermaidPreviewBinding) { target in
            mermaidPreview(for: target)
        }
        #if os(macOS)
        .focusedSceneValue(\.searchCurrentDocumentAction, SearchCurrentDocumentAction(handler: {
            activateSearchSidebar(scope: .currentDocument)
        }))
        .focusedSceneValue(\.searchAllDocumentsAction, SearchAllDocumentsAction(handler: {
            activateSearchSidebar(scope: .allDocuments)
        }))
        .focusedSceneValue(\.selectNextSearchResultAction, SelectNextSearchResultAction(handler: model.selectNextSearchResult))
        .toolbar {
            ToolbarItem(placement: .navigation) {
                macNavigationControls
            }
            if model.shouldShowTabularControls {
                ToolbarItem(placement: .automatic) {
                    tabularControls
                }
            }
            if canShowOutline {
                ToolbarItem(placement: .automatic) {
                    outlineButton
                }
            }
            ToolbarItem(placement: .automatic) {
                fontSizeControls
            }
            if let macPrintControl {
                ToolbarItem(placement: .automatic) {
                    macPrintControl
                }
            }
            ToolbarItem(placement: .primaryAction) {
                ignorePatternsButton
            }
            ToolbarItem(placement: .primaryAction) {
                macRevealInFinderButton
            }
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                Text(model.windowTitle)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(model.windowTitle)
                    .accessibilityIdentifier(AccessibilityIDs.title)
                if model.launchOptions.uiTestMode {
                    let printScope = model.lastPrintRequestScope ?? "none"
                    Text(printScope)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(printScope)
                        .accessibilityIdentifier(AccessibilityIDs.printRequestScope)
                    let printStatus = model.lastPrintRequestStatus ?? "idle"
                    Text(printStatus)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(printStatus)
                        .accessibilityIdentifier(AccessibilityIDs.printRequestStatus)
                    Text(model.searchQuery)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(model.searchQuery)
                        .accessibilityIdentifier(AccessibilityIDs.searchQueryState)
                    let resultCount = "\(model.searchResults.count)"
                    Text(resultCount)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(resultCount)
                        .accessibilityIdentifier(AccessibilityIDs.searchResultCountState)
                }
            }
            .accessibilityElement(children: .contain)
            .opacity(0.01)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topTrailing) {
            if model.launchOptions.uiTestMode {
                HStack(spacing: 4) {
                    if let onPrintSelectedDocument {
                        Button("Print") {
                            onPrintSelectedDocument()
                        }
                        .accessibilityIdentifier(AccessibilityIDs.uiTestPrintSelectedAction)
                    }
                    if let onPrintAllDocuments {
                        Button("Print All") {
                            onPrintAllDocuments()
                        }
                        .accessibilityIdentifier(AccessibilityIDs.uiTestPrintAllAction)
                    }
                }
                .padding(6)
                .background(.thinMaterial)
                .opacity(0)
            }
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

    private func applyUITestPresentationOptionsIfNeeded() {
        let launchOptions = model.launchOptions
        guard launchOptions.uiTestMode, !hasAppliedUITestPresentationOptions else { return }

        let trimmedSearchQuery = launchOptions.uiTestSearchQuery?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSearchRequest = trimmedSearchQuery.map { !$0.isEmpty } ?? false
        guard launchOptions.uiTestShowSidebar || launchOptions.uiTestShowOutline || hasSearchRequest else {
            hasAppliedUITestPresentationOptions = true
            return
        }

        var appliedAllRequestedOptions = true
        if launchOptions.uiTestShowSidebar {
            if model.files.isEmpty {
                appliedAllRequestedOptions = false
            } else {
                sidebarPane = .files
                showSidebarForUITestPresentation()
            }
        }

        if launchOptions.uiTestShowOutline {
            if model.outlineItems.isEmpty {
                appliedAllRequestedOptions = false
            } else {
                isOutlinePresented = true
            }
        }

        if let searchQuery = trimmedSearchQuery, !searchQuery.isEmpty {
            if model.files.isEmpty {
                appliedAllRequestedOptions = false
            } else {
                let scope = launchOptions.uiTestSearchScope
                    .flatMap(DocumentSearchScope.init(rawValue:)) ?? .currentDocument
                model.activateSearch(scope: scope)
                model.updateSearchQuery(searchQuery)
                sidebarPane = .search
                showSidebarForUITestPresentation()
                #if os(macOS)
                searchFieldFocused = true
                #endif
            }
        }

        if appliedAllRequestedOptions {
            hasAppliedUITestPresentationOptions = true
        }
    }

    private func showSidebarForUITestPresentation() {
        if isCompactPhoneLayout {
            compactShowsSidebar = true
        } else {
            columnVisibility = .all
        }
    }

    #if os(macOS)
    private func installMacSearchCommandHandler() {
        MacSearchCommandDispatcher.setHandler(id: searchCommandHandlerID, handleMacSearchCommand(_:))
    }

    private func uninstallMacSearchCommandHandler() {
        MacSearchCommandDispatcher.clearHandler(id: searchCommandHandlerID)
    }

    private func handleMacSearchCommand(_ command: MacSearchCommand) {
        switch command {
        case .currentDocument:
            activateSearchSidebar(scope: .currentDocument)
        case .allDocuments:
            activateSearchSidebar(scope: .allDocuments)
        case .nextResult:
            model.selectNextSearchResult()
        }
    }

    private func activateSearchSidebar(scope: DocumentSearchScope) {
        model.activateSearch(scope: scope)
        sidebarPane = .search
        searchFieldFocused = true
    }

    #endif

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

    private var sheetMermaidPreviewBinding: Binding<MermaidDiagramPreviewTarget?> {
        Binding(
            get: { usesSheetPreview ? mermaidPreviewTarget : nil },
            set: { newValue in
                if usesSheetPreview {
                    mermaidPreviewTarget = newValue
                } else if newValue == nil {
                    mermaidPreviewTarget = nil
                }
            }
        )
    }

    private var popoverMermaidPreviewBinding: Binding<MermaidDiagramPreviewTarget?> {
        Binding(
            get: { usesSheetPreview ? nil : mermaidPreviewTarget },
            set: { newValue in
                if usesSheetPreview {
                    if newValue == nil {
                        mermaidPreviewTarget = nil
                    }
                } else {
                    mermaidPreviewTarget = newValue
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
            sidebarPanePicker

            if sidebarPane == .files {
                sidebarFilterField

                List(visibleSidebarRows) { row in
                    sidebarRow(for: row)
                }
                .accessibilityIdentifier(AccessibilityIDs.sidebarList)
            } else {
                searchSidebarContent
            }
        }
        #if os(macOS)
        .focusable(sidebarPane == .files)
        .focused($sidebarFocused)
        #endif
        .listStyle(.sidebar)
        #if os(macOS)
        .onMoveCommand(perform: handleSidebarMove)
        .background(
            MacSidebarKeyEventBridge(
                isEnabled: sidebarPane == .files && (sidebarFocused || sidebarFilterFocused),
                onMoveUp: { selectAdjacentSidebarRow(offset: -1) },
                onMoveDown: { selectAdjacentSidebarRow(offset: 1) },
                onMoveLeft: collapseActiveSidebarRow,
                onMoveRight: expandActiveSidebarRow,
                onSearchDocument: {
                    activateSearchSidebar(scope: .currentDocument)
                },
                onSearchAllDocuments: {
                    activateSearchSidebar(scope: .allDocuments)
                },
                onNextSearchResult: {
                    model.selectNextSearchResult()
                },
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
        .onChange(of: model.selectedPath) { _ in
            activeSidebarRowID = model.selectedPath.map(SidebarFileTree.fileRowID(for:))
            expandSelectedSidebarAncestors()
        }
        .onChange(of: model.files) { _ in
            rebuildSidebarTreeSnapshot()
        }
        .onChange(of: sidebarFilterText) { _ in
            rebuildSidebarTreeSnapshot()
        }
        .onChange(of: expandedSidebarFolderIDs) { _ in
            refreshVisibleSidebarRows()
        }
        .onChange(of: model.searchActivationCounter) { _ in
            sidebarPane = .search
            #if os(macOS)
            searchFieldFocused = true
            #endif
        }
        .onAppear {
            rebuildSidebarTreeSnapshot()
            activeSidebarRowID = model.selectedPath.map(SidebarFileTree.fileRowID(for:))
            expandSelectedSidebarAncestors()
        }
    }

    private var sidebarPanePicker: some View {
        HStack(spacing: 6) {
            sidebarPaneTab(
                pane: .files,
                title: "Files",
                systemImage: "folder",
                accessibilityID: AccessibilityIDs.sidebarFilesTab
            )
            sidebarPaneTab(
                pane: .search,
                title: "Search",
                systemImage: "magnifyingglass",
                accessibilityID: AccessibilityIDs.sidebarSearchTab
            )
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .accessibilityLabel("Sidebar Mode")
    }

    private func sidebarPaneTab(
        pane: SidebarPane,
        title: String,
        systemImage: String,
        accessibilityID: String
    ) -> some View {
        let isSelected = sidebarPane == pane
        return Button {
            sidebarPane = pane
            #if os(macOS)
            if pane == .search {
                searchFieldFocused = true
            } else {
                sidebarFocused = true
            }
            #endif
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
                Text(title)
                    .font(ViewerFont.body(scale: 0.92))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.28) : Color.secondary.opacity(0.14), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "selected" : "")
        .accessibilityIdentifier(accessibilityID)
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

    private var searchSidebarContent: some View {
        VStack(spacing: 0) {
            searchField
            searchScopePicker

            if model.isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching...")
                        .font(ViewerFont.body(scale: 1))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            List(model.searchResults) { result in
                Button {
                    model.selectSearchResult(result)
                    showDetailIfNeeded()
                } label: {
                    SearchResultRow(
                        result: result,
                        isSelected: result.id == model.selectedSearchResultID
                    )
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                .listRowBackground(sidebarRowBackground(isSelected: result.id == model.selectedSearchResultID))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(result.fileName) L\(result.lineNumber) \(result.snippet)")
                .accessibilityIdentifier(AccessibilityIDs.searchResultFile(result.fileName))
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            #if os(macOS)
            MacLiveSearchField(
                placeholder: "Search",
                text: searchQueryBinding,
                accessibilityIdentifier: AccessibilityIDs.searchField,
                focusTrigger: model.searchActivationCounter
            )
            .frame(minWidth: 80, maxWidth: .infinity, minHeight: 24)
            #else
            TextField("Search", text: searchQueryBinding)
                .accessibilityIdentifier(AccessibilityIDs.searchField)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
            #endif
            Button {
                model.selectNextSearchResult()
            } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.plain)
            .disabled(model.searchResults.isEmpty)
            .accessibilityLabel("Next Search Result")
            .accessibilityIdentifier(AccessibilityIDs.searchNextButton)
        }
        #if os(macOS)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    private var searchScopePicker: some View {
        Picker("Search Scope", selection: searchScopeBinding) {
            ForEach(DocumentSearchScope.allCases, id: \.self) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    private var searchQueryBinding: Binding<String> {
        Binding(
            get: { model.searchQuery },
            set: { model.updateSearchQuery($0) }
        )
    }

    private var searchScopeBinding: Binding<DocumentSearchScope> {
        Binding(
            get: { model.searchScope },
            set: { model.activateSearch(scope: $0) }
        )
    }

    private var visibleSidebarRows: [SidebarFileTree.Row] {
        visibleSidebarRowsCache
    }

    private func rebuildSidebarTreeSnapshot() {
        sidebarTreeSnapshot = SidebarFileTree.Snapshot(files: filteredFiles)
        refreshVisibleSidebarRows()
    }

    private func refreshVisibleSidebarRows() {
        visibleSidebarRowsCache = sidebarTreeSnapshot.visibleRows(
            expandedFolderIDs: expandedSidebarFolderIDs,
            expandsAllFolders: sidebarFilterText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        )
        visibleSidebarRowIDsCache = Set(visibleSidebarRowsCache.map(\.id))
    }

    private var resolvedActiveSidebarRowID: String? {
        if let activeSidebarRowID,
           visibleSidebarRowIDsCache.contains(activeSidebarRowID) {
            return activeSidebarRowID
        }
        if let selectedPath = model.selectedPath {
            let selectedRowID = SidebarFileTree.fileRowID(for: selectedPath)
            if visibleSidebarRowIDsCache.contains(selectedRowID) {
                return selectedRowID
            }
        }
        return visibleSidebarRows.first?.id
    }

    @ViewBuilder
    private func sidebarRow(for row: SidebarFileTree.Row) -> some View {
        switch row {
        case let .folder(folder):
            sidebarFolderRow(for: folder)
        case let .file(file):
            sidebarFileRow(for: file)
        }
    }

    private func sidebarFolderRow(for folder: SidebarFileTree.FolderRow) -> some View {
        let isFocused = resolvedActiveSidebarRowID == folder.id
        return Button {
            #if os(macOS)
            sidebarFocused = true
            #endif
            activeSidebarRowID = folder.id
            toggleSidebarFolder(folder)
        } label: {
            SidebarFolderRow(folder: folder, isFocused: isFocused)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
        .listRowBackground(sidebarFocusedRowBackground(isFocused: isFocused))
        .accessibilityIdentifier(AccessibilityIDs.sidebarFolderNode(folder.path))
    }

    private func sidebarFileRow(for file: SidebarFileTree.FileRow) -> some View {
        let isSelected = model.selectedPath == file.file.path || resolvedActiveSidebarRowID == file.id
        return Button {
            #if os(macOS)
            sidebarFocused = true
            #endif
            activeSidebarRowID = file.id
            model.openFile(file.file.path)
            showDetailIfNeeded()
        } label: {
            SidebarFileRow(file: file.file, depth: file.depth, isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
        .listRowBackground(sidebarRowBackground(isSelected: isSelected))
        .accessibilityIdentifier(AccessibilityIDs.sidebarNode(file.file.path.rawValue))
    }

    #if os(macOS)
    private func handleSidebarMove(_ direction: MoveCommandDirection) {
        #if os(macOS)
        guard sidebarFocused else { return }
        #endif

        switch direction {
        case .up:
            selectAdjacentSidebarRow(offset: -1)
        case .down:
            selectAdjacentSidebarRow(offset: 1)
        case .left:
            collapseActiveSidebarRow()
        case .right:
            expandActiveSidebarRow()
        default:
            break
        }
    }
    #endif

    private func selectAdjacentSidebarRow(offset: Int) {
        guard let targetID = SidebarFileTree.adjacentRowID(
            from: resolvedActiveSidebarRowID,
            within: visibleSidebarRows,
            offset: offset
        ),
        let row = SidebarFileTree.row(withID: targetID, within: visibleSidebarRows) else { return }
        selectSidebarRow(row, opensFiles: true)
    }

    private func expandActiveSidebarRow() {
        guard let row = SidebarFileTree.row(withID: resolvedActiveSidebarRowID, within: visibleSidebarRows) else { return }
        switch row {
        case let .folder(folder):
            if folder.isExpanded {
                selectFirstChild(after: folder)
            } else {
                expandedSidebarFolderIDs.insert(folder.path)
                refreshVisibleSidebarRows()
                activeSidebarRowID = folder.id
            }
        case .file:
            break
        }
    }

    private func collapseActiveSidebarRow() {
        guard let row = SidebarFileTree.row(withID: resolvedActiveSidebarRowID, within: visibleSidebarRows),
              let rowIndex = visibleSidebarRows.firstIndex(of: row) else { return }
        switch row {
        case let .folder(folder):
            if folder.isExpanded {
                expandedSidebarFolderIDs.remove(folder.path)
                refreshVisibleSidebarRows()
                activeSidebarRowID = folder.id
            } else {
                selectParentFolder(before: rowIndex, depth: folder.depth)
            }
        case let .file(file):
            selectParentFolder(before: rowIndex, depth: file.depth)
        }
    }

    private func toggleSidebarFolder(_ folder: SidebarFileTree.FolderRow) {
        if folder.isExpanded {
            expandedSidebarFolderIDs.remove(folder.path)
        } else {
            expandedSidebarFolderIDs.insert(folder.path)
        }
        refreshVisibleSidebarRows()
    }

    private func selectFirstChild(after folder: SidebarFileTree.FolderRow) {
        guard let folderIndex = visibleSidebarRows.firstIndex(where: { $0.id == folder.id }) else { return }
        let childIndex = folderIndex + 1
        guard visibleSidebarRows.indices.contains(childIndex) else { return }
        let child = visibleSidebarRows[childIndex]
        switch child {
        case let .folder(childFolder) where childFolder.depth > folder.depth:
            activeSidebarRowID = childFolder.id
        case let .file(childFile) where childFile.depth > folder.depth:
            activeSidebarRowID = childFile.id
            model.openFile(childFile.file.path)
            showDetailIfNeeded()
        default:
            break
        }
    }

    private func selectParentFolder(before rowIndex: Int, depth: Int) {
        guard depth > 0 else { return }
        for index in stride(from: rowIndex - 1, through: 0, by: -1) {
            guard case let .folder(folder) = visibleSidebarRows[index], folder.depth == depth - 1 else { continue }
            activeSidebarRowID = folder.id
            return
        }
    }

    private func selectSidebarRow(_ row: SidebarFileTree.Row, opensFiles: Bool) {
        activeSidebarRowID = row.id
        guard opensFiles, let filePath = row.filePath else { return }
        model.openFile(filePath)
        showDetailIfNeeded()
    }

    private func expandSelectedSidebarAncestors() {
        let before = expandedSidebarFolderIDs
        expandedSidebarFolderIDs.formUnion(SidebarFileTree.folderPathPrefixes(for: model.selectedPath))
        if expandedSidebarFolderIDs != before {
            refreshVisibleSidebarRows()
        }
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

    private func sidebarFocusedRowBackground(isFocused: Bool) -> some View {
        Group {
            if isFocused {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.42), lineWidth: 1)
                    .padding(.vertical, 1)
            } else {
                Color.clear
            }
        }
    }

    private var detailContent: some View {
        outlineDetailLayout
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
            .sheet(isPresented: outlineSheetBinding) {
                DocumentOutlinePanel(
                    items: model.outlineItems,
                    fontScale: model.fontScale,
                    activeBlockID: activeOutlineBlockID,
                    onSelect: { item in
                        scrollToOutlineItem(item)
                        isOutlinePresented = false
                    }
                )
                #if os(macOS)
                .frame(minWidth: 300, minHeight: 420)
                #endif
            }
    }

    @ViewBuilder
    private var outlineDetailLayout: some View {
        #if os(macOS)
        if shouldShowInlineOutline {
            HSplitView {
                documentContent
                    .frame(minWidth: OutlinePaneMetrics.minimumDocumentWidth, maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)

                DocumentOutlinePanel(
                    items: model.outlineItems,
                    fontScale: model.fontScale,
                    activeBlockID: activeOutlineBlockID,
                    onSelect: scrollToOutlineItem(_:)
                )
                .frame(
                    minWidth: OutlinePaneMetrics.minimumWidth,
                    idealWidth: OutlinePaneMetrics.defaultWidth,
                    maxWidth: OutlinePaneMetrics.maximumWidth
                )
                .layoutPriority(0)
            }
        } else {
            documentContent
        }
        #else
        GeometryReader { geometry in
            let paneWidth = OutlinePaneMetrics.clampedWidth(
                outlinePaneWidth,
                containerWidth: geometry.size.width
            )

            HStack(spacing: 0) {
                documentContent

                if shouldShowInlineOutline {
                    OutlinePaneResizeHandle(
                        paneWidth: $outlinePaneWidth,
                        displayedPaneWidth: paneWidth,
                        containerWidth: geometry.size.width
                    )

                    DocumentOutlinePanel(
                        items: model.outlineItems,
                        fontScale: model.fontScale,
                        activeBlockID: activeOutlineBlockID,
                        onSelect: scrollToOutlineItem(_:)
                    )
                    .frame(width: paneWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        #endif
    }

    private var documentContent: some View {
        ZStack {
            if shouldShowEmptyWorkspaceState {
                emptyWorkspaceState
            } else if shouldUseBlockScrollView {
                DocumentBlockScrollView(
                    blocks: model.documentBlocks,
                    workspaceRootURL: model.currentWorkspaceRootURL,
                    fontScale: model.fontScale,
                    tabularPresentation: model.shouldShowTabularControls ? model.tabularPresentation : nil,
                    syntaxTheme: SyntaxHighlightTheme.resolved(
                        launchTheme: model.launchOptions.theme,
                        colorScheme: colorScheme
                    ),
                    scrollTargetID: $documentScrollTargetID,
                    outlineItems: model.outlineItems,
                    tracksActiveOutline: isOutlinePresented && canShowOutline,
                    activeOutlineBlockID: $activeOutlineBlockID,
                    searchHighlightQuery: model.searchQuery,
                    activeSearchBlockID: model.selectedSearchResult?.blockID,
                    onOpenMermaidPreview: { target in
                        mermaidPreviewTarget = target
                    }
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
            } else if model.isPreparingPrint {
                printPreparingOverlay
            }
        }
        .onChange(of: model.searchScrollTargetID) { targetID in
            guard let targetID else { return }
            documentScrollTargetID = targetID
            model.clearSearchScrollTarget()
        }
    }

    private var shouldUseBlockScrollView: Bool {
        model.shouldRenderBlockContent || !model.outlineItems.isEmpty
    }

    private var canShowOutline: Bool {
        !model.outlineItems.isEmpty
    }

    private var shouldShowInlineOutline: Bool {
        isOutlinePresented && canShowOutline && !isCompactPhoneLayout
    }

    private var outlineSheetBinding: Binding<Bool> {
        Binding(
            get: { isOutlinePresented && canShowOutline && isCompactPhoneLayout },
            set: { newValue in
                if !newValue {
                    isOutlinePresented = false
                }
            }
        )
    }

    private func scrollToOutlineItem(_ item: MarkdownOutlineItem) {
        activeOutlineBlockID = item.blockID
        documentScrollTargetID = item.blockID
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

            ignorePatternsButton

            if canShowOutline {
                outlineButton
            }

            if model.shouldShowTabularControls {
                tabularControls
            }

            printControls

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

                ignorePatternsButton

                if canShowOutline {
                    outlineButton
                }

                if model.shouldShowTabularControls {
                    tabularControls
                }

                printControls

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

    private var printPreparingOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text(model.printPreparationMessage ?? "Preparing print job...")
                    .font(ViewerFont.headline(scale: model.fontScale))
                    .multilineTextAlignment(.center)
                if let onCancelPrintPreparation {
                    Button("Cancel", action: onCancelPrintPreparation)
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier(AccessibilityIDs.printCancelButton)
                }
            }
            .padding(24)
        }
        .frame(width: 320, height: 170)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIDs.printPreparingIndicator)
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
    private var ignorePatternsButton: some View {
        Button {
            isPresentingIgnorePatterns = true
        } label: {
            Label("Ignore Patterns", systemImage: "eye")
        }
        .accessibilityIdentifier(AccessibilityIDs.ignorePatternsButton)
        .help("Edit ignored workspace patterns")
    }

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

    #if !os(macOS)
    private var ignorePatternsButton: some View {
        Button {
            isPresentingIgnorePatterns = true
        } label: {
            Image(systemName: "eye")
        }
        .accessibilityIdentifier(AccessibilityIDs.ignorePatternsButton)
        .accessibilityLabel("Ignore Patterns")
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

    private var outlineButton: some View {
        Button {
            isOutlinePresented.toggle()
        } label: {
            Label {
                Text("Document Outline")
            } icon: {
                Image(systemName: "list.bullet.indent")
                    .fontWeight(isOutlinePresented ? .semibold : .regular)
            }
            .foregroundStyle(isOutlinePresented ? Color.accentColor : Color.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background {
                if isOutlinePresented {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor.opacity(0.16))
                }
            }
            .overlay {
                if isOutlinePresented {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                }
            }
        }
        .disabled(!canShowOutline)
        .accessibilityIdentifier(AccessibilityIDs.documentOutlineButton)
        .accessibilityValue(isOutlinePresented ? "Shown" : "Hidden")
        .help(isOutlinePresented ? "Hide Document Outline" : "Show Document Outline")
    }

    private var tabularControls: some View {
        HStack(spacing: 8) {
            Button(action: model.toggleTabularWrapMode) {
                Image(systemName: "text.justify.left")
            }
            .accessibilityIdentifier(AccessibilityIDs.tableWrapToggleButton)
            .accessibilityLabel(model.tabularPresentation.wrapMode == .wrap ? "Wrap Cells" : "Clip Cells")
            .help(model.tabularPresentation.wrapMode == .wrap ? "Wrap Cells" : "Clip Cells")

            Menu {
                Button("Widen Columns") {
                    model.increaseColumnWidth()
                }
                .disabled(!model.canIncreaseColumnWidth)

                Button("Narrow Columns") {
                    model.decreaseColumnWidth()
                }
                .disabled(!model.canDecreaseColumnWidth)

                Button("Taller Rows") {
                    model.increaseRowHeight()
                }
                .disabled(!model.canIncreaseRowHeight)

                Button("Shorter Rows") {
                    model.decreaseRowHeight()
                }
                .disabled(!model.canDecreaseRowHeight)
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityIdentifier(AccessibilityIDs.tableSizingMenuButton)
            .accessibilityLabel("Table Size")
        }
        .labelStyle(.iconOnly)
    }

    private var printControls: some View {
        #if os(macOS)
        EmptyView()
        #else
        Menu {
            if let onPrintSelectedDocument {
                Button("Print") {
                    onPrintSelectedDocument()
                }
                .disabled(!model.canPrintSelectedDocument)
            }

            if let onPrintAllDocuments {
                Button("Print All") {
                    onPrintAllDocuments()
                }
                .disabled(!model.canPrintAllDocuments)
            }
        } label: {
            Image(systemName: "printer")
        }
        .accessibilityIdentifier(AccessibilityIDs.printMenuButton)
        .accessibilityLabel("Print")
        #endif
    }

    #if os(macOS)
    private var macPrintControl: AnyView? {
        guard let onPrintSelectedDocument, let onPrintAllDocuments else { return nil }
        return AnyView(
            ControlGroup {
                Button {
                    onPrintSelectedDocument()
                } label: {
                    Image(systemName: "printer")
                }
                .disabled(!model.canPrintSelectedDocument)
                .accessibilityIdentifier(AccessibilityIDs.printSelectedButton)
                .accessibilityLabel("Print")
                .help("Print the selected document")

                Button {
                    onPrintAllDocuments()
                } label: {
                    Image(systemName: "printer.fill")
                }
                .disabled(!model.canPrintAllDocuments)
                .accessibilityIdentifier(AccessibilityIDs.printAllButton)
                .accessibilityLabel("Print All")
                .help("Print every document in the workspace")
            }
            .labelStyle(.iconOnly)
        )
    }
    #endif

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

    @ViewBuilder
    private func mermaidPreview(for target: MermaidDiagramPreviewTarget) -> some View {
        MermaidDiagramPreviewView(
            target: target,
            onClose: { mermaidPreviewTarget = nil },
            onOpenInWindow: mermaidOpenInWindowAction(for: target),
            presentation: .constrainedSheet
        )
    }

    private func mermaidOpenInWindowAction(for target: MermaidDiagramPreviewTarget) -> (() -> Void)? {
        #if os(macOS)
        return {
            MermaidPreviewWindowPresenter.shared.open(target: target)
            mermaidPreviewTarget = nil
        }
        #else
        return nil
        #endif
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
            if model.launchOptions.uiTestMode && model.launchOptions.uiTestShowSidebar {
                compactShowsSidebar = true
                return
            }
            compactShowsSidebar = !model.shouldPreferDetailInCompactNavigation
            return
        }
        if model.launchOptions.uiTestMode && model.launchOptions.uiTestShowSidebar {
            columnVisibility = .all
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

private enum OutlinePaneMetrics {
    static let defaultWidth: CGFloat = 280
    static let minimumWidth: CGFloat = 220
    static let maximumWidth: CGFloat = 460
    static let minimumDocumentWidth: CGFloat = 360
    static let resizeStep: CGFloat = 24
    static let handleHitWidth: CGFloat = 14

    static func clampedWidth(_ proposedWidth: CGFloat, containerWidth: CGFloat) -> CGFloat {
        let containerMaximum = max(minimumWidth, containerWidth - minimumDocumentWidth)
        let effectiveMaximum = min(maximumWidth, containerMaximum)
        return min(max(proposedWidth, minimumWidth), effectiveMaximum)
    }
}

private struct WorkspaceIgnorePatternsSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var patternText: String

    init(model: AppModel) {
        self.model = model
        _patternText = State(initialValue: model.workspaceIgnorePatternText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ignored Patterns")
                    .font(.title2.weight(.semibold))

                Text("Enter comma-separated names or path patterns. Matching files and folders are hidden from this window's file list.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("node_modules, venv, .venv, vendor", text: $patternText)
                    #if os(macOS)
                    .textFieldStyle(.roundedBorder)
                    #else
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    #endif
                    .accessibilityIdentifier(AccessibilityIDs.ignorePatternsSheetField)

                Text("Defaults: \(WorkspaceIgnorePatterns.default.commaSeparated)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(20)
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 220, alignment: .topLeading)
            #else
            .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .automatic) {
                    Button("Reset") {
                        patternText = WorkspaceIgnorePatterns.default.commaSeparated
                    }
                    .accessibilityIdentifier(AccessibilityIDs.ignorePatternsSheetResetButton)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        model.updateWorkspaceIgnorePatterns(from: patternText)
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityIDs.ignorePatternsSheetApplyButton)
                }
            }
        }
    }
}

private struct OutlinePaneResizeHandle: View {
    @Binding var paneWidth: CGFloat
    let displayedPaneWidth: CGFloat
    let containerWidth: CGFloat
    @State private var dragStartWidth: CGFloat?
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)

            Rectangle()
                .fill((isDragging ? Color.accentColor : Color.secondary).opacity(isDragging ? 0.55 : 0.35))
                .frame(width: 1)
        }
        .frame(width: OutlinePaneMetrics.handleHitWidth)
        .contentShape(Rectangle())
        .gesture(resizeGesture)
        .horizontalResizeCursor()
        .accessibilityLabel("Resize Outline")
        .accessibilityValue("\(Int(displayedPaneWidth)) pixels")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustWidth(by: OutlinePaneMetrics.resizeStep)
            case .decrement:
                adjustWidth(by: -OutlinePaneMetrics.resizeStep)
            @unknown default:
                break
            }
        }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartWidth == nil {
                    dragStartWidth = displayedPaneWidth
                }
                isDragging = true
                let startingWidth = dragStartWidth ?? displayedPaneWidth
                paneWidth = OutlinePaneMetrics.clampedWidth(
                    startingWidth - value.translation.width,
                    containerWidth: containerWidth
                )
            }
            .onEnded { _ in
                dragStartWidth = nil
                isDragging = false
            }
    }

    private func adjustWidth(by delta: CGFloat) {
        paneWidth = OutlinePaneMetrics.clampedWidth(
            displayedPaneWidth + delta,
            containerWidth: containerWidth
        )
    }
}

struct DocumentBlockScrollView: View {
    let blocks: [MarkdownBlock]
    let workspaceRootURL: URL?
    let fontScale: CGFloat
    let tabularPresentation: TabularDocumentPresentation?
    let syntaxTheme: SyntaxHighlightTheme
    @Binding var scrollTargetID: String?
    let outlineItems: [MarkdownOutlineItem]
    let tracksActiveOutline: Bool
    @Binding var activeOutlineBlockID: String?
    let searchHighlightQuery: String
    let activeSearchBlockID: String?
    let onOpenMermaidPreview: (MermaidDiagramPreviewTarget) -> Void
    @State private var pendingHeadingOffsets: [String: CGFloat] = [:]
    @State private var activeOutlineUpdateTask: Task<Void, Never>?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                DocumentBlockStackView(
                    blocks: blocks,
                    workspaceRootURL: workspaceRootURL,
                    fontScale: fontScale,
                    tabularPresentation: tabularPresentation,
                    syntaxTheme: syntaxTheme,
                    usesLazyLayout: true,
                    isPrinting: false,
                    tracksHeadingOffsets: tracksActiveOutline,
                    searchHighlightQuery: searchHighlightQuery,
                    activeSearchBlockID: activeSearchBlockID,
                    onOpenMermaidPreview: onOpenMermaidPreview
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .coordinateSpace(name: DocumentScrollCoordinateSpace.name)
            .onPreferenceChange(HeadingOffsetPreferenceKey.self) { headingOffsets in
                scheduleActiveOutlineUpdate(headingOffsets)
            }
            .onChange(of: scrollTargetID) { targetID in
                guard let targetID else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(targetID, anchor: .top)
                }
                DispatchQueue.main.async {
                    scrollTargetID = nil
                }
            }
            .onDisappear {
                activeOutlineUpdateTask?.cancel()
                activeOutlineUpdateTask = nil
            }
        }
        .textSelection(.enabled)
        .accessibilityIdentifier(AccessibilityIDs.scrollView)
    }

    private func scheduleActiveOutlineUpdate(_ headingOffsets: [String: CGFloat]) {
        guard tracksActiveOutline else { return }
        pendingHeadingOffsets = headingOffsets
        guard activeOutlineUpdateTask == nil else { return }

        activeOutlineUpdateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: DocumentOutlineTracking.updateIntervalNanoseconds)
            applyPendingActiveOutlineUpdate()
        }
    }

    @MainActor
    private func applyPendingActiveOutlineUpdate() {
        activeOutlineUpdateTask = nil
        let resolvedBlockID = AppModel.activeOutlineBlockID(
            from: pendingHeadingOffsets,
            outlineItems: outlineItems,
            currentBlockID: activeOutlineBlockID
        )
        if resolvedBlockID != activeOutlineBlockID {
            activeOutlineBlockID = resolvedBlockID
        }
    }
}

private enum DocumentScrollCoordinateSpace {
    static let name = "document-scroll-coordinate-space"
}

private struct HeadingOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private enum DocumentOutlineTracking {
    static let updateIntervalNanoseconds: UInt64 = 80_000_000
}

struct PrintableDocumentCompositionView: View {
    let composition: DocumentPrintComposition
    let pageLayout: DocumentPrintPageLayout

    private var syntaxTheme: SyntaxHighlightTheme {
        SyntaxHighlightTheme.resolved(launchTheme: composition.launchTheme, colorScheme: .light)
    }

    private var printFontScale: CGFloat {
        CGFloat(composition.fontScale) * ViewerFont.printBodyScaleMultiplier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if composition.scope == .allFiles {
                Text(composition.workspaceTitle)
                    .font(ViewerFont.scaledSystem(size: 24, weight: .semibold, scale: printFontScale))
            }

            ForEach(Array(composition.sections.enumerated()), id: \.element.path) { index, section in
                VStack(alignment: .leading, spacing: 16) {
                    Text(section.title)
                        .font(ViewerFont.scaledSystem(size: 16, weight: .semibold, scale: printFontScale))
                    DocumentBlockStackView(
                        blocks: section.blocks,
                        workspaceRootURL: nil,
                        fontScale: printFontScale,
                        tabularPresentation: nil,
                        syntaxTheme: syntaxTheme,
                        usesLazyLayout: false,
                        isPrinting: true,
                        tracksHeadingOffsets: false,
                        searchHighlightQuery: "",
                        activeSearchBlockID: nil,
                        onOpenMermaidPreview: { _ in }
                    )
                }

                if index != composition.sections.indices.last {
                    Divider()
                }
            }
        }
        .frame(width: pageLayout.printableRect.width, alignment: .leading)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }
}

private struct DocumentBlockStackView: View {
    let blocks: [MarkdownBlock]
    let workspaceRootURL: URL?
    let fontScale: CGFloat
    let tabularPresentation: TabularDocumentPresentation?
    let syntaxTheme: SyntaxHighlightTheme
    let usesLazyLayout: Bool
    let isPrinting: Bool
    let tracksHeadingOffsets: Bool
    let searchHighlightQuery: String
    let activeSearchBlockID: String?
    let onOpenMermaidPreview: (MermaidDiagramPreviewTarget) -> Void

    var body: some View {
        Group {
            if usesLazyLayout {
                LazyVStack(alignment: .leading, spacing: 16) {
                    blockViews
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    blockViews
                }
            }
        }
    }

    @ViewBuilder
    private var blockViews: some View {
        ForEach(blocks) { block in
            MarkdownBlockView(
                block: block,
                workspaceRootURL: workspaceRootURL,
                fontScale: fontScale,
                tabularPresentation: tabularPresentation,
                syntaxTheme: syntaxTheme,
                isPrinting: isPrinting,
                searchHighlightQuery: searchHighlightQuery,
                activeSearchBlockID: activeSearchBlockID,
                onOpenMermaidPreview: onOpenMermaidPreview
            )
            .id(block.id)
            .background(headingOffsetReporter(for: block))
        }
    }

    @ViewBuilder
    private func headingOffsetReporter(for block: MarkdownBlock) -> some View {
        if tracksHeadingOffsets && block.kind == .heading {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: HeadingOffsetPreferenceKey.self,
                    value: [block.id: proxy.frame(in: .named(DocumentScrollCoordinateSpace.name)).minY]
                )
            }
        } else {
            Color.clear
        }
    }
}

private struct DocumentOutlinePanel: View {
    let items: [MarkdownOutlineItem]
    let fontScale: CGFloat
    let activeBlockID: String?
    let onSelect: (MarkdownOutlineItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Outline")
                .font(ViewerFont.headline(scale: fontScale))
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            DocumentOutlineRow(
                                item: item,
                                fontScale: fontScale,
                                isActive: item.blockID == activeBlockID
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(AccessibilityIDs.documentOutlineItem(item.blockID))
                    }
                }
                .padding(.vertical, 8)
            }
            .accessibilityIdentifier(AccessibilityIDs.documentOutlineList)
        }
        .background(.regularMaterial)
        .accessibilityIdentifier(AccessibilityIDs.documentOutlinePanel)
    }
}

private struct DocumentOutlineRow: View {
    let item: MarkdownOutlineItem
    let fontScale: CGFloat
    let isActive: Bool

    var body: some View {
        DocumentOutlineTitleText(
            runs: item.titleRuns,
            fontScale: fontScale
        )
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .foregroundStyle(isActive ? Color.accentColor : Color.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
        .padding(.leading, CGFloat(max(0, item.level - 1)) * 12 + 14)
        .padding(.trailing, 14)
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.42), lineWidth: 1)
            }
        }
    }
}

private struct DocumentOutlineTitleText: View {
    let runs: [MarkdownOutlineTitleRun]
    let fontScale: CGFloat

    var body: some View {
        composedText
    }

    private var composedText: Text {
        guard let first = runs.first else { return Text("") }
        return runs.dropFirst().reduce(text(for: first)) { partial, run in
            partial + text(for: run)
        }
    }

    private func text(for run: MarkdownOutlineTitleRun) -> Text {
        Text(verbatim: run.text)
            .font(run.isCode ? ViewerFont.monospacedBody(scale: fontScale) : ViewerFont.body(scale: fontScale))
    }
}

private struct SidebarFileRow: View {
    let file: MarkdownFileNode
    let depth: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            if depth > 0 {
                Color.clear
                    .frame(width: CGFloat(depth) * 16)
            }
            Image(systemName: file.kind.iconSystemName)
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

private struct SidebarFolderRow: View {
    let folder: SidebarFileTree.FolderRow
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            if folder.depth > 0 {
                Color.clear
                    .frame(width: CGFloat(folder.depth) * 16)
            }
            Image(systemName: folder.isExpanded ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 10)
            Image(systemName: folder.isExpanded ? "folder.fill" : "folder")
                .foregroundStyle(isFocused ? Color.accentColor : Color.secondary)
            Text(folder.label)
                .font(ViewerFont.body(scale: 1))
                .foregroundStyle(isFocused ? Color.accentColor : Color.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct SearchResultRow: View {
    let result: DocumentSearchResult
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(result.fileName)
                    .font(ViewerFont.body(scale: 1))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("L\(result.lineNumber)")
                    .font(ViewerFont.monospacedBody(scale: 0.86))
                    .foregroundStyle(.secondary)
            }
            Text(result.snippet)
                .font(ViewerFont.body(scale: 0.9))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

#if os(macOS)
private struct MacLiveSearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let accessibilityIdentifier: String
    let focusTrigger: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> LiveNSSearchField {
        let field = LiveNSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.onTextChange = context.coordinator.updateText(_:)
        field.target = context.coordinator
        field.action = #selector(Coordinator.commitText(_:))
        field.isContinuous = true
        field.sendAction(on: [.keyUp])
        field.controlSize = .regular
        field.setAccessibilityIdentifier(accessibilityIdentifier)
        return field
    }

    func updateNSView(_ nsView: LiveNSSearchField, context: Context) {
        context.coordinator.text = $text
        nsView.onTextChange = context.coordinator.updateText(_:)
        nsView.placeholderString = placeholder
        nsView.setAccessibilityIdentifier(accessibilityIdentifier)
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if context.coordinator.focusTrigger != focusTrigger {
            context.coordinator.focusTrigger = focusTrigger
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        var focusTrigger = 0

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            updateText(field.stringValue)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            updateText(field.stringValue)
        }

        @objc func commitText(_ sender: NSSearchField) {
            updateText(sender.stringValue)
        }

        func updateText(_ newText: String) {
            guard text.wrappedValue != newText else { return }
            text.wrappedValue = newText
        }
    }

    final class LiveNSSearchField: NSSearchField {
        var onTextChange: ((String) -> Void)?

        override func textDidChange(_ notification: Notification) {
            super.textDidChange(notification)
            onTextChange?(stringValue)
        }

        override func textDidEndEditing(_ notification: Notification) {
            super.textDidEndEditing(notification)
            onTextChange?(stringValue)
        }
    }
}
#endif

struct MarkdownBlockView: View {
    let block: MarkdownBlock
    let workspaceRootURL: URL?
    let fontScale: CGFloat
    let tabularPresentation: TabularDocumentPresentation?
    let syntaxTheme: SyntaxHighlightTheme
    let isPrinting: Bool
    let searchHighlightQuery: String
    let activeSearchBlockID: String?
    let onOpenMermaidPreview: (MermaidDiagramPreviewTarget) -> Void

    var body: some View {
        blockContent
            .background {
                if block.id == activeSearchBlockID {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.yellow.opacity(0.18))
                        .padding(-6)
                }
            }
    }

    @ViewBuilder
    private var blockContent: some View {
        switch block.kind {
        case .heading:
            Text(displayAttributedText(for: block))
                .font(headingFont(for: block.level ?? 1, scale: fontScale))
                .fontWeight(.semibold)
                .linkHoverCursor(MarkdownRenderer.attributedText(for: block))
        case .paragraph:
            Text(displayAttributedText(for: block))
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
                        Text(displayAttributedText(for: block))
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
                        Text(displayAttributedText(for: block))
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
                Text(displayAttributedText(for: block))
                    .font(ViewerFont.body(scale: fontScale))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .linkHoverCursor(MarkdownRenderer.attributedText(for: block))
            }
        case .codeBlock:
            codeBlockContent
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .table:
            if let table = block.table {
                tableContent(table)
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
                    fontScale: fontScale,
                    isPrinting: isPrinting
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
        case .mermaidDiagram:
            if let diagram = block.mermaidDiagram {
                MermaidDiagramBlockView(
                    diagram: diagram,
                    blockID: block.id,
                    fontScale: fontScale,
                    isPrinting: isPrinting,
                    onOpenPreview: onOpenMermaidPreview
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

    private func displayAttributedText(for block: MarkdownBlock) -> AttributedString {
        var attributedText = MarkdownRenderer.attributedText(for: block)
        let query = searchHighlightQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return attributedText }

        let plainText = String(attributedText.characters)
        var searchStart = plainText.startIndex
        while searchStart < plainText.endIndex,
              let range = plainText.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<plainText.endIndex
              ),
              let lowerBound = AttributedString.Index(range.lowerBound, within: attributedText),
              let upperBound = AttributedString.Index(range.upperBound, within: attributedText) {
            attributedText[lowerBound..<upperBound].backgroundColor = .yellow.opacity(0.55)
            searchStart = range.upperBound
        }
        return attributedText
    }

    @ViewBuilder
    private var taskListLabel: some View {
        #if os(macOS)
        Toggle(isOn: .constant(block.isTaskCompleted == true)) {
            Text(displayAttributedText(for: block))
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
            Text(displayAttributedText(for: block))
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
                    tabularPresentation: tabularPresentation,
                    syntaxTheme: syntaxTheme,
                    isPrinting: isPrinting,
                    searchHighlightQuery: searchHighlightQuery,
                    activeSearchBlockID: activeSearchBlockID,
                    onOpenMermaidPreview: onOpenMermaidPreview
                )
            }
        }
        .padding(.leading, 28)
    }

    @ViewBuilder
    private var codeBlockContent: some View {
        if isPrinting {
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
        } else {
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
        }
    }

    @ViewBuilder
    private func tableContent(_ table: MarkdownTable) -> some View {
        if isPrinting {
            VStack(alignment: .leading, spacing: 0) {
                printableTableRow(
                    table.header,
                    alignments: table.alignments,
                    contentKind: table.contentKind,
                    isHeader: true
                )
                Divider()
                ForEach(table.rows.indices, id: \.self) { rowIndex in
                    printableTableRow(
                        table.rows[rowIndex],
                        alignments: table.alignments,
                        contentKind: table.contentKind,
                        isHeader: false
                    )
                    Divider()
                }
            }
            .padding(14)
        } else if shouldUseLazyTableViewport(for: table) {
            let presentation = tabularPresentation ?? TabularDocumentPresentation()
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(table.rows.indices, id: \.self) { rowIndex in
                            lazyTableRow(
                                table.rows[rowIndex],
                                alignments: table.alignments,
                                contentKind: table.contentKind,
                                presentation: presentation,
                                isHeader: false
                            )
                            Divider()
                        }
                    } header: {
                        lazyTableRow(
                            table.header,
                            alignments: table.alignments,
                            contentKind: table.contentKind,
                            presentation: presentation,
                            isHeader: true
                        )
                        .background(.regularMaterial)
                        Divider()
                    }
                }
                .padding(14)
            }
            .frame(
                minHeight: 260,
                idealHeight: tabularTableHeight(rowCount: table.rows.count + 1, presentation: presentation),
                maxHeight: tabularTableHeight(rowCount: table.rows.count + 1, presentation: presentation)
            )
        } else {
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        ForEach(Array(table.header.enumerated()), id: \.offset) { column, cell in
                            tableCell(
                                cell,
                                columnAlignment: table.alignments[column],
                                contentKind: table.contentKind,
                                isHeader: true
                            )
                        }
                    }
                    Divider()
                        .gridCellColumns(table.header.count)
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                                tableCell(
                                    cell,
                                    columnAlignment: table.alignments[column],
                                    contentKind: table.contentKind,
                                    isHeader: false
                                )
                            }
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    private func printableTableRow(
        _ row: [MarkdownTableCell],
        alignments: [MarkdownTableAlignment],
        contentKind: MarkdownTableContentKind,
        isHeader: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                tableCell(
                    cell,
                    columnAlignment: alignments[column],
                    contentKind: contentKind,
                    isHeader: isHeader
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lazyTableRow(
        _ row: [MarkdownTableCell],
        alignments: [MarkdownTableAlignment],
        contentKind: MarkdownTableContentKind,
        presentation: TabularDocumentPresentation,
        isHeader: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(row.indices, id: \.self) { column in
                tableCell(
                    row[column],
                    columnAlignment: alignments[column],
                    contentKind: contentKind,
                    presentation: presentation,
                    isHeader: isHeader
                )
                .padding(.horizontal, 8)
            }
        }
    }

    @ViewBuilder
    private func tableCell(
        _ cell: MarkdownTableCell,
        columnAlignment: MarkdownTableAlignment,
        contentKind: MarkdownTableContentKind,
        presentation: TabularDocumentPresentation? = nil,
        isHeader: Bool
    ) -> some View {
        if let tabularPresentation = presentation ?? tabularPresentation {
            if contentKind == .plainText {
                Text(verbatim: cell.plainText)
                    .font(ViewerFont.body(scale: fontScale))
                    .fontWeight(isHeader ? .semibold : .regular)
                    .lineLimit(tabularPresentation.wrapMode == .wrap ? nil : 1)
                    .frame(
                        width: tabularPresentation.columnWidth,
                        height: tabularPresentation.rowHeight,
                        alignment: alignment(for: columnAlignment)
                    )
                    .multilineTextAlignment(textAlignment(for: columnAlignment))
                    .clipped()
            } else {
                let attributedText = MarkdownRenderer.attributedText(for: cell)
                Text(attributedText)
                    .font(ViewerFont.body(scale: fontScale))
                    .fontWeight(isHeader ? .semibold : .regular)
                    .lineLimit(tabularPresentation.wrapMode == .wrap ? nil : 1)
                    .frame(
                        width: tabularPresentation.columnWidth,
                        height: tabularPresentation.rowHeight,
                        alignment: alignment(for: columnAlignment)
                    )
                    .multilineTextAlignment(textAlignment(for: columnAlignment))
                    .clipped()
                    .linkHoverCursor(attributedText)
            }
        } else {
            if contentKind == .plainText {
                Text(verbatim: cell.plainText)
                    .font(ViewerFont.body(scale: fontScale))
                    .fontWeight(isHeader ? .semibold : .regular)
                    .frame(maxWidth: .infinity, alignment: alignment(for: columnAlignment))
            } else {
                let attributedText = MarkdownRenderer.attributedText(for: cell)
                Text(attributedText)
                    .font(ViewerFont.body(scale: fontScale))
                    .fontWeight(isHeader ? .semibold : .regular)
                    .frame(maxWidth: .infinity, alignment: alignment(for: columnAlignment))
                    .linkHoverCursor(attributedText)
            }
        }
    }

    private func shouldUseLazyTableViewport(for table: MarkdownTable) -> Bool {
        if tabularPresentation != nil && table.contentKind == .plainText {
            return true
        }
        return table.prefersLazyInteractiveViewport
    }

    private func tabularTableHeight(rowCount: Int, presentation: TabularDocumentPresentation) -> CGFloat {
        min(max(CGFloat(rowCount) * (presentation.rowHeight + 1) + 28, 260), 720)
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

    private func textAlignment(for alignment: MarkdownTableAlignment) -> TextAlignment {
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

private struct HorizontalResizeCursorModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                guard hovering != isHovering else { return }
                isHovering = hovering
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

private extension View {
    func linkHoverCursor(_ attributedText: AttributedString) -> some View {
        modifier(LinkHoverCursorModifier(hasLink: attributedText.runs.contains { $0.link != nil }))
    }

    func horizontalResizeCursor() -> some View {
        modifier(HorizontalResizeCursorModifier())
    }
}
#else
private extension View {
    func linkHoverCursor(_ attributedText: AttributedString) -> some View {
        self
    }

    func horizontalResizeCursor() -> some View {
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
    let isPrinting: Bool
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
                imageSurface(for: resolvedURL)
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

    @ViewBuilder
    private func imageSurface(for resolvedURL: URL) -> some View {
        if isPrinting {
            PrintableStaticImageSurface(url: resolvedURL)
        } else {
            InlineAnimatedImageSurface(url: resolvedURL)
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
                    fontScale: 1,
                    isPrinting: false
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
    static let printBodyScaleMultiplier: CGFloat = {
        let bodyPointSize = basePlatformFont(forTextStyle: .body).pointSize
        guard bodyPointSize > 0 else { return 1 }
        return 12 / bodyPointSize
    }()

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

private struct PrintableStaticImageSurface: View {
    let url: URL

    var body: some View {
        Group {
            if let image = decodedImage {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 320, alignment: .leading)
        .background(Color.white)
    }

    private var decodedImage: Image? {
        #if os(macOS)
        guard let image = decodedPlatformImage else { return nil }
        return Image(nsImage: image)
        #elseif os(iOS)
        guard let image = decodedPlatformImage else { return nil }
        return Image(uiImage: image)
        #endif
    }

    #if os(macOS)
    private var decodedPlatformImage: NSImage? {
        if url.isFileURL {
            return NSImage(contentsOf: url)
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return NSImage(data: data)
    }
    #elseif os(iOS)
    private var decodedPlatformImage: UIImage? {
        if url.isFileURL {
            return UIImage(contentsOfFile: url.path)
        }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    #endif
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
