import Foundation

// MARK: - Registry Error

enum RegistryError: LocalizedError {
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from registry"
        case .decodingError(let error): return "Failed to decode: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Registry Service

actor RegistryService {
    private static let baseURL = URL(string: "https://registry.modelcontextprotocol.io/v0.1/servers")!
    private let session: URLSession
    
    // Registres disponibles
    let availableRegistries = MCPRegistry.defaultRegistries
    
    // Registre actif (par défaut: Official MCP Registry)
    private var activeRegistry: MCPRegistry = MCPRegistry.defaultRegistries[0]
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func setActiveRegistry(_ registry: MCPRegistry) {
        activeRegistry = registry
    }
    
    func getActiveRegistry() -> MCPRegistry {
        return activeRegistry
    }
    
    func getAllRegistries() -> [MCPRegistry] {
        return availableRegistries
    }
    
    /// Fetch servers with pagination support
    func fetchServers(cursor: String? = nil, limit: Int = 100) async throws -> (servers: [MCPServer], nextCursor: String?) {
        guard var urlComponents = URLComponents(url: Self.baseURL, resolvingAgainstBaseURL: false) else {
            throw RegistryError.invalidResponse
        }
        
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "limit", value: String(limit))]
        
        if let cursor = cursor {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        
        urlComponents.queryItems = queryItems
        
        guard let requestURL = urlComponents.url else {
            throw RegistryError.invalidResponse
        }
        
        let (data, response) = try await session.data(from: requestURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw RegistryError.invalidResponse
        }
        
        let registryResponse = try JSONDecoder().decode(RegistryResponse.self, from: data)
        let servers = registryResponse.servers.map { $0.server }
        
        return (servers, registryResponse.metadata.nextCursor)
    }
    
    /// Fetch all servers (handles pagination automatically)
    func fetchAllServers(from registry: MCPRegistry? = nil) async throws -> [MCPServer] {
        var allServers: [MCPServer] = []
        var cursor: String? = nil
        
        repeat {
            let result = try await fetchServers(cursor: cursor)
            allServers.append(contentsOf: result.servers)
            cursor = result.nextCursor
        } while cursor != nil
        
        // Deduplicate by repository URL, keeping the entry with newest version
        return deduplicateByRepository(allServers)
    }
    
    /// Deduplicate servers by repository URL, keeping the entry with the newest version
    private func deduplicateByRepository(_ servers: [MCPServer]) -> [MCPServer] {
        var bestByRepo: [String: MCPServer] = [:]
        var noRepoServers: [String: MCPServer] = [:]
        
        for server in servers {
            guard let repoUrl = server.repository?.url else {
                // No repo URL - dedupe by name
                if noRepoServers[server.name] == nil {
                    noRepoServers[server.name] = server
                }
                continue
            }
            
            // Normalize repo URL (remove .git suffix, trailing slashes)
            let normalized = repoUrl
                .replacingOccurrences(of: ".git", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .lowercased()
            
            if let existing = bestByRepo[normalized] {
                // Keep the one with higher version (or more packages as tiebreaker)
                let serverVersion = server.version ?? ""
                let existingVersion = existing.version ?? ""
                if serverVersion.compare(existingVersion, options: .numeric) == .orderedDescending {
                    bestByRepo[normalized] = server
                } else if serverVersion == existingVersion && server.packages.count > existing.packages.count {
                    bestByRepo[normalized] = server
                }
            } else {
                bestByRepo[normalized] = server
            }
        }
        
        return Array(bestByRepo.values) + Array(noRepoServers.values)
    }
    
    func searchServers(query: String, in registry: MCPRegistry? = nil) async throws -> [MCPServer] {
        let allServers = try await fetchAllServers(from: registry)
        let lowercaseQuery = query.lowercased()
        
        return allServers.filter { server in
            server.name.lowercased().contains(lowercaseQuery) ||
            (server.description?.lowercased().contains(lowercaseQuery) ?? false) ||
            (server.displayName.lowercased().contains(lowercaseQuery))
        }
    }
}

// MARK: - GitHub Metadata Service

/// Service for fetching GitHub metadata from the josh.ing API
actor GitHubMetadataService {
    private let baseURL = "https://www.josh.ing/api/mymcp/servers"
    private let session: URLSession

    // Session-based cache (no TTL - lives until app quits)
    private var nameCache: [String: GitHubMetadata] = [:]
    private var urlCache: [String: GitHubMetadata] = [:]
    private var hasFetched = false

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetch all metadata (paginated, ~11 calls for ~1100 servers)
    /// Returns the name-keyed cache for use in views
    func fetchAllMetadata() async throws -> [String: GitHubMetadata] {
        guard !hasFetched else { return nameCache }

        var offset = 0
        let limit = 100
        var hasMore = true

        print("📊 GitHubMetadataService: Starting fetch from josh.ing API")

        while hasMore {
            guard let url = URL(string: "\(baseURL)?limit=\(limit)&offset=\(offset)&latest_only=true") else {
                throw GitHubMetadataError.invalidURL
            }

            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("⚠️ GitHubMetadataService: Invalid response at offset \(offset)")
                throw GitHubMetadataError.invalidResponse
            }

            let decoded = try JSONDecoder().decode(JoshIngResponse.self, from: data)

            for server in decoded.servers {
                // Skip servers without GitHub data or with null stats
                guard let gh = server.github,
                      gh.stars != nil  // Skip if GitHub data couldn't be fetched
                else { continue }

                let metadata = GitHubMetadata(from: gh)

                // Dual-key indexing
                nameCache[server.name] = metadata
                if let repoUrl = server.repositoryUrl {
                    urlCache[normalizeURL(repoUrl)] = metadata
                }
            }

            hasMore = decoded.pagination.hasMore
            offset += limit
        }

        hasFetched = true
        print("✅ GitHubMetadataService: Completed fetch, cached \(nameCache.count) servers")

        return nameCache
    }

