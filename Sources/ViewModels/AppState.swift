import Foundation
import SwiftUI

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    // Services
    let registryService = RegistryService()
    let clientDiscoveryService = ClientDiscoveryService()
    let gitHubMetadataService = GitHubMetadataService()
    let skillsService = SkillsService()
    
    // State - MCP Servers
    @Published var registryServers: [MCPServer] = []
    @Published var availableRegistries: [MCPRegistry] = []
    @Published var selectedRegistry: MCPRegistry?
    @Published var clients: [MCPClient] = []
    @Published var gitHubMetadata: [String: GitHubMetadata] = [:]
    
    // State - Skills
    @Published var skills: [AgentSkill] = []
    @Published var isLoadingSkills = false
    
    // Loading states
    @Published var isLoadingRegistry = false
    @Published var isLoadingClients = false
    @Published var isLoadingMetadata = false
    @Published var error: AppError?
    @Published var searchText = ""
    
    // Navigation
    @Published var selectedSection: SidebarSection? = .installed
    
    init() {
        print("📱 AppState initialized")
        // Charger les registres disponibles
        Task {
            await loadAvailableRegistries()
        }
    }
    
    // MARK: - Computed Properties
    
    var installedServers: [InstalledServer] {
        var servers: [String: InstalledServer] = [:]
        
        for client in clients {
            for (name, server) in client.installedServers {
                if var existing = servers[name] {
                    var newClientTypes = existing.clientTypes
                    newClientTypes.formUnion(server.clientTypes)
                    existing = InstalledServer(
                        id: existing.id,
                        name: existing.name,
                        command: existing.command,
                        args: existing.args,
                        env: existing.env,
                        isEnabled: existing.isEnabled,
                        clientTypes: newClientTypes
                    )
                    servers[name] = existing
                } else {
                    servers[name] = server
                }
            }
        }
        
        return Array(servers.values).sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    var installedClients: [MCPClient] {
        clients.filter { $0.isInstalled || !$0.installedServers.isEmpty }
    }
    
    var filteredRegistryServers: [MCPServer] {
        if searchText.isEmpty {
            return registryServers
        }
        return registryServers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    // MARK: - Actions
    
    func loadAvailableRegistries() async {
        availableRegistries = await registryService.getAllRegistries()
        if selectedRegistry == nil {
            selectedRegistry = await registryService.getActiveRegistry()
        }
        print("📚 Loaded \(availableRegistries.count) available registries")
    }
    
    func switchRegistry(_ registry: MCPRegistry) async {
        selectedRegistry = registry
        await registryService.setActiveRegistry(registry)
        await loadRegistry()
        print("🔄 Switched to registry: \(registry.name)")
    }
    
    func loadInitialData() async {
        print("🔄 Loading initial data...")
        
        async let registryTask: () = loadRegistry()
        async let clientsTask: () = discoverClients()
        async let metadataTask: () = loadGitHubMetadata()
        async let skillsTask: () = loadSkills()
        
        _ = await (registryTask, clientsTask, metadataTask, skillsTask)
        
        print("✅ Initial data loaded")
    }
    
    func loadRegistry() async {
        isLoadingRegistry = true
        defer { isLoadingRegistry = false }
        
        do {
            if let registry = selectedRegistry {
                registryServers = try await registryService.fetchAllServers(from: registry)
            } else {
                registryServers = try await registryService.fetchAllServers()
            }
            print("📦 Loaded \(registryServers.count) servers from registry")
        } catch {
            self.error = .registryLoadFailed(error.localizedDescription)
        }
    }
    
    func loadGitHubMetadata() async {
        isLoadingMetadata = true
        defer { isLoadingMetadata = false }
        
        do {
            gitHubMetadata = try await gitHubMetadataService.fetchAllMetadata()
            print("⭐ Loaded GitHub metadata for \(gitHubMetadata.count) servers")
        } catch {
            print("⚠️ Failed to load GitHub metadata: \(error.localizedDescription)")
            // Non-fatal error - app works without metadata
        }
    }
    
    /// Get GitHub metadata for a server
    func getMetadata(for server: MCPServer) -> GitHubMetadata? {
        return gitHubMetadata[server.name] ?? 
               (server.repository?.url.flatMap { gitHubMetadata[$0] })
    }
    
    func discoverClients() async {
        isLoadingClients = true
        defer { isLoadingClients = false }
        
        clients = await clientDiscoveryService.discoverClients()
        let installedCount = clients.filter { $0.isInstalled }.count
        print("🔍 Discovered \(installedCount) installed clients")
    }
    
    // MARK: - Skills
    
    func loadSkills() async {
        isLoadingSkills = true
        defer { isLoadingSkills = false }
        
        do {
            skills = try await skillsService.fetchPopularSkills()
            print("🎯 Loaded \(skills.count) skills")
        } catch {
            print("⚠️ Failed to load skills: \(error.localizedDescription)")
            // Non-fatal error
        }
    }
    
    func searchSkills(query: String) async -> [AgentSkill] {
        do {
            return try await skillsService.searchSkills(query: query)
        } catch {
            print("⚠️ Skills search failed: \(error.localizedDescription)")
            return []
        }
    }
    
    func refreshAll() async {
        await loadInitialData()
    }
    
    func installServer(_ server: MCPServer, toClient clientType: MCPClientType, command: String, args: [String], env: [String: String]?) async throws {
        try await ConfigFileService.shared.installServer(server, toClient: clientType, command: command, args: args, env: env)
        await discoverClients()
    }
    
    func uninstallServer(_ serverName: String, fromClient clientType: MCPClientType) async throws {
        try await ConfigFileService.shared.uninstallServer(serverName, fromClient: clientType)
        await discoverClients()
    }
    
    func clearError() {
        error = nil
    }
}

// MARK: - Sidebar Section

enum SidebarSection: Hashable {
    case installed
    case browse
    case skills
    case client(MCPClientType)
    
    var displayName: String {
        switch self {
        case .installed: return "Installed Servers"
        case .browse: return "MCP Servers"
        case .skills: return "Agent Skills"
        case .client(let type): return type.displayName
        }
    }
    
    var systemIcon: String {
        switch self {
        case .installed: return "checkmark.circle.fill"
        case .browse: return "server.rack"
        case .skills: return "sparkles"
        case .client(let type): return type.systemIcon
        }
    }
}
