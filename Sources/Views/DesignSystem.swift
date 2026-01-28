import SwiftUI

// MARK: - Design Tokens

/// Centralized design system for the AgenticHub glassmorphism UI
enum GlassDesign {
    // MARK: - Colors

    /// Deep navy background colors for gradient mesh
    enum Background {
        static let deepNavy = Color(hex: "1a1a2e")
        static let darkBlue = Color(hex: "16213e")
        static let navy = Color(hex: "0f3460")
        static let darkest = Color(hex: "0F0F1A")
    }

    /// Accent colors
    enum Accent {
        static let violet = Color(hex: "7c3aed")
        static let purple = Color(hex: "a855f7")
        static let cyan = Color(hex: "06b6d4")
        static let indigo = Color(hex: "6366F1")
        static let pink = Color(hex: "EC4899")
    }

    /// Semantic colors
    enum Semantic {
        static let success = Color(hex: "10b981")
        static let warning = Color(hex: "f59e0b")
        static let error = Color(hex: "EF4444")
        static let info = Color(hex: "3B82F6")
    }

    /// Glass surface colors
    enum Glass {
        static let border = Color.white.opacity(0.15)
        static let borderSubtle = Color.white.opacity(0.1)
        static let highlight = Color.white.opacity(0.1)
        static let surfaceLight = Color.white.opacity(0.05)
        static let surfaceHover = Color.white.opacity(0.08)
    }

    // MARK: - Dimensions

    enum Dimensions {
        static let cornerRadiusSmall: CGFloat = 10
        static let cornerRadiusMedium: CGFloat = 14
        static let cornerRadiusLarge: CGFloat = 20
        static let cornerRadiusXLarge: CGFloat = 24

        static let sidebarCollapsed: CGFloat = 70
        static let sidebarExpanded: CGFloat = 200

        static let cardPadding: CGFloat = 16
        static let contentPadding: CGFloat = 20

        static let iconSizeSmall: CGFloat = 32
        static let iconSizeMedium: CGFloat = 44
        static let iconSizeLarge: CGFloat = 64
    }

    // MARK: - Gradients

