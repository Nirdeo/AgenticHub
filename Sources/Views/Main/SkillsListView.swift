import SwiftUI

// MARK: - Skills Source Enum
// Note: Only Skills.sh has a free public API
// SkillsMP requires API key authentication

enum SkillsSource: String, CaseIterable, Identifiable {
    case skillsSh = "Skills.sh"

    var id: String { rawValue }

    var color: Color {
        return GlassDesign.Accent.purple
    }
}

struct SkillsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedSkill: AgentSkill?
    @State private var searchResults: [AgentSkill] = []
    @State private var isSearching = false
    @State private var sortOption: SkillSortOption = .installs

    var body: some View {
        HSplitView {
            skillList
                .frame(minWidth: 350, idealWidth: 450)

            Group {
                if let skill = selectedSkill {
                    GlassSkillDetailView(skill: skill)
                } else {
                    EmptyStateView(
                        title: "Select a Skill",
                        message: "Choose a skill from the list to view details.",
                        systemImage: "sparkles",
                        color: GlassDesign.Accent.purple
                    )
                }
            }
            .frame(minWidth: 400)
        }
        .navigationTitle("Agent Skills")
    }

    private var skillList: some View {
        VStack(spacing: 0) {
            // Glass search bar
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    // Search field
                    GlassSearchField(
                        text: $searchText,
                        placeholder: "Search skills..."
                    )
                    .onChange(of: searchText) { _, newValue in
                        Task {
                            await performSearch(query: newValue)
                        }
                    }

                    // Refresh button
                    GlassIconButton(
                        icon: "arrow.clockwise",
                        isLoading: appState.isLoadingSkills
                    ) {
                        Task { await appState.loadSkills() }
                    }
                }

                // Filter pills
                HStack(spacing: 10) {
                    // Sort filter
                    GlassFilterPill(
                        icon: sortOption.systemImage,
                        title: sortOption.rawValue,
                        isActive: true
                    ) {
                        // Cycle through sort options
                        let options = SkillSortOption.allCases
                        if let idx = options.firstIndex(of: sortOption),
                           idx < options.count - 1 {
                            sortOption = options[idx + 1]
                        } else {
                            sortOption = options.first!
                        }
                    }

                    Spacer()

                    // Count badge
                    Text("\(filteredAndSortedSkills.count) skills")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Skills list
            if appState.isLoadingSkills {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: GlassDesign.Accent.purple))
                        .scaleEffect(1.2)
                    Text("Loading skills...")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 12)
                    Spacer()
                }
            } else {
                let displaySkills = filteredAndSortedSkills

                if displaySkills.isEmpty {
                    EmptyStateView(
                        title: "No Skills Found",
                        message: searchText.isEmpty
                            ? "Skills will appear here once loaded."
                            : "Try a different search term.",
                        systemImage: "sparkles",
                        color: GlassDesign.Accent.purple
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(displaySkills) { skill in
                                GlassSkillCard(
                                    skill: skill,
                                    isSelected: selectedSkill == skill
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedSkill = skill
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

    private var filteredAndSortedSkills: [AgentSkill] {
        let skills = searchText.isEmpty ? appState.skills : searchResults

        return skills.sorted { s1, s2 in
            switch sortOption {
            case .installs:
                return s1.installs > s2.installs
            case .name:
                return s1.displayName.lowercased() < s2.displayName.lowercased()
            }
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        searchResults = await appState.searchSkills(query: query)
    }
}

// MARK: - Glass Skill Detail View

struct GlassSkillDetailView: View {
    @EnvironmentObject var appState: AppState
    let skill: AgentSkill

    @State private var copiedCommand = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Description
                GlassDetailSection(title: "About", icon: "text.alignleft") {
                    if let description = skill.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("No description available.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                            .italic()
                    }
                }

                // Installation
                installSection

                // Source
                sourceSection
            }
            .padding(24)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Large icon
                GlassSkillIcon(size: 64, isHovered: false)

                VStack(alignment: .leading, spacing: 6) {
                    Text(skill.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let ownerRepo = skill.sourceOwnerRepo {
                        Text(ownerRepo)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 10)
            }

            // Stats and badges row
            HStack(spacing: 12) {
                // Installs badge
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(GlassDesign.Semantic.success)
                    Text(skill.formattedInstalls)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text("installs")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }

                GlassBadge(text: "AI Skill", color: GlassDesign.Accent.purple, icon: "wand.and.stars")

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

    private var installSection: some View {
        GlassDetailSection(title: "Installation", icon: "square.and.arrow.down") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Run this command in your terminal:")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))

                GlassCodeBlock(code: skill.installCommand, language: "bash") {
                    copiedCommand = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedCommand = false
                    }
                }

                Text("Copy this command and run it in your terminal to install the skill.")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var sourceSection: some View {
        GlassDetailSection(title: "Source", icon: "link") {
            HStack(spacing: 12) {
                if let repoUrl = skill.repositoryUrl, let url = URL(string: repoUrl) {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                            Text("View on GitHub")
                        }
                        .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(GlassButtonStyle(color: GlassDesign.Semantic.info, isCompact: true))
                }

                Link(destination: URL(string: "https://skills.sh/\(skill.source)")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                        Text("View on Skills.sh")
                    }
                    .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(GlassButtonStyle(color: GlassDesign.Accent.purple, isCompact: true))

                Spacer()
            }
        }
    }
}

// MARK: - Legacy Skill Row

struct SkillRow: View {
    let skill: AgentSkill
    @State private var isHovered = false

    var body: some View {
        GlassSkillCard(skill: skill, isSelected: false) {}
    }
}

// MARK: - Installs Badge

struct InstallsBadge: View {
    let count: Int

    private var formattedCount: String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000)
        } else if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000)
        }
        return "\(count)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(GlassDesign.Semantic.success)
            Text(formattedCount)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.7))
    }
}

// MARK: - Sort Option

enum SkillSortOption: String, CaseIterable, Identifiable {
    case installs = "Most Installed"
    case name = "Name"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .installs: return "arrow.down.circle.fill"
        case .name: return "textformat.abc"
        }
    }
}

// MARK: - Source Badge

struct SourceBadge: View {
    let source: String
    var color: Color = GlassDesign.Semantic.info

    var body: some View {
        GlassBadge(text: source, color: color, icon: "link")
    }
}

#Preview {
    SkillsListView()
        .environmentObject(AppState())
}
