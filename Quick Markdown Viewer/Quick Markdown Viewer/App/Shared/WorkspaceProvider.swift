import Foundation

protocol WorkspaceProvider: Sendable {
    var displayRoot: String { get }
    nonisolated func loadRoot() throws -> Workspace
    nonisolated func readFile(at path: WorkspacePath) throws -> String
    nonisolated func resolveMediaURL(for path: WorkspacePath) throws -> URL
    nonisolated func resolveMediaURL(for sourceURL: String, relativeTo documentPath: WorkspacePath?) throws -> URL
}

enum WorkspaceProviderError: Error {
    case fileNotFound(WorkspacePath)
    case rootMissing(String)
}

nonisolated struct WorkspaceIgnorePatterns: Codable, Equatable, Sendable {
    static let defaultValues = ["node_modules", "venv", ".venv", "vendor"]
    static let `default` = WorkspaceIgnorePatterns(patterns: defaultValues)

    let patterns: [String]

    init(patterns: [String] = defaultValues) {
        self.patterns = Self.normalizedPatterns(from: patterns)
    }

    init(commaSeparated value: String) {
        self.init(patterns: value.split(separator: ",").map(String.init))
    }

    var commaSeparated: String {
        patterns.joined(separator: ", ")
    }

    func shouldIgnore(relativePath: String) -> Bool {
        let path = Self.normalizedPath(relativePath)
        guard !path.isEmpty else { return false }
        let components = path.split(separator: "/").map(String.init)

        return patterns.contains { pattern in
            if Self.hasWildcard(pattern) {
                return Self.matchesWildcard(pattern: pattern, value: path)
                    || components.contains { Self.matchesWildcard(pattern: pattern, value: $0) }
            }
            if pattern.contains("/") {
                return path == pattern || path.hasPrefix(pattern + "/")
            }
            return components.contains(pattern)
        }
    }

    private static func normalizedPatterns(from values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values {
            let pattern = normalizedPath(value)
            guard !pattern.isEmpty, !seen.contains(pattern) else { continue }
            seen.insert(pattern)
            result.append(pattern)
        }

        return result
    }

    private static func normalizedPath(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func hasWildcard(_ pattern: String) -> Bool {
        pattern.contains("*") || pattern.contains("?")
    }

    private static func matchesWildcard(pattern: String, value: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        return value.range(of: "^\(escaped)$", options: .regularExpression) != nil
    }
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

enum SupportedDocumentExtensions {
    nonisolated static let all: Set<String> = [
        "md",
        "markdown",
        "mdown",
        "mkd",
        "mkdn",
        "mermaid",
        "mmd",
        "csv",
        "tsv",
        "json",
        "jsonc",
        "ndjson",
        "jsonl",
    ]

    nonisolated static func contains(_ fileExtension: String) -> Bool {
        all.contains(fileExtension.lowercased())
    }
}

struct LocalWorkspaceProvider: WorkspaceProvider, Sendable {
    let rootURL: URL?
    let explicitFileURL: URL?
    let embeddedDocs: [String: String]
    let ignorePatterns: WorkspaceIgnorePatterns

    init(
        rootURL: URL?,
        explicitFileURL: URL? = nil,
        embeddedDocs: [String: String],
        ignorePatterns: WorkspaceIgnorePatterns = .default
    ) {
        self.rootURL = rootURL
        self.explicitFileURL = explicitFileURL?.resolvingSymlinksInPath().standardizedFileURL
        self.embeddedDocs = embeddedDocs
        self.ignorePatterns = ignorePatterns
    }

    var displayRoot: String {
        if let rootURL {
            return normalizedDisplayRoot(for: rootURL)
        }
        return "Fixtures/docs"
    }

    nonisolated func loadRoot() throws -> Workspace {
        if let rootURL {
            let rootIdentifier = normalizedDisplayRoot(for: rootURL)
            let discoveredFiles: [MarkdownFileNode]
            do {
                discoveredFiles = try markdownFiles(in: rootURL)
            } catch {
                if let explicitFile = explicitFileNode(rootURL: rootURL) {
                    return Workspace(rootIdentifier: rootIdentifier, files: [explicitFile])
                }
                throw error
            }
            guard let explicitFile = explicitFileNode(rootURL: rootURL),
                  discoveredFiles.contains(where: { $0.path == explicitFile.path }) == false else {
                return Workspace(rootIdentifier: rootIdentifier, files: discoveredFiles)
            }
            let files = (discoveredFiles + [explicitFile])
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return Workspace(
                rootIdentifier: rootIdentifier,
                files: files
            )
        }

        let files = embeddedDocs.keys.sorted().map { key in
            MarkdownFileNode(
                path: WorkspacePath(rawValue: key),
                name: key,
                kind: WorkspaceDocumentKind.forPath(key) ?? .markdown
            )
        }
        return Workspace(rootIdentifier: "Fixtures/docs", files: files)
    }

    nonisolated func readFile(at path: WorkspacePath) throws -> String {
        if let explicitFileURL,
           explicitFileNode(rootURL: rootURL)?.path == path {
            return try readTextFile(at: explicitFileURL, path: path)
        }
        if let rootURL {
            let url = rootURL.appendingPathComponent(path.rawValue)
            return try readTextFile(at: url, path: path)
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

    nonisolated func resolveMediaURL(for sourceURL: String, relativeTo documentPath: WorkspacePath?) throws -> URL {
        if let absoluteURL = Self.absoluteMediaURL(from: sourceURL) {
            return absoluteURL
        }

        guard let rootURL else {
            throw WorkspaceProviderError.rootMissing(sourceURL)
        }

        let documentDirectoryPath = documentPath.map { ($0.rawValue as NSString).deletingLastPathComponent } ?? ""
        let workspaceRelativePath = documentDirectoryPath.isEmpty
            ? (sourceURL as NSString)
            : (documentDirectoryPath as NSString).appendingPathComponent(sourceURL) as NSString
        let normalizedRelativePath = workspaceRelativePath.standardizingPath
        return rootURL.appendingPathComponent(normalizedRelativePath).standardizedFileURL
    }

    private nonisolated func markdownFiles(in rootURL: URL) throws -> [MarkdownFileNode] {
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            throw WorkspaceProviderError.rootMissing(rootURL.path)
        }

        let rootPath = rootURL.standardizedFileURL.path
        let canonicalRootPath = canonicalPath(for: rootURL)
        let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        )

        var result: [MarkdownFileNode] = []
        while let fileURL = enumerator?.nextObject() as? URL {
            let filteringRelativePath = relativePath(for: fileURL, rootPath: rootPath)
            if ignorePatterns.shouldIgnore(relativePath: filteringRelativePath) {
                if fileURL.hasDirectoryPath {
                    enumerator?.skipDescendants()
                }
                continue
            }

            if fileURL.hasDirectoryPath { continue }
            guard SupportedDocumentExtensions.contains(fileURL.pathExtension) else { continue }

            let canonicalFilePath = canonicalPath(for: fileURL)
            guard canonicalFilePath.hasPrefix(canonicalRootPath + "/") else { continue }
            let relative = String(canonicalFilePath.dropFirst(canonicalRootPath.count + 1))
            let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            guard resourceValues?.isRegularFile == true else { continue }
            guard let kind = WorkspaceDocumentKind.forPath(relative) else { continue }
            result.append(MarkdownFileNode(path: WorkspacePath(rawValue: relative), name: relative, kind: kind))
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private nonisolated func explicitFileNode(rootURL: URL?) -> MarkdownFileNode? {
        guard let rootURL, let explicitFileURL else { return nil }
        guard let kind = WorkspaceDocumentKind.forPath(explicitFileURL.path) else { return nil }
        let canonicalRootPath = canonicalPath(for: rootURL)
        let canonicalFilePath = canonicalPath(for: explicitFileURL)
        guard canonicalFilePath.hasPrefix(canonicalRootPath + "/") else { return nil }
        let relative = String(canonicalFilePath.dropFirst(canonicalRootPath.count + 1))
        guard ignorePatterns.shouldIgnore(relativePath: relative) == false else { return nil }
        return MarkdownFileNode(path: WorkspacePath(rawValue: relative), name: relative, kind: kind)
    }

    private nonisolated func readTextFile(at url: URL, path: WorkspacePath) throws -> String {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw WorkspaceProviderError.fileNotFound(path)
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .utf16) {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        return String(decoding: data, as: UTF8.self)
    }

    private nonisolated func canonicalPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private nonisolated func relativePath(for url: URL, rootPath: String) -> String {
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return path }
        return String(path.dropFirst(rootPath.count + 1))
    }

    private nonisolated func normalizedDisplayRoot(for rootURL: URL) -> String {
        if rootURL.lastPathComponent == "docs", rootURL.deletingLastPathComponent().lastPathComponent == "Fixtures" {
            return "Fixtures/docs"
        }
        return rootURL.lastPathComponent
    }

    nonisolated static func absoluteMediaURL(from sourceURL: String) -> URL? {
        guard let url = URL(string: sourceURL), let scheme = url.scheme, !scheme.isEmpty else {
            return nil
        }
        guard url.isFileURL || url.host != nil else {
            return nil
        }
        return url
    }
}