    /// Get metadata for a server by name or repository URL
    func getMetadata(forName name: String, repoURL: String?) -> GitHubMetadata? {
        if let m = nameCache[name] { return m }
        if let url = repoURL, let m = urlCache[normalizeURL(url)] { return m }
        return nil
    }

    /// Force refresh (for manual refresh button)
    func clearCache() {
        nameCache.removeAll()
        urlCache.removeAll()
        hasFetched = false
        print("🔄 GitHubMetadataService: Cache cleared")
    }

    private func normalizeURL(_ url: String) -> String {
        url.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

enum GitHubMetadataError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from josh.ing API"
        case .decodingError(let error): return "Failed to decode: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Skills Service

/// Service for fetching agent skills from Skills.sh
actor SkillsService {
    private let baseURL = "https://skills.sh"
    private let session: URLSession
    
    // Cache
    private var cachedSkills: [AgentSkill] = []
    private var hasFetched = false
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Search for skills by query
    func searchSkills(query: String) async throws -> [AgentSkill] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(baseURL)/api/search?q=\(encodedQuery)&limit=50") else {
            throw SkillsError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SkillsError.invalidResponse
        }
        
        let searchResponse = try JSONDecoder().decode(SkillsSearchResponse.self, from: data)
        return searchResponse.skills.map { $0.toAgentSkill() }
    }
    
    /// Fetch trending/popular skills (scraping leaderboard page data)
    func fetchPopularSkills() async throws -> [AgentSkill] {
        guard !hasFetched else { return cachedSkills }
        
        print("🎯 SkillsService: Fetching popular skills...")
        
        // Try to get skills from the search API with common queries
        var allSkills: [String: AgentSkill] = [:]
        
        // Fetch skills with different popular queries to build a catalog
        let popularQueries = ["react", "typescript", "python", "ai", "frontend", "backend", "testing", "git", "docker", "aws", "design", "code", "api", "database"]
        
        for query in popularQueries {
            do {
                let skills = try await searchSkills(query: query)
                for skill in skills {
                    allSkills[skill.id] = skill
                }
            } catch {
                // Continue with other queries
                print("⚠️ SkillsService: Query '\(query)' failed: \(error.localizedDescription)")
            }
        }
        
        // Also try empty query for general list
        do {
            let generalSkills = try await searchSkills(query: "")
            for skill in generalSkills {
                allSkills[skill.id] = skill
            }
        } catch {
            // Ignore
        }
        
        cachedSkills = Array(allSkills.values).sorted { $0.installs > $1.installs }
        hasFetched = true
        
        print("✅ SkillsService: Loaded \(cachedSkills.count) skills")
        
        return cachedSkills
    }
    
    /// Get all cached skills
    func getAllSkills() -> [AgentSkill] {
        return cachedSkills
    }
    
    /// Clear cache for refresh
    func clearCache() {
        cachedSkills.removeAll()
        hasFetched = false
        print("🔄 SkillsService: Cache cleared")
    }
    
