import SwiftUI

enum ExplorerTheme {
    static let backgroundTop = Color(hex: "#181818")
    static let backgroundBottom = Color(hex: "#101010")
    static let surface = Color(hex: "#212121")
    static let surfaceElevated = Color(hex: "#2a2a2a")
    static let divider = Color.white.opacity(0.08)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textMuted = Color.white.opacity(0.48)
    static let goldHighlightStart = Color(hex: "#FACF39")
    static let goldHighlightEnd = Color(hex: "#f9c307")
    static let success = Color(hex: "#34D399")
    static let danger = Color(hex: "#F87171")
    static let info = Color(hex: "#38BDF8")

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var goldGradient: LinearGradient {
        LinearGradient(
            colors: [goldHighlightStart, goldHighlightEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? surface : Color.white
    }

    static func secondaryCardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? surfaceElevated : Color(hex: "#f5f5f5")
    }

    static func baseBackground(for colorScheme: ColorScheme) -> some View {
        Group {
            if colorScheme == .dark {
                backgroundGradient
            } else {
                LinearGradient(
                    colors: [Color.white, Color(hex: "#f4f6fb")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

extension Color {
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hexSanitized.count {
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

extension Font {
    static func explorer(_ style: TextStyle, weight: Weight = .regular) -> Font {
        let size: CGFloat
        switch style {
        case .largeTitle: size = 34
        case .title: size = 28
        case .title2: size = 24
        case .title3: size = 20
        case .headline: size = 17
        case .subheadline: size = 15
        case .body: size = 17
        case .callout: size = 16
        case .footnote: size = 13
        case .caption: size = 12
        case .caption2: size = 11
        @unknown default: size = 17
        }

        return Font.custom("Inter", size: size, relativeTo: style).weight(weight)
    }
}

struct ExplorerCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var stroke: Bool

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(ExplorerTheme.cardBackground(for: colorScheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(
                                ExplorerTheme.goldHighlightStart.opacity(stroke ? 0.25 : 0.12),
                                lineWidth: stroke ? 1.2 : 0.8
                            )
                    )
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.08), radius: 24, x: 0, y: 18)
            )
    }
}

extension View {
    func explorerCard(stroke: Bool = false) -> some View {
        modifier(ExplorerCardModifier(stroke: stroke))
    }

    func explorerBackground() -> some View {
        modifier(ExplorerBackgroundModifier())
    }
}

struct ExplorerPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ExplorerPrimaryButton(configuration: configuration)
    }

    private struct ExplorerPrimaryButton: View {
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration

        var body: some View {
            configuration.label
                .font(.explorer(.headline, weight: .semibold))
                .foregroundStyle(
                    Color.black.opacity(
                        configuration.isPressed ? 0.8 : (isEnabled ? 0.92 : 0.45)
                    )
                )
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    ExplorerTheme.goldGradient
                        .opacity(
                            configuration.isPressed ? 0.85 : (isEnabled ? 1 : 0.55)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 0.6)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(
                    color: ExplorerTheme.goldHighlightEnd.opacity(configuration.isPressed ? 0.15 : (isEnabled ? 0.35 : 0.15)),
                    radius: 16,
                    x: 0,
                    y: 12
                )
                .scaleEffect(configuration.isPressed ? 0.99 : 1)
                .opacity(isEnabled ? 1 : 0.7)
        }
    }
}

struct ExplorerSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.explorer(.callout, weight: .medium))
            .foregroundStyle(ExplorerTheme.textPrimary.opacity(configuration.isPressed ? 0.8 : 0.95))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.05 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(ExplorerTheme.goldHighlightStart.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.18 : 0.28), radius: 18, x: 0, y: 16)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct ExplorerBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                ExplorerTheme.baseBackground(for: colorScheme)
                    .ignoresSafeArea()
            )
    }
}

struct ExplorerSectionHeader: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.explorer(.caption, weight: .semibold))
            .foregroundStyle(ExplorerTheme.textSecondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

extension View {
    func explorerSectionHeader() -> some View {
        modifier(ExplorerSectionHeader())
    }
}
