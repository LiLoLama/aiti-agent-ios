import Foundation
import SwiftUI

enum ColorSchemeOption: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Hell"
        case .dark:
            return "Dunkel"
        }
    }

    var preferredScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AccentColorOption: String, CaseIterable, Identifiable, Codable {
    case gold
    case emerald
    case indigo
    case orange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gold:
            return "Gold"
        case .emerald:
            return "Smaragd"
        case .indigo:
            return "Indigo"
        case .orange:
            return "Orange"
        }
    }

    var color: Color {
        switch self {
        case .gold:
            return ExplorerTheme.goldHighlightStart
        case .emerald:
            return Color(red: 0.19, green: 0.69, blue: 0.49)
        case .indigo:
            return Color(red: 0.35, green: 0.4, blue: 0.94)
        case .orange:
            return Color(red: 0.99, green: 0.57, blue: 0.23)
        }
    }
}

struct AgentSettingsModel: Codable, Hashable {
    var colorScheme: ColorSchemeOption
    var accentColor: AccentColorOption

    static let `default` = AgentSettingsModel(
        colorScheme: .system,
        accentColor: .gold
    )
}
