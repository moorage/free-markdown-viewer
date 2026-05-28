import Foundation

nonisolated struct SidebarFileTree: Sendable {
    struct Snapshot: Sendable {
        private let root: DirectoryNode

        init(files: [MarkdownFileNode]) {
            let builder = DirectoryBuilder(name: "", path: "")
            for file in files {
                SidebarFileTree.insert(file, into: builder)
            }
            root = SidebarFileTree.freeze(builder)
        }

        func visibleRows(
            expandedFolderIDs: Set<String>,
            expandsAllFolders: Bool = false
        ) -> [Row] {
            SidebarFileTree.childRows(
                for: root,
                depth: 0,
                expandedFolderIDs: expandedFolderIDs,
                expandsAllFolders: expandsAllFolders
            )
        }
    }

    struct FolderRow: Identifiable, Hashable, Sendable {
        let path: String
        let label: String
        let depth: Int
        let isExpanded: Bool

        var id: String { Self.id(for: path) }

        static func id(for path: String) -> String {
            "folder:\(path)"
        }
    }

    struct FileRow: Identifiable, Hashable, Sendable {
        let file: MarkdownFileNode
        let depth: Int

        var id: String { Self.id(for: file.path) }

        static func id(for path: WorkspacePath) -> String {
            "file:\(path.rawValue)"
        }
    }

    enum Row: Identifiable, Hashable, Sendable {
        case folder(FolderRow)
        case file(FileRow)

        var id: String {
            switch self {
            case let .folder(folder):
                return folder.id
            case let .file(file):
                return file.id
            }
        }

        var filePath: WorkspacePath? {
            guard case let .file(file) = self else { return nil }
            return file.file.path
        }

        var folderPath: String? {
            guard case let .folder(folder) = self else { return nil }
            return folder.path
        }
    }

    private struct DirectoryNode: Sendable {
        let name: String
        let path: String
        let folders: [DirectoryNode]
        let files: [MarkdownFileNode]

        init(name: String, path: String, folders: [DirectoryNode], files: [MarkdownFileNode]) {
            self.name = name
            self.path = path
            self.folders = folders
            self.files = files
        }
    }

    private final class DirectoryBuilder {
        let name: String
        let path: String
        var folders: [String: DirectoryBuilder] = [:]
        var files: [MarkdownFileNode] = []

        init(name: String, path: String) {
            self.name = name
            self.path = path
        }
    }

    static func visibleRows(
        from files: [MarkdownFileNode],
        expandedFolderIDs: Set<String>,
        expandsAllFolders: Bool = false
    ) -> [Row] {
        Snapshot(files: files).visibleRows(
            expandedFolderIDs: expandedFolderIDs,
            expandsAllFolders: expandsAllFolders
        )
    }

    static func folderPathPrefixes(for path: WorkspacePath?) -> Set<String> {
        guard let path else { return [] }
        let components = path.rawValue.split(separator: "/").map(String.init)
        guard components.count > 1 else { return [] }
        var prefixes: Set<String> = []
        for index in 0..<(components.count - 1) {
            prefixes.insert(components[0...index].joined(separator: "/"))
        }
        return prefixes
    }

    static func fileRowID(for path: WorkspacePath) -> String {
        FileRow.id(for: path)
    }

    static func folderRowID(for path: String) -> String {
        FolderRow.id(for: path)
    }

    static func adjacentRowID(from currentRowID: String?, within rows: [Row], offset: Int) -> String? {
        guard rows.isEmpty == false else { return nil }
        guard let currentRowID,
              let currentIndex = rows.firstIndex(where: { $0.id == currentRowID }) else {
            return offset >= 0 ? rows.first?.id : rows.last?.id
        }
        let targetIndex = currentIndex + offset
        guard rows.indices.contains(targetIndex) else { return nil }
        return rows[targetIndex].id
    }

    static func row(withID rowID: String?, within rows: [Row]) -> Row? {
        guard let rowID else { return nil }
        return rows.first { $0.id == rowID }
    }

    private static func insert(_ file: MarkdownFileNode, into root: DirectoryBuilder) {
        let components = file.path.rawValue.split(separator: "/").map(String.init)
        guard let fileName = components.last else { return }
        var node = root
        if components.count > 1 {
            for index in 0..<(components.count - 1) {
                let name = components[index]
                let path = components[0...index].joined(separator: "/")
                if let existingNode = node.folders[name] {
                    node = existingNode
                } else {
                    let newNode = DirectoryBuilder(name: name, path: path)
                    node.folders[name] = newNode
                    node = newNode
                }
            }
        }
        node.files.append(
            MarkdownFileNode(
                path: file.path,
                name: fileName,
                kind: file.kind
            )
        )
    }

    private static func freeze(_ builder: DirectoryBuilder) -> DirectoryNode {
        DirectoryNode(
            name: builder.name,
            path: builder.path,
            folders: builder.folders.values
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                .map(freeze(_:)),
            files: sortedFiles(builder.files)
        )
    }

    private static func childRows(
        for node: DirectoryNode,
        depth: Int,
        expandedFolderIDs: Set<String>,
        expandsAllFolders: Bool
    ) -> [Row] {
        folderRows(
            for: node.folders,
            depth: depth,
            expandedFolderIDs: expandedFolderIDs,
            expandsAllFolders: expandsAllFolders
        ) + node.files.map { file in
            .file(FileRow(file: file, depth: depth))
        }
    }

    private static func contentsRows(
        for node: DirectoryNode,
        depth: Int,
        expandedFolderIDs: Set<String>,
        expandsAllFolders: Bool
    ) -> [Row] {
        node.files.map { file in
            Row.file(FileRow(file: file, depth: depth))
        } + folderRows(
            for: node.folders,
            depth: depth,
            expandedFolderIDs: expandedFolderIDs,
            expandsAllFolders: expandsAllFolders
        )
    }

    private static func folderRows(
        for folders: [DirectoryNode],
        depth: Int,
        expandedFolderIDs: Set<String>,
        expandsAllFolders: Bool
    ) -> [Row] {
        var rows: [Row] = []
        for folder in folders {
            let compacted = compactedFolder(from: folder)
            let isExpanded = expandsAllFolders || expandedFolderIDs.contains(compacted.node.path)
            let folderRow = FolderRow(
                path: compacted.node.path,
                label: compacted.label,
                depth: depth,
                isExpanded: isExpanded
            )
            rows.append(.folder(folderRow))
            if isExpanded {
                rows.append(
                    contentsOf: contentsRows(
                        for: compacted.node,
                        depth: depth + 1,
                        expandedFolderIDs: expandedFolderIDs,
                        expandsAllFolders: expandsAllFolders
                    )
                )
            }
        }
        return rows
    }

    private static func compactedFolder(from folder: DirectoryNode) -> (node: DirectoryNode, label: String) {
        var labelComponents = [folder.name]
        var node = folder
        while node.files.isEmpty, node.folders.count == 1, let child = node.folders.first {
            labelComponents.append(child.name)
            node = child
        }
        return (node, labelComponents.joined(separator: " / "))
    }

    private static func sortedFiles(_ files: [MarkdownFileNode]) -> [MarkdownFileNode] {
        files.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}
