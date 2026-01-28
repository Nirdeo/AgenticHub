import SwiftUI

// MARK: - Main Window View

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: NavigationTab = .servers
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Animated background
            AnimatedGlassBackground()

            // Main layout with sidebar
            HStack(spacing: 0) {
                // Glass sidebar navigation
                GlassSidebar(selectedTab: $selectedTab)

                // Content area
                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Tab content
                    tabContent
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .task {
            await appState.loadInitialData()
        }
        .alert(item: $appState.error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.localizedDescription),
                dismissButton: .default(Text("OK")) {
                    appState.clearError()
                }
            )
        }
    }

    private var headerView: some View {
        HStack(spacing: 24) {
            // Page title
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTab.rawValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text(headerSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Stats cards
            HStack(spacing: 12) {
                GlassStatCard(
                    icon: "server.rack",
                    value: "\(appState.registryServers.count)",
                    label: "servers",
                    color: GlassDesign.Accent.indigo
                )

                GlassStatCard(
                    icon: "wand.and.stars",
                    value: "\(appState.skills.count)",
                    label: "skills",
                    color: GlassDesign.Accent.purple
                )

                // Refresh button
                GlassIconButton(
                    icon: "arrow.clockwise",
                    isLoading: appState.isLoadingRegistry || appState.isLoadingSkills
                ) {
                    Task { await appState.refreshAll() }
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.05), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GlassDesign.Glass.borderSubtle)
                .frame(height: 1)
        }
    }

    private var headerSubtitle: String {
        switch selectedTab {
        case .search:
            return "Find MCP servers and agent skills"
        case .servers:
            return "Browse and install MCP servers"
        case .skills:
            return "Discover agent skills for Claude"
        case .settings:
            return "Configure your preferences"
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .search:
            // Combined search view (could be implemented later)
            RegistryListView()
        case .servers:
            RegistryListView()
        case .skills:
            SkillsListView()
        case .settings:
            SettingsPlaceholderView()
        }
    }
}

// MARK: - Glass Stat Card

struct GlassStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial.opacity(isHovered ? 0.5 : 0.3))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(GlassDesign.Glass.borderSubtle, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Glass Icon Button

struct GlassIconButton: View {
    let icon: String
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(isHovered ? 0.9 : 0.6))
                }
            }
            .frame(width: 38, height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial.opacity(isHovered ? 0.5 : 0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isHovered
                            ? GlassDesign.Glass.border
                            : GlassDesign.Glass.borderSubtle,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Settings Placeholder

struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(GlassDesign.Accent.indigo.opacity(0.1))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(GlassDesign.Accent.indigo.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: "gearshape")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(GlassDesign.Accent.indigo)
            }

            VStack(spacing: 8) {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Text("Settings panel coming soon...")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var color: Color = GlassDesign.Accent.indigo

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: systemImage)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(color)
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
