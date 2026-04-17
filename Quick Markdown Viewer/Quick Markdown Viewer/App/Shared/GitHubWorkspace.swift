import Foundation

struct GitHubWorkspaceDescriptor: Codable, Equatable, Sendable {
    let originalURLString: String
    let owner: String
    let repository: String
    let requestedRef: String
    let resolvedCommitSHA: String
    let subdirectory: String?
    let displayRoot: String

    nonisolated var normalizedOriginalURLString: String {
        Self.normalizeOriginalURLString(originalURLString)
    }

    nonisolated func rawContentURL(for workspaceRelativePath: String) -> URL {
        let repoRelativePath = repositoryRelativePath(for: workspaceRelativePath)
        return URL(string: "https://raw.githubusercontent.com/\(owner)/\(repository)/\(resolvedCommitSHA)/\(repoRelativePath)")!
    }

    nonisolated func repositoryRelativePath(for workspaceRelativePath: String) -> String {
        let sanitizedPath = workspaceRelativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let subdirectory, !subdirectory.isEmpty {
            if sanitizedPath.isEmpty {
                return subdirectory
            }
            return "\(subdirectory)/\(sanitizedPath)"
        }
        return sanitizedPath
    }

    private nonisolated static func normalizeOriginalURLString(_ rawValue: String) -> String {
        guard var components = URLComponents(string: rawValue) else { return rawValue }
        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + trimmedPath
        components.query = nil
        components.fragment = nil
        return components.string ?? rawValue
    }
}

struct CachedGitHubWorkspace: Equatable, Sendable {
    let descriptor: GitHubWorkspaceDescriptor
    let cacheRootURL: URL
}

protocol GitHubWorkspaceLoading: Sendable {
    func loadWorkspace(from rawURLString: String) async throws -> CachedGitHubWorkspace
}

protocol GitHubRemoteClientProtocol: Sendable {
    func repositoryMetadata(owner: String, repository: String) async throws -> GitHubRepositoryMetadata
    func commitSHA(owner: String, repository: String, ref: String) async throws -> String
    func treeEntries(owner: String, repository: String, commitSHA: String) async throws -> [GitHubTreeEntry]
    func fileData(owner: String, repository: String, commitSHA: String, path: String) async throws -> Data
}

struct GitHubRepositoryMetadata: Codable, Equatable, Sendable {
    let defaultBranch: String

    enum CodingKeys: String, CodingKey {
        case defaultBranch = "default_branch"
    }
}

struct GitHubTreeEntry: Codable, Equatable, Sendable {
    let path: String
    let type: String
}

enum GitHubWorkspaceError: LocalizedError, Equatable {
    case invalidURL
    case unsupportedHost
    case unsupportedPath
    case missingTreeReference
    case refNotFound(String)
    case subdirectoryNotFound(String)
    case missingCachedWorkspace
    case missingMarkdownContent
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid GitHub repository URL."
        case .unsupportedHost:
            return "Only public github.com repository URLs are supported."
        case .unsupportedPath:
            return "Only repository and tree URLs are supported."
        case .missingTreeReference:
            return "Tree URLs must include a branch or tag."
        case let .refNotFound(ref):
            return "GitHub ref not found: \(ref)"
        case let .subdirectoryNotFound(path):
            return "GitHub path not found: \(path)"
        case .missingCachedWorkspace:
            return "Cached GitHub workspace is unavailable."
        case .missingMarkdownContent:
            return "No Markdown files were found in that GitHub path."
        case let .httpStatus(statusCode):
            return "GitHub request failed with HTTP \(statusCode)."
        }
    }
}

struct GitHubWorkspaceProvider: WorkspaceProvider {
    let cachedRootURL: URL
    let descriptor: GitHubWorkspaceDescriptor

    var displayRoot: String {
        descriptor.displayRoot
    }

    nonisolated func loadRoot() throws -> Workspace {
        Workspace(
            rootIdentifier: descriptor.displayRoot,
            files: try markdownFiles(in: cachedRootURL)
        )
    }

