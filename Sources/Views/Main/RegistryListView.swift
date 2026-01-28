import SwiftUI

// Note: Only MCP Registry has a free public API
// Other MCP directories require authentication or don't have APIs

struct RegistryListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = RegistryViewModel()
    @State private var selectedServer: MCPServer?

    var body: some View {
        HSplitView {
            serverList
                .frame(minWidth: 350, idealWidth: 450)

            Group {
                if let server = selectedServer {
                    GlassServerDetailView(server: server)
                } else {
                    EmptyStateView(
                        title: "Select a Server",
                        message: "Choose a server from the list to view details.",
                        systemImage: "server.rack",
                        color: GlassDesign.Accent.indigo
                    )
                }
            }
            .frame(minWidth: 400)
        }
        .navigationTitle("MCP Registry")
    }

    private var serverList: some View {
        VStack(spacing: 0) {
            // Glass search bar
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    // Search field
                    GlassSearchField(
                        text: $viewModel.searchText,
                        placeholder: "Search servers..."
                    )

                    // Refresh button
                    GlassIconButton(
                        icon: "arrow.clockwise",
                        isLoading: appState.isLoadingRegistry
                    ) {
                        Task { await appState.refreshAll() }
                    }
                }

                // Filter pills
                HStack(spacing: 10) {
                    // Type filter
                    GlassFilterPill(
                        icon: "cube.box",
                        title: viewModel.selectedPackageType?.displayName ?? "All Types",
                        isActive: viewModel.selectedPackageType != nil
                    ) {
                        // Cycle through options
                        let types: [PackageRegistryType?] = [nil] + PackageRegistryType.allCases.map { $0 }
                        if let current = viewModel.selectedPackageType,
                           let idx = types.firstIndex(where: { $0 == current }),
                           idx < types.count - 1 {
                            viewModel.selectedPackageType = types[idx + 1]
                        } else {
                            viewModel.selectedPackageType = types.first ?? nil
                        }
                    }

                    // Sort picker
                    GlassFilterPill(
                        icon: viewModel.sortOption.systemImage,
                        title: viewModel.sortOption.rawValue,
                        isActive: true
                    ) {
                        // Cycle through sort options
                        let options = SortOption.allCases
                        if let idx = options.firstIndex(of: viewModel.sortOption),
                           idx < options.count - 1 {
                            viewModel.sortOption = options[idx + 1]
                        } else {
                            viewModel.sortOption = options.first!
                        }
                    }

                    Spacer()

                    // Count badge
                    Text("\(viewModel.filteredServers(from: appState.registryServers, metadata: appState.gitHubMetadata).count) servers")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Server list
            if appState.isLoadingRegistry {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: GlassDesign.Accent.indigo))
                        .scaleEffect(1.2)
                    Text("Loading servers...")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 12)
                    Spacer()
                }
            } else {
                let filteredServers = viewModel.filteredServers(from: appState.registryServers, metadata: appState.gitHubMetadata)

                if filteredServers.isEmpty {
                    EmptyStateView(
                        title: "No Servers Found",
                        message: viewModel.searchText.isEmpty
                            ? "The registry appears to be empty."
                            : "Try adjusting your search or filters.",
                        systemImage: "magnifyingglass",
                        color: GlassDesign.Accent.indigo
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredServers) { server in
                                GlassServerCard(
                                    server: server,
                                    isSelected: selectedServer == server
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedServer = server
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
}

// MARK: - Glass Server Detail View

struct GlassServerDetailView: View {
    @EnvironmentObject var appState: AppState
    let server: MCPServer

    @State private var copiedConfig = false

    /// Auth credentials required by this server
    private var authCredentials: [MCPEnvironmentVariable] {
        server.primaryPackage?.environmentVariables?.filter { $0.isSecret == true } ?? []
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Description
                if let description = server.description {
                    GlassDetailSection(title: "Description", icon: "text.alignleft") {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                // Packages
                packagesSection

                // Authentication
                if !authCredentials.isEmpty {
                    authenticationSection
                }

                // Configuration
                configurationSection
            }
            .padding(24)
        }
        .navigationTitle(server.displayName)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Large icon
                GlassServerIcon(url: server.iconURL, size: 64)

                VStack(alignment: .leading, spacing: 6) {
                    Text(server.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(server.name)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .textSelection(.enabled)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                // Repository link
                if let repoURL = server.repository?.url,
                   !repoURL.isEmpty,
                   let url = URL(string: repoURL) {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Repo")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(GlassButtonStyle(color: GlassDesign.Semantic.info, isCompact: true))
                }
            }

            // Badges row
            HStack(spacing: 8) {
                if let version = server.version {
                    GlassBadge(text: "v\(version)", color: GlassDesign.Accent.cyan)
                }

                if !authCredentials.isEmpty {
                    GlassBadge(
                        text: "\(authCredentials.count) credential\(authCredentials.count == 1 ? "" : "s")",
                        color: GlassDesign.Semantic.warning,
                        icon: "lock.fill"
                    )
                }

                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusLarge)
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusLarge)
                .stroke(GlassDesign.Glass.borderSubtle, lineWidth: 1)
        )
    }

    private var packagesSection: some View {
        GlassDetailSection(title: "Packages", icon: "cube.box") {
            if server.packages.isEmpty {
                Text("No packages available for this server.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            } else {
                VStack(spacing: 12) {
                    ForEach(server.packages) { package in
                        GlassPackageCard(package: package)
                    }
                }
            }
        }
    }

    private var authenticationSection: some View {
        GlassDetailSection(title: "Authentication Required", icon: "lock.fill") {
            VStack(spacing: 10) {
                ForEach(authCredentials) { credential in
                    GlassCredentialCard(credential: credential)
                }
            }
        }
    }

    private var configurationSection: some View {
        GlassDetailSection(title: "Configuration", icon: "doc.text") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Add this to your MCP client configuration file:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))

                GlassCodeBlock(code: configurationJSON, language: "json") {
                    copiedConfig = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedConfig = false
                    }
                }
            }
        }
    }

    private var configurationJSON: String {
        guard let package = server.primaryPackage else {
            return "// No package information available"
        }

        let serverKey = server.displayName.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")

        var args: [String] = []
        switch package.registryType {
        case .npm:
            args = ["-y", package.identifier]
        case .pypi:
            args = [package.identifier]
        default:
            args = [package.identifier]
        }

        let argsString = args.map { "\"\($0)\"" }.joined(separator: ", ")

        let envSection: String
        if let envVars = package.environmentVariables, !envVars.isEmpty {
            let envEntries = envVars.map { "\"\($0.name)\": \"YOUR_\($0.name)\"" }.joined(separator: ",\n      ")
            envSection = ",\n    \"env\": {\n      \(envEntries)\n    }"
        } else {
            envSection = ""
        }

        return """
        "\(serverKey)": {
          "command": "\(package.registryType.installCommand)",
          "args": [\(argsString)]\(envSection)
        }
        """
    }
}

