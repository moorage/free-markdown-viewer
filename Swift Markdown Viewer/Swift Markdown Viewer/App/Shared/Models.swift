import Foundation

struct WorkspacePath: Hashable, Codable, Identifiable {
    let rawValue: String

    var id: String { rawValue }
}

struct MarkdownFileNode: Identifiable, Hashable {
    let path: WorkspacePath
    let name: String

    var id: String { path.rawValue }
}

struct Workspace {
    let rootIdentifier: String
    let files: [MarkdownFileNode]
}

struct NavigationEntry: Equatable {
    let filePath: WorkspacePath
    let scrollPosition: Double?
}