    nonisolated func readFile(at path: WorkspacePath) throws -> String {
        let fileURL = cachedRootURL.appendingPathComponent(path.rawValue)
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw WorkspaceProviderError.fileNotFound(path)
        }
        return text
    }

    nonisolated func resolveMediaURL(for path: WorkspacePath) throws -> URL {
        try resolveWorkspaceURL(forRelativePath: path.rawValue)
    }

    nonisolated func resolveMediaURL(for sourceURL: String, relativeTo documentPath: WorkspacePath?) throws -> URL {
        if let absoluteURL = LocalWorkspaceProvider.absoluteMediaURL(from: sourceURL) {
            return absoluteURL
        }

        let documentDirectoryPath = documentPath.map { ($0.rawValue as NSString).deletingLastPathComponent } ?? ""
        let workspaceRelativePath = documentDirectoryPath.isEmpty
            ? (sourceURL as NSString)
            : (documentDirectoryPath as NSString).appendingPathComponent(sourceURL) as NSString
        return try resolveWorkspaceURL(forRelativePath: workspaceRelativePath.standardizingPath)
    }

    private nonisolated func resolveWorkspaceURL(forRelativePath path: String) throws -> URL {
        let sanitizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !sanitizedPath.isEmpty else {
            throw WorkspaceProviderError.fileNotFound(WorkspacePath(rawValue: path))
        }

        let localURL = cachedRootURL.appendingPathComponent(sanitizedPath).standardizedFileURL
        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        return descriptor.rawContentURL(for: sanitizedPath)
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
            guard SupportedMarkdownExtensions.contains(fileURL.pathExtension) else { continue }
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
}

struct GitHubWorkspaceSessionSource: Codable, Equatable, Sendable {
    let originalURLString: String
    let cachedRootPath: String
    let descriptor: GitHubWorkspaceDescriptor
}

struct GitHubWorkspaceService: GitHubWorkspaceLoading {
    private let remoteClient: any GitHubRemoteClientProtocol
    private let fileManager: FileManager
    private let cacheDirectoryURL: URL

    init(
        remoteClient: any GitHubRemoteClientProtocol,
        fileManager: FileManager = .default,
        cacheDirectoryURL: URL? = nil
    ) {
        self.remoteClient = remoteClient
        self.fileManager = fileManager
        self.cacheDirectoryURL = cacheDirectoryURL ?? Self.defaultCacheDirectoryURL(fileManager: fileManager)
    }

    nonisolated static func live(fileManager: FileManager = .default) -> GitHubWorkspaceService {
        GitHubWorkspaceService(remoteClient: LiveGitHubRemoteClient(), fileManager: fileManager)
    }

    nonisolated static func makeDefault(launchOptions: HarnessLaunchOptions, fileManager: FileManager = .default) -> GitHubWorkspaceService {
        if let fixtureURL = launchOptions.uiTestGitHubFixtureURL {
            if let fixtureClient = try? FixtureGitHubRemoteClient(fixtureURL: fixtureURL) {
                return GitHubWorkspaceService(remoteClient: fixtureClient, fileManager: fileManager)
            }
        }
        return .live(fileManager: fileManager)
    }

    func loadWorkspace(from rawURLString: String) async throws -> CachedGitHubWorkspace {
        let request = try GitHubWorkspaceRequest.parse(rawURLString)

        do {
            let resolvedWorkspace = try await resolveWorkspace(for: request)
            try storeAlias(
                GitHubWorkspaceAlias(
                    originalURLString: request.canonicalURLString,
                    cachedRootPath: resolvedWorkspace.cacheRootURL.path,
                    descriptor: resolvedWorkspace.descriptor
                )
            )
            return resolvedWorkspace
        } catch {
            if let cachedWorkspace = try loadCachedWorkspace(forCanonicalURLString: request.canonicalURLString) {
                return cachedWorkspace
            }
            throw error
        }
    }

