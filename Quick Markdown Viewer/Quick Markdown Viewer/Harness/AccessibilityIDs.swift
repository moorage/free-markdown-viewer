import Foundation

enum AccessibilityIDs {
    static let sidebarList = "sidebar.list"
    static let sidebarFilterField = "sidebar.filterField"
    static let sidebarFilterClearButton = "sidebar.filterClear"
    static let backButton = "nav.back"
    static let forwardButton = "nav.forward"
    static let title = "nav.title"
    static let openFolderButton = "toolbar.openFolder"
    static let openGitHubURLButton = "toolbar.openGitHubURL"
    static let printMenuButton = "toolbar.print"
    static let printSelectedButton = "toolbar.printSelected"
    static let printAllButton = "toolbar.printAll"
    static let printRequestScope = "print.request.scope"
    static let printRequestStatus = "print.request.status"
    static let uiTestPrintSelectedAction = "ui-test.printSelectedAction"
    static let uiTestPrintAllAction = "ui-test.printAllAction"
    static let revealInFinderButton = "toolbar.revealInFinder"
    static let ignorePatternsButton = "toolbar.ignorePatterns"
    static let tableWrapToggleButton = "toolbar.tableWrap"
    static let tableSizingMenuButton = "toolbar.tableSizing"
    static let decreaseFontSizeButton = "toolbar.decreaseFontSize"
    static let increaseFontSizeButton = "toolbar.increaseFontSize"
    static let documentOutlineButton = "toolbar.documentOutline"
    static let documentOutlinePanel = "document.outline.panel"
    static let documentOutlineList = "document.outline.list"
    static let scrollView = "document.scrollView"
    static let text = "document.text"
    static let placeholderBlock = "block.placeholder.0"
    static let emptyStateMessage = "empty-state.message"
    static let emptyStateOpenFolderButton = "empty-state.open-folder"
    static let emptyStateGitHubURLField = "empty-state.github-url.field"
    static let emptyStateGitHubURLLoadButton = "empty-state.github-url.load"
    static let emptyStateGitHubURLErrorMessage = "empty-state.github-url.error"
    static let emptyStateCommandLineToolMessage = "empty-state.commandLineTool.message"
    static let emptyStateCommandLineToolButton = "empty-state.commandLineTool.button"
    static let githubURLSheetField = "github-url.sheet.field"
    static let githubURLSheetLoadButton = "github-url.sheet.load"
    static let githubURLSheetErrorMessage = "github-url.sheet.error"
    static let ignorePatternsSheetField = "ignore-patterns.sheet.field"
    static let ignorePatternsSheetApplyButton = "ignore-patterns.sheet.apply"
    static let ignorePatternsSheetResetButton = "ignore-patterns.sheet.reset"
    static let commandLineToolPostInstallTitle = "command-line-tool.post-install.title"
    static let commandLineToolPostInstallMessage = "command-line-tool.post-install.message"
    static let commandLineToolPostInstallCommand = "command-line-tool.post-install.command"
    static let commandLineToolPostInstallCopyButton = "command-line-tool.post-install.copy"
    static let commandLineToolPostInstallDoneButton = "command-line-tool.post-install.done"
    static let mediaPreviewContainer = "media-preview.container"
    static let mediaPreviewCloseButton = "media-preview.close"
    static let mediaPreviewOpenInBrowserButton = "media-preview.open-in-browser"

    static func sidebarNode(_ path: String) -> String {
        "sidebar.node.\(path.replacingOccurrences(of: "/", with: "."))"
    }

    static func imageBlock(_ blockID: String) -> String {
        "block.image.\(sanitizedBlockID(blockID))"
    }

    static func videoBlock(_ blockID: String) -> String {
        "block.video.\(sanitizedBlockID(blockID))"
    }

    static func videoPlayButton(_ blockID: String) -> String {
        "video.playButton.\(sanitizedBlockID(blockID))"
    }

    static func documentOutlineItem(_ blockID: String) -> String {
        "document.outline.item.\(sanitizedBlockID(blockID))"
    }

    private static func sanitizedBlockID(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"[^A-Za-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