    /// Primary accent gradient
    static let accentGradient = LinearGradient(
        colors: [Accent.indigo, Accent.purple, Accent.violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Purple to pink gradient
    static let purplePinkGradient = LinearGradient(
        colors: [Accent.purple, Accent.pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Background mesh gradient
    static let backgroundGradient = LinearGradient(
        colors: [
            Background.darkest,
            Background.deepNavy,
            Background.darkBlue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle glass border gradient
    static func glassBorderGradient(isActive: Bool = false) -> LinearGradient {
        if isActive {
            return LinearGradient(
                colors: [Accent.indigo.opacity(0.5), Accent.purple.opacity(0.3)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [Glass.border, Glass.borderSubtle],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Animated Background

/// Animated orb for background effects
struct BackgroundOrb: Identifiable {
    let id = UUID()
    var color: Color
    var size: CGFloat
    var position: CGPoint
    var blur: CGFloat
    var opacity: Double
    var animationDuration: Double
}

/// Animated mesh gradient background with floating orbs
struct AnimatedGlassBackground: View {
    @State private var animateOrbs = false

    private let orbs: [BackgroundOrb] = [
        BackgroundOrb(
            color: GlassDesign.Accent.indigo,
            size: 400,
            position: CGPoint(x: 0.1, y: 0.1),
            blur: 80,
            opacity: 0.15,
            animationDuration: 8
        ),
        BackgroundOrb(
            color: GlassDesign.Accent.purple,
            size: 500,
            position: CGPoint(x: 0.9, y: 0.8),
            blur: 100,
            opacity: 0.1,
            animationDuration: 10
        ),
        BackgroundOrb(
            color: GlassDesign.Semantic.info,
            size: 300,
            position: CGPoint(x: 0.5, y: 0.15),
            blur: 60,
            opacity: 0.08,
            animationDuration: 12
        ),
        BackgroundOrb(
            color: GlassDesign.Accent.cyan,
            size: 350,
            position: CGPoint(x: 0.2, y: 0.7),
            blur: 70,
            opacity: 0.06,
            animationDuration: 9
        )
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base gradient
                GlassDesign.backgroundGradient

                // Animated orbs
                ForEach(orbs) { orb in
                    Circle()
                        .fill(orb.color.opacity(orb.opacity))
                        .blur(radius: orb.blur)
                        .frame(width: orb.size, height: orb.size)
                        .position(
                            x: geo.size.width * orb.position.x + (animateOrbs ? 30 : -30),
                            y: geo.size.height * orb.position.y + (animateOrbs ? -20 : 20)
                        )
                        .animation(
                            .easeInOut(duration: orb.animationDuration)
                            .repeatForever(autoreverses: true),
                            value: animateOrbs
                        )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            animateOrbs = true
        }
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = GlassDesign.Dimensions.cornerRadiusLarge
    var padding: CGFloat = GlassDesign.Dimensions.cardPadding
    var isHovered: Bool = false
    var isSelected: Bool = false
    var showBorder: Bool = true

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .opacity(isHovered ? 0.9 : 0.7)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isSelected ? GlassDesign.Accent.indigo.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        showBorder ? (isHovered || isSelected
                            ? GlassDesign.glassBorderGradient(isActive: true)
                            : GlassDesign.glassBorderGradient(isActive: false))
                        : LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: .black.opacity(isHovered ? 0.25 : 0.15),
                radius: isHovered ? 25 : 15,
                y: isHovered ? 12 : 8
            )
    }
}

// MARK: - Glass Button Style

struct GlassButtonStyle: ButtonStyle {
    var color: Color = GlassDesign.Accent.indigo
    var isCompact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isCompact ? 13 : 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.vertical, isCompact ? 8 : 10)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 8 : 10)
                    .fill(color.opacity(configuration.isPressed ? 0.6 : 0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 8 : 10)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 4 : 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Glow Effect Modifier

struct GlowEffectModifier: ViewModifier {
    var color: Color = GlassDesign.Accent.indigo
    var radius: CGFloat = 12
    var isActive: Bool = true

    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.5) : .clear, radius: radius)
    }
}

// MARK: - Shimmer Loading Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    var isAnimating: Bool = true

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    if isAnimating {
                        LinearGradient(
                            colors: [
                                .clear,
                                .white.opacity(0.1),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 2)
                        .offset(x: phase * geo.size.width * 2 - geo.size.width)
                        .animation(
                            .linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                            value: phase
                        )
                    }
                }
                .mask(content)
            )
            .onAppear {
                if isAnimating {
                    phase = 1
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply glass card styling
    func glassCard(
        cornerRadius: CGFloat = GlassDesign.Dimensions.cornerRadiusLarge,
        padding: CGFloat = GlassDesign.Dimensions.cardPadding,
        isHovered: Bool = false,
        isSelected: Bool = false,
        showBorder: Bool = true
    ) -> some View {
        modifier(GlassCardModifier(
            cornerRadius: cornerRadius,
            padding: padding,
            isHovered: isHovered,
            isSelected: isSelected,
            showBorder: showBorder
        ))
    }

    /// Apply glow effect
    func glowEffect(
        color: Color = GlassDesign.Accent.indigo,
        radius: CGFloat = 12,
        isActive: Bool = true
    ) -> some View {
        modifier(GlowEffectModifier(color: color, radius: radius, isActive: isActive))
    }

    /// Apply shimmer loading effect
    func shimmer(isAnimating: Bool = true) -> some View {
        modifier(ShimmerModifier(isAnimating: isAnimating))
    }
}

// MARK: - Navigation Item

enum NavigationTab: String, CaseIterable, Identifiable {
    case search = "Search"
    case servers = "Servers"
    case skills = "Skills"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .servers: return "server.rack"
        case .skills: return "wand.and.stars"
        case .settings: return "gearshape"
        }
    }

    var color: Color {
        switch self {
        case .search: return GlassDesign.Accent.cyan
        case .servers: return GlassDesign.Accent.indigo
        case .skills: return GlassDesign.Accent.purple
        case .settings: return .gray
        }
    }
}

// MARK: - Sidebar Navigation Item

struct SidebarNavItem: View {
    let tab: NavigationTab
    let isSelected: Bool
    let isExpanded: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected || isHovered ? tab.color.opacity(0.2) : Color.clear)
                        .frame(width: 40, height: 40)

                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? tab.color : .white.opacity(0.6))
                }

                if isExpanded {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(SidebarButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// Custom button style for sidebar items
struct SidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Glass Sidebar

struct GlassSidebar: View {
    @Binding var selectedTab: NavigationTab
    @State private var isExpanded = false

    private let mainTabs: [NavigationTab] = [.servers, .skills]
    private let bottomTabs: [NavigationTab] = [.settings]

    var body: some View {
        VStack(spacing: 0) {
            // Logo
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(GlassDesign.accentGradient)
                        .frame(width: 36, height: 36)
                        .shadow(color: GlassDesign.Accent.purple.opacity(0.4), radius: 8)

                    Image(systemName: "cube.transparent")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AgenticHub")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("MCP & Skills")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)

            Divider()
                .background(GlassDesign.Glass.border)
                .padding(.horizontal, 12)

            // Main navigation
            VStack(spacing: 4) {
                ForEach(mainTabs) { tab in
                    SidebarNavItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        isExpanded: isExpanded
                    ) {
                        print("Tapped on \(tab.rawValue)")
                        selectedTab = tab
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)

            Spacer()

            Divider()
                .background(GlassDesign.Glass.border)
                .padding(.horizontal, 12)

            // Bottom navigation
            VStack(spacing: 4) {
                ForEach(bottomTabs) { tab in
                    SidebarNavItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        isExpanded: isExpanded
                    ) {
                        print("Tapped on \(tab.rawValue)")
                        selectedTab = tab
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
        }
        .frame(width: isExpanded ? GlassDesign.Dimensions.sidebarExpanded : GlassDesign.Dimensions.sidebarCollapsed)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.08), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .allowsHitTesting(false)
        )
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(GlassDesign.Glass.border)
                .frame(width: 1)
                .allowsHitTesting(false)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded = hovering
            }
        }
    }
}

// MARK: - Glass Search Field

struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.4))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.5))
        )
        .overlay(
            Capsule()
                .stroke(GlassDesign.Glass.border, lineWidth: 1)
        )
    }
}

// MARK: - Glass Badge

struct GlassBadge: View {
    let text: String
    var color: Color = GlassDesign.Accent.indigo
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
    }
}

// MARK: - Glass Icon Box

struct GlassIconBox: View {
    var icon: String = "server.rack"
    var size: CGFloat = 44
    var gradient: LinearGradient = GlassDesign.accentGradient
    var isHovered: Bool = false

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
                                ? gradient
                                : LinearGradient(
                                    colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                            lineWidth: 1
                        )
                )

            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(gradient)
        }
    }
}

// MARK: - Previews

#Preview("Glass Components") {
    ZStack {
        AnimatedGlassBackground()

        VStack(spacing: 20) {
            GlassSearchField(text: .constant(""))

            HStack(spacing: 8) {
                GlassBadge(text: "npm", color: .red, icon: "cube.box.fill")
                GlassBadge(text: "stdio", color: .green)
                GlassBadge(text: "Official", color: GlassDesign.Semantic.success, icon: "checkmark.seal.fill")
            }

            GlassIconBox(icon: "server.rack", isHovered: false)

            Button("Glass Button") {}
                .buttonStyle(GlassButtonStyle())
        }
        .padding(40)
    }
    .frame(width: 400, height: 400)
}