    private func resolveWorkspace(for request: GitHubWorkspaceRequest) async throws -> CachedGitHubWorkspace {
        let metadata = try await remoteClient.repositoryMetadata(owner: request.owner, repository: request.repository)
        let resolution = try await resolveReference(
            owner: request.owner,
            repository: request.repository,
            metadata: metadata,
            request: request
        )

        let treeEntries = try await remoteClient.treeEntries(
            owner: request.owner,
            repository: request.repository,
            commitSHA: resolution.commitSHA
        )

        let subtreeEntries = try entries(
            in: treeEntries,
            forSubdirectory: resolution.subdirectory
        )

        let descriptor = GitHubWorkspaceDescriptor(
            originalURLString: request.canonicalURLString,
            owner: request.owner,
            repository: request.repository,
            requestedRef: resolution.requestedRef,
            resolvedCommitSHA: resolution.commitSHA,
            subdirectory: resolution.subdirectory,
            displayRoot: displayRoot(
                owner: request.owner,
                repository: request.repository,
                requestedRef: resolution.requestedRef,
                subdirectory: resolution.subdirectory
            )
        )

        let cacheRootURL = cacheDirectoryURL
            .appendingPathComponent("\(request.owner)--\(request.repository)", isDirectory: true)
            .appendingPathComponent(resolution.commitSHA, isDirectory: true)

        try fileManager.createDirectory(at: cacheRootURL, withIntermediateDirectories: true)
        try await cacheMarkdownFiles(
            subtreeEntries: subtreeEntries,
            owner: request.owner,
            repository: request.repository,
            commitSHA: resolution.commitSHA,
            subdirectory: resolution.subdirectory,
            cacheRootURL: cacheRootURL
        )

        return CachedGitHubWorkspace(
            descriptor: descriptor,
            cacheRootURL: cacheRootURL
        )
    }

    private func resolveReference(
        owner: String,
        repository: String,
        metadata: GitHubRepositoryMetadata,
        request: GitHubWorkspaceRequest
    ) async throws -> GitHubReferenceResolution {
        guard let treeSegments = request.treeSegments else {
            let commitSHA = try await remoteClient.commitSHA(
                owner: owner,
                repository: repository,
                ref: metadata.defaultBranch
            )
            return GitHubReferenceResolution(
                requestedRef: metadata.defaultBranch,
                commitSHA: commitSHA,
                subdirectory: nil
            )
        }

        guard !treeSegments.isEmpty else {
            throw GitHubWorkspaceError.missingTreeReference
        }

        for candidateLength in stride(from: treeSegments.count, through: 1, by: -1) {
            let candidateRef = treeSegments.prefix(candidateLength).joined(separator: "/")
            do {
                let commitSHA = try await remoteClient.commitSHA(
                    owner: owner,
                    repository: repository,
                    ref: candidateRef
                )
                let remainingPath = Array(treeSegments.dropFirst(candidateLength)).joined(separator: "/")
                return GitHubReferenceResolution(
                    requestedRef: candidateRef,
                    commitSHA: commitSHA,
                    subdirectory: remainingPath.isEmpty ? nil : remainingPath
                )
            } catch {
                continue
            }
        }

        throw GitHubWorkspaceError.refNotFound(treeSegments.joined(separator: "/"))
    }

    private func entries(
        in treeEntries: [GitHubTreeEntry],
        forSubdirectory subdirectory: String?
    ) throws -> [GitHubTreeEntry] {
        guard let subdirectory, !subdirectory.isEmpty else {
            return treeEntries.filter { $0.type == "blob" }
        }

        let normalizedPrefix = subdirectory + "/"
        let matchingEntries = treeEntries.filter { entry in
            entry.type == "blob" && entry.path.hasPrefix(normalizedPrefix)
        }

        guard !matchingEntries.isEmpty || treeEntries.contains(where: { $0.path == subdirectory }) else {
            throw GitHubWorkspaceError.subdirectoryNotFound(subdirectory)
        }

        return matchingEntries
    }

    private func cacheMarkdownFiles(
        subtreeEntries: [GitHubTreeEntry],
        owner: String,
        repository: String,
        commitSHA: String,
        subdirectory: String?,
        cacheRootURL: URL
    ) async throws {
        let markdownEntries = subtreeEntries.filter { entry in
            SupportedMarkdownExtensions.contains((entry.path as NSString).pathExtension)
        }

        guard !markdownEntries.isEmpty else {
            throw GitHubWorkspaceError.missingMarkdownContent
        }

        for entry in markdownEntries {
            let relativePath = workspaceRelativePath(for: entry.path, subdirectory: subdirectory)
            let destinationURL = cacheRootURL.appendingPathComponent(relativePath)
            if fileManager.fileExists(atPath: destinationURL.path) {
                continue
            }

            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try await remoteClient.fileData(
                owner: owner,
                repository: repository,
                commitSHA: commitSHA,
                path: entry.path
            )
            try data.write(to: destinationURL, options: .atomic)
        }
    }