// MARK: - Glass Package Card

struct GlassPackageCard: View {
    let package: MCPPackage

    var body: some View {
        HStack(spacing: 12) {
            PackageTypeBadge(type: package.registryType)

            Text(package.identifier)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .textSelection(.enabled)

            Spacer()

            if let transport = package.transport {
                TransportTypeBadge(type: transport.type)
            }

            Button(action: {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(package.identifier, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "1E1E2E").opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(GlassDesign.Glass.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Glass Credential Card

struct GlassCredentialCard: View {
    let credential: MCPEnvironmentVariable

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundColor(GlassDesign.Semantic.warning)

            VStack(alignment: .leading, spacing: 4) {
                Text(credential.name)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)

                if let description = credential.description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(GlassDesign.Semantic.warning.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(GlassDesign.Semantic.warning.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Legacy Views (for backward compatibility)

struct RegistryServerRow: View {
    @EnvironmentObject var appState: AppState
    let server: MCPServer
    @State private var isHovered = false

    var body: some View {
        GlassServerCard(server: server, isSelected: false) {}
    }
}

struct PackageInfoCard: View {
    let package: MCPPackage

    var body: some View {
        GlassPackageCard(package: package)
    }
}

struct AuthCredentialCard: View {
    let credential: MCPEnvironmentVariable

    var body: some View {
        GlassCredentialCard(credential: credential)
    }
}

// MARK: - Stars Badge

struct StarsBadge: View {
    let count: Int

    private var formattedCount: String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(GlassDesign.Semantic.warning)
            Text(formattedCount)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.7))
    }
}

// MARK: - Archived Badge

struct ArchivedBadge: View {
    var body: some View {
        GlassBadge(text: "Archived", color: GlassDesign.Semantic.error, icon: "archivebox.fill")
    }
}