    /// Install a skill to specified agents
    func installSkill(_ skill: AgentSkill, toAgents agents: [String]) async throws {
        // Skills are installed via CLI, so we just provide the command
        // The actual installation happens via terminal
        print("📦 SkillsService: Install command: \(skill.installCommand)")
    }
}

enum SkillsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case notFound
    case installationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from Skills API"
        case .notFound: return "Skill not found"
        case .installationFailed(let msg): return "Installation failed: \(msg)"
        }
    }
}

// MARK: - SkillsMP Service

/// Service for fetching skills from SkillsMP.com (105K+ skills)
actor SkillsMPService {
    private let baseURL = "https://skillsmp.com/api/v1/skills"
    private let session: URLSession
    
    // Cache
    private var cachedSkills: [AgentSkill] = []
    private var hasFetched = false
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Search for skills by query
    func searchSkills(query: String, page: Int = 1, limit: Int = 50, sortBy: String = "stars") async throws -> [AgentSkill] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(baseURL)/search?q=\(encodedQuery)&page=\(page)&limit=\(limit)&sortBy=\(sortBy)") else {
            throw SkillsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SkillsError.invalidResponse
        }
        
        let searchResponse = try JSONDecoder().decode(SkillsMPSearchResponse.self, from: data)
        return searchResponse.skills.map { $0.toAgentSkill(source: "SkillsMP") }
    }
    
    /// Fetch popular skills
    func fetchPopularSkills() async throws -> [AgentSkill] {
        guard !hasFetched else { return cachedSkills }
        
        print("🎯 SkillsMPService: Fetching popular skills...")
        
        var allSkills: [String: AgentSkill] = [:]
        
        // Fetch with different queries
        let popularQueries = ["ai", "react", "python", "typescript", "code"]
        
        for query in popularQueries {
            do {
                let skills = try await searchSkills(query: query, limit: 100)
                for skill in skills {
                    allSkills[skill.id] = skill
                }
            } catch {
                print("⚠️ SkillsMPService: Query '\(query)' failed: \(error.localizedDescription)")
            }
        }
        
        cachedSkills = Array(allSkills.values).sorted { $0.installs > $1.installs }
        hasFetched = true
        
        print("✅ SkillsMPService: Loaded \(cachedSkills.count) skills")
        
        return cachedSkills
    }
    
    func getAllSkills() -> [AgentSkill] {
        return cachedSkills
    }
    
    func clearCache() {
        cachedSkills.removeAll()
        hasFetched = false
    }
}

// MARK: - SkillsMP Response Models

struct SkillsMPSearchResponse: Codable {
    let skills: [SkillsMPSkill]
    let pagination: SkillsMPPagination?
}

struct SkillsMPSkill: Codable {
    let id: String
    let name: String
    let description: String?
    let stars: Int?
    let source: String?
    let repositoryUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, stars, source
        case repositoryUrl = "repository_url"
    }
    
    func toAgentSkill(source sourceName: String) -> AgentSkill {
        AgentSkill(
            id: "\(sourceName):\(id)",
            name: name,
            description: description,
            source: source ?? id,
            installs: stars ?? 0,
            repositoryUrl: repositoryUrl
        )
    }
}

struct SkillsMPPagination: Codable {
    let page: Int?
    let limit: Int?
    let total: Int?
    let hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case page, limit, total
        case hasMore = "has_more"
    }
}

// MARK: - Client Discovery Service