    private func loadCachedWorkspace(forCanonicalURLString canonicalURLString: String) throws -> CachedGitHubWorkspace? {
        let aliases = try loadAliases()
        guard let alias = aliases[canonicalURLString] else { return nil }

        let cacheRootURL = URL(fileURLWithPath: alias.cachedRootPath, isDirectory: true)
        guard fileManager.fileExists(atPath: cacheRootURL.path) else {
            return nil
        }

        return CachedGitHubWorkspace(
            descriptor: alias.descriptor,
            cacheRootURL: cacheRootURL
        )
    }

    private func loadAliases() throws -> [String: GitHubWorkspaceAlias] {
        let aliasURL = aliasFileURL
        guard fileManager.fileExists(atPath: aliasURL.path) else { return [:] }
        let data = try Data(contentsOf: aliasURL)
        return try JSONDecoder().decode([String: GitHubWorkspaceAlias].self, from: data)
    }

    private func storeAlias(_ alias: GitHubWorkspaceAlias) throws {
        try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        var aliases = try loadAliases()
        aliases[alias.originalURLString] = alias
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(aliases)
        try data.write(to: aliasFileURL, options: Data.WritingOptions.atomic)
    }

    private var aliasFileURL: URL {
        cacheDirectoryURL.appendingPathComponent("aliases.json")
    }

    private func displayRoot(
        owner: String,
        repository: String,
        requestedRef: String,
        subdirectory: String?
    ) -> String {
        if let subdirectory, !subdirectory.isEmpty {
            return "\(owner)/\(repository)@\(requestedRef)/\(subdirectory)"
        }
        return "\(owner)/\(repository)@\(requestedRef)"
    }

    private func workspaceRelativePath(for repositoryPath: String, subdirectory: String?) -> String {
        guard let subdirectory, !subdirectory.isEmpty else { return repositoryPath }
        return String(repositoryPath.dropFirst(subdirectory.count + 1))
    }

    private static func defaultCacheDirectoryURL(fileManager: FileManager) -> URL {
        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseDirectory.appendingPathComponent("GitHubWorkspaces", isDirectory: true)
    }
}

private struct GitHubWorkspaceRequest: Equatable, Sendable {
    let canonicalURLString: String
    let owner: String
    let repository: String
    let treeSegments: [String]?

    static func parse(_ rawURLString: String) throws -> GitHubWorkspaceRequest {
        guard let url = URL(string: rawURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw GitHubWorkspaceError.invalidURL
        }

        guard components.scheme?.lowercased() == "https" else {
            throw GitHubWorkspaceError.invalidURL
        }
        guard components.host?.lowercased() == "github.com" else {
            throw GitHubWorkspaceError.unsupportedHost
        }

        let pathSegments = components.path.split(separator: "/").map(String.init)
        guard pathSegments.count >= 2 else {
            throw GitHubWorkspaceError.unsupportedPath
        }

        let owner = pathSegments[0]
        let repository = pathSegments[1]
        let remainingSegments = Array(pathSegments.dropFirst(2))
        let treeSegments: [String]?
        if remainingSegments.isEmpty {
            treeSegments = nil
        } else if remainingSegments.first == "tree" {
            let tail = Array(remainingSegments.dropFirst())
            guard !tail.isEmpty else {
                throw GitHubWorkspaceError.missingTreeReference
            }
            treeSegments = tail
        } else {
            throw GitHubWorkspaceError.unsupportedPath
        }

        components.path = "/\(owner)/\(repository)" + (treeSegments.map { "/tree/" + $0.joined(separator: "/") } ?? "")
        components.query = nil
        components.fragment = nil
        let canonicalURLString = components.string ?? rawURLString

        return GitHubWorkspaceRequest(
            canonicalURLString: canonicalURLString,
            owner: owner,
            repository: repository,
            treeSegments: treeSegments
        )
    }
}

private struct GitHubReferenceResolution: Equatable, Sendable {
    let requestedRef: String
    let commitSHA: String
    let subdirectory: String?
}

private struct GitHubWorkspaceAlias: Codable, Equatable, Sendable {
    let originalURLString: String
    let cachedRootPath: String
    let descriptor: GitHubWorkspaceDescriptor
}

