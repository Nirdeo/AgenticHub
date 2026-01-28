import Foundation
import SwiftUI

// MARK: - MCP Server Model

struct MCPServer: Identifiable, Codable, Hashable {
    var id: String {
        if let repoUrl = repository?.url {
            let normalized = repoUrl
                .replacingOccurrences(of: ".git", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .lowercased()
            return "\(name)|\(normalized)"
        }
        return name
    }

    let name: String
    let title: String?
    let description: String?
    let version: String?
    let packages: [MCPPackage]
    let icons: [MCPIcon]?
    let repository: MCPRepository?
    let websiteUrl: String?
    
    // Legacy properties for compatibility
    let vendor: String?
    let sourceUrl: String?
    let homepage: String?
    let license: String?
    
    var displayName: String {
        title ?? name.components(separatedBy: "/").last ?? name
    }
    
    var primaryPackage: MCPPackage? {
        packages.first
    }
    
    var iconURL: URL? {
        guard let iconSrc = icons?.first?.src else { return nil }
        return URL(string: iconSrc)
    }
    
    /// Unique transport types across all packages
    var uniqueTransportTypes: [TransportType] {
        var seen = Set<TransportType>()
        return packages.compactMap { package in
            guard let transport = package.transport?.type else { return nil }
            if seen.contains(transport) { return nil }
            seen.insert(transport)
            return transport
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case name, title, description, version, packages, icons, repository, websiteUrl
        case vendor, sourceUrl, homepage, license
    }
    
    init(name: String, title: String? = nil, description: String? = nil,
         version: String? = nil, packages: [MCPPackage] = [],
         icons: [MCPIcon]? = nil, repository: MCPRepository? = nil,
         websiteUrl: String? = nil, vendor: String? = nil,
         sourceUrl: String? = nil, homepage: String? = nil, license: String? = nil) {
        self.name = name
        self.title = title
        self.description = description
        self.version = version
        self.packages = packages
        self.icons = icons
        self.repository = repository
        self.websiteUrl = websiteUrl
        self.vendor = vendor
        self.sourceUrl = sourceUrl
        self.homepage = homepage
        self.license = license
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        packages = try container.decodeIfPresent([MCPPackage].self, forKey: .packages) ?? []
        icons = try container.decodeIfPresent([MCPIcon].self, forKey: .icons)
        repository = try container.decodeIfPresent(MCPRepository.self, forKey: .repository)
        websiteUrl = try container.decodeIfPresent(String.self, forKey: .websiteUrl)
        vendor = try container.decodeIfPresent(String.self, forKey: .vendor)
        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        homepage = try container.decodeIfPresent(String.self, forKey: .homepage)
        license = try container.decodeIfPresent(String.self, forKey: .license)
    }
}

// MARK: - MCP Package

struct MCPPackage: Codable, Identifiable, Hashable {
    var id: String { identifier }

    let registryType: PackageRegistryType
    let identifier: String
    let transport: MCPTransport?
    let environmentVariables: [MCPEnvironmentVariable]?

    init(registryType: PackageRegistryType, identifier: String,
         transport: MCPTransport? = nil, environmentVariables: [MCPEnvironmentVariable]? = nil) {
        self.registryType = registryType
        self.identifier = identifier
        self.transport = transport
        self.environmentVariables = environmentVariables
    }
}

enum PackageRegistryType: String, Codable, Hashable, CaseIterable {
    case npm
    case pypi
    case oci
    case mcpb
    case unknown

    static var allCases: [PackageRegistryType] {
        [.npm, .pypi, .oci, .mcpb]
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = PackageRegistryType(rawValue: value) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .npm: return "NPM"
        case .pypi: return "PyPI"
        case .oci: return "Docker"
        case .mcpb: return "MCP Bundle"
        case .unknown: return "Other"
        }
    }

    var installCommand: String {
        switch self {
        case .npm: return "npx"
        case .pypi: return "uvx"
        case .oci: return "docker"
        case .mcpb: return "open"
        case .unknown: return ""
        }
    }
}

struct MCPTransport: Codable, Hashable {
    let type: TransportType
    let url: String?

