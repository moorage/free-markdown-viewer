import Foundation

enum AccessibilityIDs {
    static let sidebarList = "sidebar.list"
    static let backButton = "nav.back"
    static let forwardButton = "nav.forward"
    static let title = "nav.title"
    static let scrollView = "document.scrollView"
    static let text = "document.text"
    static let placeholderBlock = "block.placeholder.0"

    static func sidebarNode(_ path: String) -> String {
        "sidebar.node.\(path.replacingOccurrences(of: "/", with: "."))"
    }
}