actor ClientDiscoveryService {
    func discoverClients() async -> [MCPClient] {
        var clients: [MCPClient] = []
        
        for clientType in MCPClientType.allCases {
            let isInstalled = checkClientInstalled(clientType)
            var installedServers: [String: InstalledServer] = [:]
            
            if isInstalled, let configPath = clientType.configPath {
                installedServers = loadServersFromConfig(configPath, clientType: clientType)
            }
            
            clients.append(MCPClient(
                type: clientType,
                isInstalled: isInstalled,
                installedServers: installedServers
            ))
        }
        
        return clients
    }
    
    private func checkClientInstalled(_ clientType: MCPClientType) -> Bool {
        let fm = FileManager.default
        let apps = "/Applications"
        let home = NSHomeDirectory()
        
        switch clientType {
        // Desktop Apps
        case .claude:
            return fm.fileExists(atPath: "\(apps)/Claude.app")
        case .cursor:
            return fm.fileExists(atPath: "\(apps)/Cursor.app")
        case .vscode:
            return fm.fileExists(atPath: "\(apps)/Visual Studio Code.app")
        case .windsurf:
            return fm.fileExists(atPath: "\(apps)/Windsurf.app")
        case .zed:
            return fm.fileExists(atPath: "\(apps)/Zed.app")
        case .trae:
            return fm.fileExists(atPath: "\(apps)/Trae.app")
        case .kiro:
            return fm.fileExists(atPath: "\(apps)/Kiro.app") ||
                   fm.fileExists(atPath: "\(apps)/Amazon Kiro.app")
        case .antigravity:
            return fm.fileExists(atPath: "\(apps)/Antigravity.app") ||
                   fm.fileExists(atPath: "\(apps)/Google Antigravity.app")
        case .ampcode:
            return fm.fileExists(atPath: "\(apps)/AMPCode.app") ||
                   fm.fileExists(atPath: "\(apps)/AMP Code.app")
        
        // CLI Agents
        case .claudeCode:
            return fm.fileExists(atPath: "/usr/local/bin/claude") ||
                   fm.fileExists(atPath: "\(home)/.claude")
        case .githubCopilot:
            return fm.fileExists(atPath: "/usr/local/bin/gh") ||
                   fm.fileExists(atPath: "\(home)/.copilot")
        case .openaiCodex:
            return fm.fileExists(atPath: "/usr/local/bin/codex") ||
                   fm.fileExists(atPath: "\(home)/.codex")
        case .geminiCli:
            return fm.fileExists(atPath: "/usr/local/bin/gemini") ||
                   fm.fileExists(atPath: "\(home)/.gemini")
        case .openCode:
            return fm.fileExists(atPath: "/usr/local/bin/opencode") ||
                   fm.fileExists(atPath: "\(home)/.config/opencode")
        case .goose:
            return fm.fileExists(atPath: "/usr/local/bin/goose") ||
                   fm.fileExists(atPath: "\(home)/.config/goose")
        
        // VS Code Extensions (check if extension folder exists)
        case .cline:
            return fm.fileExists(atPath: "\(home)/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev")
        case .rooCode:
            return fm.fileExists(atPath: "\(home)/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline")
        case .kiloCode:
            return fm.fileExists(atPath: "\(home)/Library/Application Support/Code/User/globalStorage/kilocode.kilo-code")
        case .factoryAi:
            return fm.fileExists(atPath: "\(home)/.factory") ||
                   fm.fileExists(atPath: "\(apps)/Factory.app")
        }
    }
    
    private func loadServersFromConfig(_ path: String, clientType: MCPClientType) -> [String: InstalledServer] {
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        
        var servers: [String: InstalledServer] = [:]
        
        // Parse selon le format du client
        if let mcpServers = json["mcpServers"] as? [String: [String: Any]] {
            for (name, config) in mcpServers {
                if let command = config["command"] as? String {
                    let args = config["args"] as? [String] ?? []
                    let env = config["env"] as? [String: String]
                    
                    servers[name] = InstalledServer(
                        name: name,
                        command: command,
                        args: args,
                        env: env,
                        clientTypes: [clientType]
                    )
                }
            }
        }
        
        return servers
    }
}

// MARK: - Config File Service

class ConfigFileService {
    static let shared = ConfigFileService()
    
    func installServer(_ server: MCPServer, toClient clientType: MCPClientType, command: String, args: [String], env: [String: String]?) async throws {
        guard let configPath = clientType.configPath else {
            throw AppError.configurationError("Config path not found for \(clientType.displayName)")
        }
        
        var config: [String: Any] = [:]
        
        // Load existing config
        if let data = FileManager.default.contents(atPath: configPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            config = existing
        }
        
        // Add server
        var mcpServers = config["mcpServers"] as? [String: [String: Any]] ?? [:]
        var serverConfig: [String: Any] = [
            "command": command,
            "args": args
        ]
        if let env = env {
            serverConfig["env"] = env
        }
        mcpServers[server.name] = serverConfig
        config["mcpServers"] = mcpServers
        
        // Write config
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        
        // Create directory if needed
        let dir = (configPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        
        try data.write(to: URL(fileURLWithPath: configPath))
    }
    
    func uninstallServer(_ serverName: String, fromClient clientType: MCPClientType) async throws {
        guard let configPath = clientType.configPath else {
            throw AppError.configurationError("Config path not found for \(clientType.displayName)")
        }
        
        guard let data = FileManager.default.contents(atPath: configPath),
              var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        var mcpServers = config["mcpServers"] as? [String: [String: Any]] ?? [:]
        mcpServers.removeValue(forKey: serverName)
        config["mcpServers"] = mcpServers
        
        let newData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try newData.write(to: URL(fileURLWithPath: configPath))
    }
}