    init(type: TransportType, url: String? = nil) {
        self.type = type
        self.url = url
    }
}

enum TransportType: String, Codable, Hashable {
    case stdio
    case streamableHttp = "streamable-http"
    case sse
    case unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "stdio": self = .stdio
        case "streamable-http": self = .streamableHttp
        case "sse": self = .sse
        default: self = .unknown
        }
    }

    var displayName: String {
        switch self {
        case .stdio: return "stdio"
        case .sse: return "sse"
        case .streamableHttp: return "http"
        case .unknown: return "other"
        }
    }
}

struct MCPEnvironmentVariable: Codable, Hashable, Identifiable {
    var id: String { name }
    
    let name: String
    let description: String?
    let isSecret: Bool?
    let format: String?
    
    init(name: String, description: String? = nil, isSecret: Bool? = nil, format: String? = nil) {
        self.name = name
        self.description = description
        self.isSecret = isSecret
        self.format = format
    }
}

struct MCPIcon: Codable, Hashable {
    let src: String
    let mimeType: String?
    let theme: String?

    init(src: String, mimeType: String? = nil, theme: String? = nil) {
        self.src = src
        self.mimeType = mimeType
        self.theme = theme
    }
}

struct MCPRepository: Codable, Hashable {
    let url: String?
    let source: String?

    init(url: String? = nil, source: String? = nil) {
        self.url = url
        self.source = source
    }
}

// MARK: - GitHub Metadata

/// GitHub repository metadata from the josh.ing API
struct GitHubMetadata: Codable, Hashable {
    let stars: Int
    let forks: Int
    let openIssues: Int
    let language: String?
    let topics: [String]
    let license: String?
    let lastCommitAt: Date?
    let archived: Bool

    /// Formatted star count (e.g., "1.2k", "25.3k")
    var formattedStars: String {
        if stars >= 1000 {
            return String(format: "%.1fk", Double(stars) / 1000)
        }
        return "\(stars)"
    }

    /// Activity status based on last commit date
    var activityStatus: ActivityStatus {
        if archived {
            return .archived
        }
        guard let lastCommit = lastCommitAt else {
            return .unknown
        }
        let now = Date()
        guard let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: now),
              let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: now) else {
            return .unknown
        }

        if lastCommit > oneMonthAgo {
            return .active
        } else if lastCommit > sixMonthsAgo {
            return .recent
        } else {
            return .stale
        }
    }

    /// Relative time string for last commit (e.g., "2 days ago")
    var lastCommitRelative: String? {
        guard let lastCommit = lastCommitAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastCommit, relativeTo: Date())
    }

    /// Initialize from JoshIngGitHub response
    init(from github: JoshIngGitHub) {
        self.stars = github.stars ?? 0
        self.forks = github.forks ?? 0
        self.openIssues = github.openIssues ?? 0
        self.language = github.language
        self.topics = github.topics ?? []
        self.license = github.license
        self.archived = github.archived ?? false

        // Parse ISO8601 date
        if let dateString = github.lastCommitAt {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.lastCommitAt = formatter.date(from: dateString)
                ?? ISO8601DateFormatter().date(from: dateString)
        } else {
            self.lastCommitAt = nil
        }
    }

    /// Direct initializer
    init(stars: Int, forks: Int, openIssues: Int, language: String?,
         topics: [String], license: String?, lastCommitAt: Date?, archived: Bool) {
        self.stars = stars
        self.forks = forks
        self.openIssues = openIssues
        self.language = language
        self.topics = topics
        self.license = license
        self.lastCommitAt = lastCommitAt
        self.archived = archived
    }
}

/// Activity status based on last commit recency
enum ActivityStatus: String {
    case active = "Active"
    case recent = "Recent"
    case stale = "Stale"
    case archived = "Archived"
    case unknown = "Unknown"

    var color: Color {
        switch self {
        case .active: return .green
        case .recent: return .yellow
        case .stale: return .orange
        case .archived: return .red
        case .unknown: return .gray
        }
    }
}

// MARK: - Agent Skill Model