private struct LiveGitHubRemoteClient: GitHubRemoteClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func repositoryMetadata(owner: String, repository: String) async throws -> GitHubRepositoryMetadata {
        let url = try apiURL(path: "/repos/\(owner)/\(repository)")
        let request = configuredRequest(for: url)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(GitHubRepositoryMetadata.self, from: data)
    }

    func commitSHA(owner: String, repository: String, ref: String) async throws -> String {
        let encodedRef = ref.addingPercentEncoding(withAllowedCharacters: .githubPathComponentAllowed) ?? ref
        let url = try apiURL(path: "/repos/\(owner)/\(repository)/commits/\(encodedRef)")
        let request = configuredRequest(for: url)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        let payload = try JSONDecoder().decode(GitHubCommitPayload.self, from: data)
        return payload.sha
    }

    func treeEntries(owner: String, repository: String, commitSHA: String) async throws -> [GitHubTreeEntry] {
        var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repository)/git/trees/\(commitSHA)")!
        components.queryItems = [URLQueryItem(name: "recursive", value: "1")]
        let request = configuredRequest(for: components.url!)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        let payload = try JSONDecoder().decode(GitHubTreePayload.self, from: data)
        return payload.tree
    }

    func fileData(owner: String, repository: String, commitSHA: String, path: String) async throws -> Data {
        let encodedPath = path
            .split(separator: "/")
            .map { segment in
                String(segment).addingPercentEncoding(withAllowedCharacters: .githubPathComponentAllowed) ?? String(segment)
            }
            .joined(separator: "/")
        let url = URL(string: "https://raw.githubusercontent.com/\(owner)/\(repository)/\(commitSHA)/\(encodedPath)")!
        let (data, response) = try await session.data(for: URLRequest(url: url))
        try validate(response: response)
        return data
    }

    private func apiURL(path: String) throws -> URL {
        guard let url = URL(string: "https://api.github.com\(path)") else {
            throw GitHubWorkspaceError.invalidURL
        }
        return url
    }

    private func configuredRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("QuickMarkdownViewer", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw GitHubWorkspaceError.httpStatus(httpResponse.statusCode)
        }
    }
}

private struct GitHubCommitPayload: Codable {
    let sha: String
}

private struct GitHubTreePayload: Codable {
    let tree: [GitHubTreeEntry]
}

struct FixtureGitHubRemoteClient: GitHubRemoteClientProtocol {
    private let fixture: GitHubFixtureDocument

    init(fixtureURL: URL) throws {
        let data = try Data(contentsOf: fixtureURL)
        fixture = try JSONDecoder().decode(GitHubFixtureDocument.self, from: data)
    }

    func repositoryMetadata(owner: String, repository: String) async throws -> GitHubRepositoryMetadata {
        let key = "\(owner)/\(repository)"
        guard let metadata = fixture.repositories[key] else {
            throw GitHubWorkspaceError.refNotFound(key)
        }
        return metadata
    }

    func commitSHA(owner: String, repository: String, ref: String) async throws -> String {
        let key = "\(owner)/\(repository)"
        guard let commitSHA = fixture.commits[key]?[ref] else {
            throw GitHubWorkspaceError.refNotFound(ref)
        }
        return commitSHA
    }

    func treeEntries(owner: String, repository: String, commitSHA: String) async throws -> [GitHubTreeEntry] {
        let key = "\(owner)/\(repository)"
        return fixture.trees[key]?[commitSHA] ?? []
    }

    func fileData(owner: String, repository: String, commitSHA: String, path: String) async throws -> Data {
        let key = "\(owner)/\(repository)"
        guard let contents = fixture.files[key]?[commitSHA]?[path] else {
            throw GitHubWorkspaceError.subdirectoryNotFound(path)
        }
        return Data(contents.utf8)
    }
}

struct GitHubFixtureDocument: Codable {
    let repositories: [String: GitHubRepositoryMetadata]
    let commits: [String: [String: String]]
    let trees: [String: [String: [GitHubTreeEntry]]]
    let files: [String: [String: [String: String]]]
}

private extension CharacterSet {
    static let githubPathComponentAllowed: CharacterSet = {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return allowed
    }()
}
