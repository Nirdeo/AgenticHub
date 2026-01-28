import SwiftUI

// MARK: - Glass Search Field (Legacy compatibility)

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        GlassSearchField(text: $text, placeholder: placeholder)
    }
}

// MARK: - Glass Filter Pill

struct GlassFilterPill: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(isActive ? GlassDesign.Accent.indigo : .white.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isActive {
                        Capsule()
                            .fill(GlassDesign.Accent.indigo.opacity(0.15))
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial.opacity(0.3))
                    }
                }
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive
                            ? GlassDesign.Accent.indigo.opacity(0.3)
                            : GlassDesign.Glass.borderSubtle,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Glass Server Card

struct GlassServerCard: View {
    @EnvironmentObject var appState: AppState
    let server: MCPServer
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    private var metadata: GitHubMetadata? {
        appState.getMetadata(for: server)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Server icon with glow
                GlassServerIcon(url: server.iconURL, size: 48, isHovered: isHovered)

                VStack(alignment: .leading, spacing: 8) {
                    // Title row
                    HStack {
                        Text(server.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer()

                        // GitHub stars
                        if let meta = metadata {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(GlassDesign.Semantic.warning)
                                Text(formatNumber(meta.stars))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    // Description
                    if let description = server.description {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    // Badges row
                    HStack(spacing: 8) {
                        // Transport type badge
                        if let firstTransport = server.uniqueTransportTypes.first {
                            GlassBadge(
                                text: firstTransport.displayName,
                                color: transportColor(for: firstTransport),
                                icon: transportIcon(for: firstTransport)
                            )
                        }

                        // Package type badge
                        if let registryType = server.primaryPackage?.registryType {
                            GlassBadge(
                                text: registryType.displayName,
                                color: registryColor(for: registryType),
                                icon: "cube.box.fill"
                            )
                        }

                        Spacer()

                        // Archived badge
                        if metadata?.archived == true {
                            GlassBadge(
                                text: "Archived",
                                color: GlassDesign.Semantic.error,
                                icon: "archivebox.fill"
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusMedium)
                    .fill(.ultraThinMaterial.opacity(isHovered || isSelected ? 0.6 : 0.3))
            )
            .background(
                RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusMedium)
                    .fill(isSelected ? GlassDesign.Accent.indigo.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusMedium)
                    .stroke(
                        GlassDesign.glassBorderGradient(isActive: isHovered || isSelected),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: .black.opacity(isHovered ? 0.2 : 0.1),
                radius: isHovered ? 15 : 8,
                y: isHovered ? 8 : 4
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func formatNumber(_ num: Int) -> String {
        if num >= 1000 {
            return String(format: "%.1fk", Double(num) / 1000)
        }
        return "\(num)"
    }

    private func transportColor(for transport: TransportType) -> Color {
        switch transport {
        case .stdio: return GlassDesign.Semantic.success
        case .sse: return GlassDesign.Semantic.warning
        case .streamableHttp: return GlassDesign.Semantic.info
        case .unknown: return .gray
        }
    }

    private func transportIcon(for transport: TransportType) -> String? {
        switch transport {
        case .stdio: return "terminal.fill"
        case .sse: return "arrow.triangle.branch"
        case .streamableHttp: return "network"
        case .unknown: return nil
        }
    }

    private func registryColor(for registry: PackageRegistryType) -> Color {
        switch registry {
        case .npm: return .red
        case .pypi: return GlassDesign.Semantic.info
        case .oci: return GlassDesign.Accent.cyan
        case .mcpb: return GlassDesign.Accent.purple
        case .unknown: return .gray
        }
    }
}

// MARK: - Glass Server Icon

struct GlassServerIcon: View {
    let url: URL?
    let size: CGFloat
    var isHovered: Bool = false

    @State private var image: NSImage?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            // Glow effect on hover
            if isHovered {
                Circle()
                    .fill(GlassDesign.Accent.indigo.opacity(0.3))
                    .blur(radius: 12)
                    .frame(width: size + 10, height: size + 10)
            }

            RoundedRectangle(cornerRadius: size * 0.27)
                .fill(Color(hex: "1E1E2E"))
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.27)
                        .stroke(
                            isHovered
                                ? GlassDesign.accentGradient
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                            lineWidth: 1
                        )
                )

            Group {
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size * 0.6, height: size * 0.6)
                } else if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "server.rack")
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(GlassDesign.accentGradient)
                }
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = url else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let nsImage = NSImage(data: data) {
                await MainActor.run {
                    image = nsImage
                }
            }
        } catch {
            // Use fallback icon
        }
    }
}

// MARK: - Glass Skill Card

struct GlassSkillCard: View {
    let skill: AgentSkill
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Skill icon with glow
                GlassSkillIcon(size: 48, isHovered: isHovered)