/// Represents a skill from Skills.sh or SkillsMP
struct AgentSkill: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String?
    let source: String
    let installs: Int
    let repositoryUrl: String?
    let sourceProvider: String  // "Skills.sh" or "SkillsMP"
    
    var displayName: String {
        name.components(separatedBy: "/").last ?? name
    }
    
    var formattedInstalls: String {
        if installs >= 1000000 {
            return String(format: "%.1fM", Double(installs) / 1000000)
        } else if installs >= 1000 {
            return String(format: "%.1fk", Double(installs) / 1000)
        }
        return "\(installs)"
    }
    
    var sourceOwnerRepo: String? {
        // Extract owner/repo from source like "vercel-labs/agent-skills"
        let components = source.components(separatedBy: "/")
        if components.count >= 2 {
            return "\(components[0])/\(components[1])"
        }
        return nil
    }
    
    var skillPath: String? {
        // Extract skill path after owner/repo
        let components = source.components(separatedBy: "/")
        if components.count >= 3 {
            return components.dropFirst(2).joined(separator: "/")
        }
        return nil
    }
    
    var installCommand: String {
        "npx skills add \(source)"
    }
    
    // Default initializer with sourceProvider defaulting to Skills.sh
    init(id: String, name: String, description: String?, source: String, installs: Int, repositoryUrl: String?, sourceProvider: String = "Skills.sh") {
        self.id = id
        self.name = name
        self.description = description
        self.source = source
        self.installs = installs
        self.repositoryUrl = repositoryUrl
        self.sourceProvider = sourceProvider
    }
}

/// Response from Skills.sh API search
struct SkillsSearchResponse: Codable {
    let skills: [SkillsSearchResult]
}

struct SkillsSearchResult: Codable {
    let id: String
    let name: String
    let installs: Int
    let topSource: String?
    
    func toAgentSkill() -> AgentSkill {
        AgentSkill(
            id: "Skills.sh:\(id)",
            name: name,
            description: nil,
            source: topSource ?? id,
            installs: installs,
            repositoryUrl: topSource != nil ? "https://github.com/\(topSource!.components(separatedBy: "@").first ?? topSource!)" : nil,
            sourceProvider: "Skills.sh"
        )
    }
}

/// Response from Skills.sh leaderboard
struct SkillsLeaderboardResponse: Codable {
    let skills: [SkillsLeaderboardEntry]
    let pagination: SkillsPagination?
}

struct SkillsLeaderboardEntry: Codable {
    let id: String
    let name: String
    let description: String?
    let installs: Int
    let source: String?
    let repositoryUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, installs, source
        case repositoryUrl = "repository_url"
    }
    
    func toAgentSkill() -> AgentSkill {
        AgentSkill(
            id: "Skills.sh:\(id)",
            name: name,
            description: description,
            source: source ?? id,
            installs: installs,
            repositoryUrl: repositoryUrl,
            sourceProvider: "Skills.sh"
        )
    }
}

struct SkillsPagination: Codable {
    let total: Int?
    let limit: Int?
    let offset: Int?
    let hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case total, limit, offset
        case hasMore = "has_more"
    }
}

// MARK: - Josh.ing API Response Models

/// Response from the josh.ing API /servers endpoint
struct JoshIngResponse: Codable {
    let servers: [JoshIngServer]
    let pagination: JoshIngPagination
}

/// Server entry from josh.ing API
struct JoshIngServer: Codable {
    let name: String
    let repositoryUrl: String?
    let github: JoshIngGitHub?

    enum CodingKeys: String, CodingKey {
        case name
        case repositoryUrl = "repository_url"
        case github
    }
}

/// GitHub metadata from josh.ing API
struct JoshIngGitHub: Codable {
    let stars: Int?
    let forks: Int?
    let openIssues: Int?
    let language: String?
    let topics: [String]?
    let license: String?
    let lastCommitAt: String?
    let archived: Bool?

    enum CodingKeys: String, CodingKey {
        case stars, forks
        case openIssues = "open_issues"
        case language, topics, license
        case lastCommitAt = "last_commit_at"
        case archived
    }
}

/// Pagination info from josh.ing API
struct JoshIngPagination: Codable {
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case total, limit, offset
        case hasMore = "has_more"
    }
}

// MARK: - Installed Server

