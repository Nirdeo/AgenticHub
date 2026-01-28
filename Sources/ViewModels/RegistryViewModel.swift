import SwiftUI

/// ViewModel for registry browsing
@MainActor
class RegistryViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedPackageType: PackageRegistryType? = nil
    @Published var sortOption: SortOption = .stars

    func filteredServers(from servers: [MCPServer], metadata: [String: GitHubMetadata] = [:]) -> [MCPServer] {
        var result = servers
        
        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { server in
                server.name.lowercased().contains(query) ||
                server.displayName.lowercased().contains(query) ||
                (server.description?.lowercased().contains(query) ?? false)
            }
        }

        // Apply package type filter
        if let packageType = selectedPackageType {
            result = result.filter {
                $0.packages.contains { $0.registryType == packageType }
            }
        }

        // Apply sorting
        result.sort { server1, server2 in
            switch sortOption {
            case .name:
                return server1.displayName.lowercased() < server2.displayName.lowercased()
            case .stars:
                let stars1 = metadata[server1.name]?.stars ?? 0
                let stars2 = metadata[server2.name]?.stars ?? 0
                if stars1 != stars2 {
                    return stars1 > stars2
                }
                return server1.displayName.lowercased() < server2.displayName.lowercased()
            case .recentlyUpdated:
                let date1 = metadata[server1.name]?.lastCommitAt ?? .distantPast
                let date2 = metadata[server2.name]?.lastCommitAt ?? .distantPast
                if date1 != date2 {
                    return date1 > date2
                }
                return server1.displayName.lowercased() < server2.displayName.lowercased()
            }
        }

        return result
    }

    func clearFilters() {
        searchText = ""
        selectedPackageType = nil
        sortOption = .stars
    }
}

/// Sort options for the registry list
enum SortOption: String, CaseIterable, Identifiable {
    case stars = "Most Stars"
    case name = "Name"
    case recentlyUpdated = "Recently Updated"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .stars: return "star.fill"
        case .name: return "textformat.abc"
        case .recentlyUpdated: return "clock.fill"
        }
    }
}