                VStack(alignment: .leading, spacing: 8) {
                    // Title row
                    HStack {
                        Text(skill.displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Spacer()

                        // Install count
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(GlassDesign.Semantic.success)
                            Text(skill.formattedInstalls)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }

                    // Description
                    if let description = skill.description {
                        Text(description)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    // Badges row
                    HStack(spacing: 8) {
                        GlassBadge(
                            text: "AI Skill",
                            color: GlassDesign.Accent.purple,
                            icon: "wand.and.stars"
                        )

                        if let ownerRepo = skill.sourceOwnerRepo {
                            GlassBadge(
                                text: ownerRepo,
                                color: GlassDesign.Semantic.info,
                                icon: "link"
                            )
                        }

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusMedium)
                    .fill(.ultraThinMaterial.opacity(isHovered || isSelected ? 0.6 : 0.3))
            )
            .background(
                RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusMedium)
                    .fill(isSelected ? GlassDesign.Accent.purple.opacity(0.15) : Color.clear)
            )
            .overlay(
                Group {
                    if isHovered || isSelected {
                        RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusMedium)
                            .stroke(GlassDesign.purplePinkGradient, lineWidth: 1)
                    } else {
                        RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusMedium)
                            .stroke(GlassDesign.glassBorderGradient(isActive: false), lineWidth: 1)
                    }
                }
            )
            .shadow(
                color: .black.opacity(isHovered ? 0.2 : 0.1),
                radius: isHovered ? 15 : 8,
                y: isHovered ? 8 : 4
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Glass Skill Icon

struct GlassSkillIcon: View {
    var size: CGFloat = 48
    var isHovered: Bool = false

    var body: some View {
        ZStack {
            // Glow effect on hover
            if isHovered {
                Circle()
                    .fill(GlassDesign.Accent.purple.opacity(0.3))
                    .blur(radius: 12)
                    .frame(width: size + 10, height: size + 10)
            }

            RoundedRectangle(cornerRadius: size * 0.27)
                .fill(Color(hex: "1E1E2E"))
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.27)
                        .stroke(
                            isHovered
                                ? GlassDesign.purplePinkGradient
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                            lineWidth: 1
                        )
                )

            Image(systemName: "sparkles")
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(GlassDesign.purplePinkGradient)
        }
    }
}

// MARK: - Glass Section Header

struct GlassSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var color: Color = .white

    var body: some View {
        HStack(spacing: 10) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()
        }
    }
}

// MARK: - Glass Code Block

struct GlassCodeBlock: View {
    let code: String
    var language: String? = nil
    var onCopy: (() -> Void)? = nil

    @State private var isCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if let language = language {
                    Text(language)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    isCopied = true
                    onCopy?()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isCopied = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied!" : "Copy")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.2))

            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "1A1A2E"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(GlassDesign.Glass.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Glass Detail Section

struct GlassDetailSection<Content: View>: View {
    let title: String
    var icon: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(GlassDesign.Accent.indigo)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusMedium)
                .fill(.ultraThinMaterial.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: GlassDesign.Dimensions.cornerRadiusMedium)
                .stroke(GlassDesign.Glass.borderSubtle, lineWidth: 1)
        )
    }
}

// MARK: - Legacy Badge Components (for backward compatibility)

struct VibrantBadge: View {
    let text: String
    let color: Color
    let icon: String?

    var body: some View {
        GlassBadge(text: text, color: color, icon: icon)
    }
}

struct ColoredBadge: View {
    let text: String
    let color: Color
    var font: Font = .caption2
    var fontWeight: Font.Weight = .medium

    var body: some View {
        Text(text)
            .font(font)
            .fontWeight(fontWeight)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .cornerRadius(4)
    }
}

struct PackageTypeBadge: View {
    let type: PackageRegistryType

    private var color: Color {
        switch type {
        case .npm: return .red
        case .pypi: return .blue
        case .oci: return .cyan
        case .mcpb: return .purple
        case .unknown: return .gray
        }
    }

    var body: some View {
        GlassBadge(text: type.displayName, color: color, icon: "cube.box.fill")
    }
}

struct TransportTypeBadge: View {
    let type: TransportType

    private var color: Color {
        switch type {
        case .stdio: return .green
        case .sse: return .orange
        case .streamableHttp: return .blue
        case .unknown: return .gray
        }
    }

    var body: some View {
        GlassBadge(text: type.displayName, color: color)
    }
}

// MARK: - Legacy Icon Views

struct ServerIconView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        GlassServerIcon(url: url, size: size)
    }
}

// MARK: - Filter Pill (Legacy)

struct FilterPill: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        GlassFilterPill(icon: icon, title: title, isActive: isActive, action: action)
    }
}

// MARK: - Client Badges

struct ClientBadge: View {
    let clientType: MCPClientType
    var size: CGFloat = 24
    var showBorder: Bool = true

    var body: some View {
        Image(systemName: clientType.systemIcon)
            .font(.system(size: size * 0.5))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(clientType.accentColor)
            .clipShape(Circle())
            .overlay {
                if showBorder {
                    Circle()
                        .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 2)
                }
            }
            .help(clientType.displayName)
    }
}

struct ClientBadgeStack: View {
    let clientTypes: [MCPClientType]
    var size: CGFloat = 20
    var overlap: CGFloat = -6

    var body: some View {
        HStack(spacing: overlap) {
            ForEach(clientTypes, id: \.self) { clientType in
                ClientBadge(clientType: clientType, size: size)
            }
        }
    }
}

struct ClientTypeToggle: View {
    let clientType: MCPClientType
    @Binding var isSelected: Bool

    var body: some View {
        Button(action: { isSelected.toggle() }) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)

                Image(systemName: clientType.systemIcon)
                    .font(.title3)
                    .foregroundStyle(clientType.accentColor)
                    .frame(width: 24)

                Text(clientType.displayName)
                    .font(.subheadline.weight(.medium))

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Glass Components") {
    ZStack {
        AnimatedGlassBackground()

        VStack(spacing: 20) {
            GlassSearchField(text: .constant("Search..."))

            GlassFilterPill(icon: "cube.box", title: "All Types", isActive: false) {}

            GlassSectionHeader(title: "Packages", subtitle: "Available packages", icon: "cube.box")

            GlassCodeBlock(code: "npm install @modelcontextprotocol/server", language: "bash")
        }
        .padding(40)
    }
    .frame(width: 500, height: 500)
}