struct InstalledServer: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let command: String
    let args: [String]
    let env: [String: String]?
    var isEnabled: Bool
    let clientTypes: Set<MCPClientType>
    
    init(id: String = UUID().uuidString, name: String, command: String, args: [String] = [], env: [String: String]? = nil, isEnabled: Bool = true, clientTypes: Set<MCPClientType> = []) {
        self.id = id
        self.name = name
        self.command = command
        self.args = args
        self.env = env
        self.isEnabled = isEnabled
        self.clientTypes = clientTypes
    }
}

// MARK: - Client Category

enum ClientCategory: String, CaseIterable, Identifiable {
    case desktopApp = "desktop"
    case cliAgent = "cli"
    case vscodeExtension = "extension"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .desktopApp: return "Desktop Apps"
        case .cliAgent: return "CLI Agents"
        case .vscodeExtension: return "VS Code Extensions"
        }
    }
    
    var systemIcon: String {
        switch self {
        case .desktopApp: return "macwindow"
        case .cliAgent: return "terminal"
        case .vscodeExtension: return "puzzlepiece.extension"
        }
    }
}

// MARK: - MCP Client Type

enum MCPClientType: String, Codable, CaseIterable, Identifiable {
    // Desktop Apps
    case claude = "claude"
    case cursor = "cursor"
    case vscode = "vscode"
    case windsurf = "windsurf"
    case zed = "zed"
    case trae = "trae"
    case kiro = "kiro"
    case antigravity = "antigravity"
    case ampcode = "ampcode"
    
    // CLI Agents
    case claudeCode = "claude-code"
    case githubCopilot = "github-copilot"
    case openaiCodex = "openai-codex"
    case geminiCli = "gemini-cli"
    case openCode = "opencode"
    case goose = "goose"
    
    // VS Code Extensions
    case cline = "cline"
    case rooCode = "roo-code"
    case kiloCode = "kilo-code"
    case factoryAi = "factory-ai"
    
    var id: String { rawValue }
    
    var category: ClientCategory {
        switch self {
        case .claude, .cursor, .vscode, .windsurf, .zed, .trae, .kiro, .antigravity, .ampcode:
            return .desktopApp
        case .claudeCode, .githubCopilot, .openaiCodex, .geminiCli, .openCode, .goose:
            return .cliAgent
        case .cline, .rooCode, .kiloCode, .factoryAi:
            return .vscodeExtension
        }
    }
    
    var displayName: String {
        switch self {
        // Desktop Apps
        case .claude: return "Claude Desktop"
        case .cursor: return "Cursor"
        case .vscode: return "VS Code"
        case .windsurf: return "Windsurf"
        case .zed: return "Zed"
        case .trae: return "Trae"
        case .kiro: return "Amazon Kiro"
        case .antigravity: return "Google Antigravity"
        case .ampcode: return "AMPCode"
        // CLI Agents
        case .claudeCode: return "Claude Code"
        case .githubCopilot: return "GitHub Copilot CLI"
        case .openaiCodex: return "OpenAI Codex CLI"
        case .geminiCli: return "Gemini CLI"
        case .openCode: return "OpenCode"
        case .goose: return "Goose"
        // VS Code Extensions
        case .cline: return "Cline"
        case .rooCode: return "Roo Code"
        case .kiloCode: return "Kilo Code"
        case .factoryAi: return "Factory AI"
        }
    }
    
    var systemIcon: String {
        switch self {
        // Desktop Apps
        case .claude: return "message.circle.fill"
        case .cursor: return "cursorarrow.rays"
        case .vscode: return "chevron.left.forwardslash.chevron.right"
        case .windsurf: return "wind"
        case .zed: return "z.circle.fill"
        case .trae: return "t.circle.fill"
        case .kiro: return "k.circle.fill"
        case .antigravity: return "arrow.up.circle.fill"
        case .ampcode: return "bolt.circle.fill"
        // CLI Agents
        case .claudeCode: return "terminal.fill"
        case .githubCopilot: return "airplane"
        case .openaiCodex: return "brain"
        case .geminiCli: return "sparkles"
        case .openCode: return "doc.text.fill"
        case .goose: return "bird.fill"
        // VS Code Extensions
        case .cline: return "puzzlepiece.extension.fill"
        case .rooCode: return "hare.fill"
        case .kiloCode: return "scalemass.fill"
        case .factoryAi: return "gearshape.2.fill"
        }
    }
    
