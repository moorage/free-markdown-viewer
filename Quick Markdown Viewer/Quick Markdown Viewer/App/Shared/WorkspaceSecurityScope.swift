import Foundation

struct WorkspaceAccessSelection {
    let rootURL: URL?
    let bookmarkData: Data?
    let activeSecurityScopedURL: URL?
}

enum WorkspaceSecurityScope {
    static func selection(for rootURL: URL?) -> WorkspaceAccessSelection {
        guard let rootURL else {
            return WorkspaceAccessSelection(
                rootURL: nil,
                bookmarkData: nil,
                activeSecurityScopedURL: nil
            )
        }

        let didStartAccess = rootURL.startAccessingSecurityScopedResource()
        return WorkspaceAccessSelection(
            rootURL: rootURL,
            bookmarkData: didStartAccess ? bookmarkData(for: rootURL) : nil,
            activeSecurityScopedURL: didStartAccess ? rootURL : nil
        )
    }

    static func selection(for session: WorkspaceWindowSession?) -> WorkspaceAccessSelection {
        guard let session else {
            return WorkspaceAccessSelection(
                rootURL: nil,
                bookmarkData: nil,
                activeSecurityScopedURL: nil
            )
        }

        if let securityScopedBookmarkData = session.securityScopedBookmarkData,
           let resolvedSelection = resolvedSelection(from: securityScopedBookmarkData) {
            return resolvedSelection
        }

        let fallbackURL = session.rootURL
        let didStartAccess = fallbackURL.startAccessingSecurityScopedResource()
        return WorkspaceAccessSelection(
            rootURL: fallbackURL,
            bookmarkData: didStartAccess ? bookmarkData(for: fallbackURL) : session.securityScopedBookmarkData,
            activeSecurityScopedURL: didStartAccess ? fallbackURL : nil
        )
    }

    static func bookmarkData(for rootURL: URL) -> Data? {
        try? rootURL.bookmarkData(
            options: bookmarkCreationOptions,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private static func resolvedSelection(from bookmarkData: Data) -> WorkspaceAccessSelection? {
        var isStale = false
        guard let resolvedURL = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: bookmarkResolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        let didStartAccess = resolvedURL.startAccessingSecurityScopedResource()
        return WorkspaceAccessSelection(
            rootURL: resolvedURL,
            bookmarkData: didStartAccess ? Self.bookmarkData(for: resolvedURL) ?? bookmarkData : bookmarkData,
            activeSecurityScopedURL: didStartAccess ? resolvedURL : nil
        )
    }

    private static var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if os(iOS)
        return []
        #else
        return [.withSecurityScope]
        #endif
    }

    private static var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if os(iOS)
        return []
        #else
        return [.withSecurityScope]
        #endif
    }
}
