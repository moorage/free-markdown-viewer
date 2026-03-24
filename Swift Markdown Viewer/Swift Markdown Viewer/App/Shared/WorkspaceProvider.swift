import Foundation

protocol WorkspaceProvider {
    var displayRoot: String { get }
    nonisolated func loadRoot() throws -> Workspace
    nonisolated func readFile(at path: WorkspacePath) throws -> String
    nonisolated func resolveMediaURL(for path: WorkspacePath) throws -> URL
}

enum WorkspaceProviderError: Error {
    case fileNotFound(WorkspacePath)
    case rootMissing(String)
}

enum EmbeddedFixtures {
    static let docs: [String: String] = [
        "basic_typography.md": """
        # Basic typography

        This is a small fixture for the harness shell.

        It includes emphasis, **strong text**, and a simple second paragraph.
        """,
        "anchors_and_relative_links.md": """
        # Anchors and links

        [Go to mixed document](mixed_long_document.md)

        ## Details {#details}

        A placeholder anchor section for the harness shell.
        """,
        "mixed_long_document.md": """
        # Mixed long document

        This is a longer placeholder fixture used by the harness shell.

        It contains multiple paragraphs so the app can expose visible block state.

        Another paragraph appears here to give the document some scroll depth.
        """,
        "stress_1000_blocks.md": (1...1000).map { "Paragraph \($0)" }.joined(separator: "\n\n"),
    ]
}

struct LocalWorkspaceProvider: WorkspaceProvider, Sendable {
    let rootURL: URL?
    let embeddedDocs: [String: String]

    var displayRoot: String {
        if let rootURL {
            return normalizedDisplayRoot(for: rootURL)
        }
        return "Fixtures/docs"
    }

    nonisolated func loadRoot() throws -> Workspace {
        if let rootURL {
            return Workspace(
                rootIdentifier: normalizedDisplayRoot(for: rootURL),
                files: try markdownFiles(in: rootURL)
            )
        }

        let files = embeddedDocs.keys.sorted().map { key in
            MarkdownFileNode(path: WorkspacePath(rawValue: key), name: key)
        }
        return Workspace(rootIdentifier: "Fixtures/docs", files: files)
    }

    nonisolated func readFile(at path: WorkspacePath) throws -> String {
        if let rootURL {
            let url = rootURL.appendingPathComponent(path.rawValue)
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
            throw WorkspaceProviderError.fileNotFound(path)
        }
        if let text = embeddedDocs[path.rawValue] {
            return text
        }
        throw WorkspaceProviderError.fileNotFound(path)
    }

    nonisolated func resolveMediaURL(for path: WorkspacePath) throws -> URL {
        if let rootURL {
            return rootURL.appendingPathComponent(path.rawValue).standardizedFileURL
        }
        throw WorkspaceProviderError.rootMissing(path.rawValue)
    }

    private nonisolated func markdownFiles(in rootURL: URL) throws -> [MarkdownFileNode] {
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            throw WorkspaceProviderError.rootMissing(rootURL.path)
        }

        let canonicalRootPath = canonicalPath(for: rootURL)
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        )

        var result: [MarkdownFileNode] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            let canonicalFilePath = canonicalPath(for: fileURL)
            guard canonicalFilePath.hasPrefix(canonicalRootPath + "/") else { continue }
            let relative = String(canonicalFilePath.dropFirst(canonicalRootPath.count + 1))
            result.append(MarkdownFileNode(path: WorkspacePath(rawValue: relative), name: relative))
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private nonisolated func canonicalPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private nonisolated func normalizedDisplayRoot(for rootURL: URL) -> String {
        if rootURL.lastPathComponent == "docs", rootURL.deletingLastPathComponent().lastPathComponent == "Fixtures" {
            return "Fixtures/docs"
        }
        return rootURL.lastPathComponent
    }
}