    var accentColor: Color {
        Color(hex: accentColorHex)
    }
    
    var accentColorHex: String {
        switch self {
        // Desktop Apps
        case .claude: return "#D97757"
        case .cursor: return "#7B61FF"
        case .vscode: return "#007ACC"
        case .windsurf: return "#00CED1"
        case .zed: return "#F5A623"
        case .trae: return "#FF6B6B"
        case .kiro: return "#FF9900"
        case .antigravity: return "#4285F4"
        case .ampcode: return "#FFD700"
        // CLI Agents
        case .claudeCode: return "#00A67E"
        case .githubCopilot: return "#6E40C9"
        case .openaiCodex: return "#10A37F"
        case .geminiCli: return "#8E75B2"
        case .openCode: return "#3B82F6"
        case .goose: return "#FF7F50"
        // VS Code Extensions
        case .cline: return "#2DD4BF"
        case .rooCode: return "#EC4899"
        case .kiloCode: return "#8B5CF6"
        case .factoryAi: return "#06B6D4"
        }
    }
    
    /// Chemin du fichier de configuration global (macOS)
    var configPath: String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        // Desktop Apps
        case .claude:
            return "\(home)/Library/Application Support/Claude/claude_desktop_config.json"
        case .cursor:
            return "\(home)/.cursor/mcp.json"
        case .vscode:
            return nil // VS Code utilise Command Palette : "MCP: Open User Configuration"
        case .windsurf:
            return "\(home)/.codeium/windsurf/mcp_config.json"
        case .zed:
            return "\(home)/.config/zed/settings.json"
        case .trae:
            return nil // Trae: config via UI uniquement (Cmd+U → engrenage → MCP)
        case .kiro:
            return "\(home)/.kiro/settings/mcp.json"
        case .antigravity:
            return "\(home)/.gemini/antigravity/mcp_config.json"
        case .ampcode:
            return "\(home)/.config/amp/settings.json"
        // CLI Agents
        case .claudeCode:
            return "\(home)/.claude.json"
        case .githubCopilot:
            return "\(home)/.copilot/mcp-config.json"
        case .openaiCodex:
            return "\(home)/.codex/config.toml"
        case .geminiCli:
            return "\(home)/.gemini/settings.json"
        case .openCode:
            return "\(home)/.config/opencode/opencode.json"
        case .goose:
            return "\(home)/.config/goose/config.yaml"
        // VS Code Extensions
        case .cline:
            return "\(home)/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json"
        case .rooCode:
            return "\(home)/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/cline_mcp_settings.json"
        case .kiloCode:
            return "\(home)/Library/Application Support/Code/User/globalStorage/kilocode.kilo-code/settings/mcp_settings.json"
        case .factoryAi:
            return "\(home)/.factory/mcp.json"
        }
    }
    
    /// Chemin de configuration au niveau projet (si supporté)
    var projectConfigPath: String? {
        switch self {
        case .cursor: return ".cursor/mcp.json"
        case .vscode: return ".vscode/mcp.json"
        case .zed: return ".zed/settings.json"
        case .kiro: return ".kiro/settings/mcp.json"
        case .ampcode: return ".amp/settings.json"
        case .claudeCode: return ".mcp.json"
        case .githubCopilot: return ".copilot/mcp-config.json"
        case .geminiCli: return ".gemini/settings.json"
        case .openCode: return "opencode.json"
        case .rooCode: return ".roo/mcp.json"
        case .kiloCode: return ".kilocode/mcp.json"
        case .factoryAi: return ".factory/mcp.json"
        default: return nil
        }
    }
    
    /// Le nom du fichier de configuration
    var configFileName: String {
        switch self {
        // Desktop Apps
        case .claude: return "claude_desktop_config.json"
        case .cursor: return "mcp.json"
        case .vscode: return "mcp.json"
        case .windsurf: return "mcp_config.json"
        case .zed: return "settings.json"
        case .trae: return "(UI only)"
        case .kiro: return "mcp.json"
        case .antigravity: return "mcp_config.json"
        case .ampcode: return "settings.json"
        // CLI Agents
        case .claudeCode: return ".claude.json / .mcp.json"
        case .githubCopilot: return "mcp-config.json"
        case .openaiCodex: return "config.toml"
        case .geminiCli: return "settings.json"
        case .openCode: return "opencode.json"
        case .goose: return "config.yaml"
        // VS Code Extensions
        case .cline: return "cline_mcp_settings.json"
        case .rooCode: return "cline_mcp_settings.json"
        case .kiloCode: return "mcp_settings.json"
        case .factoryAi: return "mcp.json"
        }
    }
    
    /// Format du fichier de configuration
    var configFormat: String {
        switch self {
        case .openaiCodex: return "TOML"
        case .goose: return "YAML"
        case .openCode: return "JSONC"
        default: return "JSON"
        }
    }
    
    /// Clé racine MCP dans le fichier de configuration
    var mcpRootKey: String {
        switch self {
        case .vscode: return "servers"
        case .zed: return "context_servers"
        case .ampcode: return "amp.mcpServers"
        case .openaiCodex: return "mcp_servers"
        case .openCode: return "mcp"
        case .goose: return "extensions"
        default: return "mcpServers"
        }
    }
    
    /// Note spéciale sur la configuration
    var configNote: String? {
        switch self {
        case .claude:
            return "Accessible via Claude Menu → Settings → Developer → Edit Config"
        case .cursor:
            return "Aussi accessible via Command Palette → Cursor Settings → MCP"
        case .vscode:
            return "Config via Command Palette : 'MCP: Open User Configuration'"
        case .windsurf:
            return "Limite de 100 outils actifs simultanément"
        case .zed:
            return "Utilise context_servers au lieu de mcpServers. Supporte aussi les extensions."
        case .trae:
            return "Configuration via UI uniquement : Cmd/Ctrl+U → Icône engrenage → MCP → Add Manually. Linux non supporté."
        case .kiro:
            return "Config workspace prend précédence sur global"
        case .antigravity:
            return "Inclut un MCP Store intégré pour installation en un clic"
        case .ampcode:
            return "Commandes CLI : amp mcp add, amp mcp approve"
        case .claudeCode:
            return "Les serveurs projet (.mcp.json) nécessitent approbation utilisateur"
        case .githubCopilot:
            return "Le serveur GitHub MCP est pré-configuré par défaut"
        case .openaiCodex:
            return "Supporte uniquement le transport STDIO (pas de HTTP/SSE distant)"
        case .geminiCli:
            return "Supporte stdio, SSE et HTTP"
        case .openCode:
            return "Variable d'environnement OPENCODE_CONFIG pour chemin personnalisé"
        case .goose:
            return "Les serveurs MCP sont configurés comme extensions de type stdio ou sse"
        case .rooCode:
            return "La configuration projet (.roo/mcp.json) prend précédence en cas de conflit"
        case .factoryAi:
            return "La configuration user (~/.factory) prend précédence sur projet"
        default:
            return nil
        }
    }
}

