import Foundation

enum AccessibilityIDs {
    static let sidebarList = "sidebar.list"
    static let backButton = "nav.back"
    static let forwardButton = "nav.forward"
    static let title = "nav.title"
    static let scrollView = "document.scrollView"
    static let text = "document.text"
    static let placeholderBlock = "block.placeholder.0"
    static let emptyStateMessage = "empty-state.message"
    static let emptyStateOpenFolderButton = "empty-state.open-folder"

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

    private static func sanitizedBlockID(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"[^A-Za-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