// MARK: - MCP Client

struct MCPClient: Identifiable, Hashable {
    let type: MCPClientType
    var isInstalled: Bool
    var installedServers: [String: InstalledServer]
    
    var id: String { type.rawValue }
    var configPath: String? { type.configPath }
    
    init(type: MCPClientType, isInstalled: Bool = false, installedServers: [String: InstalledServer] = [:]) {
        self.type = type
        self.isInstalled = isInstalled
        self.installedServers = installedServers
    }
}

// MARK: - MCP Registry

struct MCPRegistry: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String
    let url: String
    let type: RegistryType
    let icon: String?
    let isOfficial: Bool
    
    enum RegistryType: String, Codable, Hashable {
        case github = "github"
        case curated = "curated"
        case community = "community"
        case hosted = "hosted"
        
        var displayName: String {
            switch self {
            case .github: return "GitHub"
            case .curated: return "Curated"
            case .community: return "Community"
            case .hosted: return "Hosted"
            }
        }
    }
    
    static let defaultRegistries: [MCPRegistry] = [
        MCPRegistry(
            id: "smithery",
            name: "Smithery",
            description: "Le plus grand registre MCP avec 3,823+ serveurs, authentification OAuth intégrée et observabilité",
            url: "https://api.smithery.ai/servers",
            type: .hosted,
            icon: "🔨",
            isOfficial: true
        ),
        MCPRegistry(
            id: "glama",
            name: "Glama MCP Servers",
            description: "Répertoire complet avec 17,307+ serveurs, catégories et recherche avancée",
            url: "https://glama.ai/api/mcp/servers",
            type: .curated,
            icon: "✨",
            isOfficial: true
        ),
        MCPRegistry(
            id: "github-official",
            name: "GitHub Official",
            description: "Référentiel officiel MCP par Anthropic avec serveurs de référence",
            url: "https://api.github.com/repos/modelcontextprotocol/servers",
            type: .github,
            icon: "🐙",
            isOfficial: true
        ),
        MCPRegistry(
            id: "awesome-punkpeye",
            name: "Awesome MCP Servers",
            description: "Liste communautaire maintenue par @punkpeye avec serveurs vérifiés",
            url: "https://raw.githubusercontent.com/punkpeye/awesome-mcp-servers/main/servers.json",
            type: .community,
            icon: "⭐",
            isOfficial: false
        ),
        MCPRegistry(
            id: "awesome-wong2",
            name: "MCP Servers by wong2",
            description: "Collection communautaire populaire avec mcpservers.org",
            url: "https://raw.githubusercontent.com/wong2/awesome-mcp-servers/main/servers.json",
            type: .community,
            icon: "🌟",
            isOfficial: false
        ),
        MCPRegistry(
            id: "mcp-get",
            name: "mcp-get",
            description: "Outil CLI pour installer et gérer les serveurs MCP",
            url: "https://mcp-get.com/api/servers",
            type: .hosted,
            icon: "📦",
            isOfficial: false
        ),
        MCPRegistry(
            id: "mcpservers-com",
            name: "MCPServers.com",
            description: "Répertoire de serveurs MCP de haute qualité avec guides de configuration",
            url: "https://mcpservers.com/api/servers",
            type: .curated,
            icon: "🚀",
            isOfficial: false
        ),
        MCPRegistry(
            id: "mcp-hub",
            name: "MCPHub",
            description: "Plateforme de découverte et gestion de serveurs MCP",
            url: "https://www.mcphub.com/api/servers",
            type: .hosted,
            icon: "🎯",
            isOfficial: false
        ),
        MCPRegistry(
            id: "natoma",
            name: "Natoma MCP",
            description: "Plateforme hébergée pour découvrir, installer et gérer les serveurs MCP",
            url: "https://mcp.natoma.ai/api/servers",
            type: .hosted,
            icon: "🔮",
            isOfficial: false
        ),
        MCPRegistry(
            id: "mcpverse",
            name: "MCPVerse",
            description: "Portail pour créer et héberger des serveurs MCP authentifiés",
            url: "https://mcpverse.dev/api/servers",
            type: .hosted,
            icon: "🌐",
            isOfficial: false
        )
    ]
}

// MARK: - Registry Response

/// Response from MCP registry API
struct RegistryResponse: Codable {
    let servers: [ServerWrapper]
    let metadata: RegistryMetadata
}

struct ServerWrapper: Codable {
    let server: MCPServer
}

struct RegistryMetadata: Codable {
    let nextCursor: String?
    let count: Int
}

// MARK: - App Error

enum AppError: LocalizedError, Identifiable {
    case registryLoadFailed(String)
    case clientDiscoveryFailed(String)
    case installationFailed(String)
    case configurationError(String)
    case networkError(String)
    
    var id: String {
        switch self {
        case .registryLoadFailed(let msg): return "registry_\(msg)"
        case .clientDiscoveryFailed(let msg): return "client_\(msg)"
        case .installationFailed(let msg): return "install_\(msg)"
        case .configurationError(let msg): return "config_\(msg)"
        case .networkError(let msg): return "network_\(msg)"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .registryLoadFailed(let msg): return "Failed to load registry: \(msg)"
        case .clientDiscoveryFailed(let msg): return "Failed to discover clients: \(msg)"
        case .installationFailed(let msg): return "Installation failed: \(msg)"
        case .configurationError(let msg): return "Configuration error: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        }
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
