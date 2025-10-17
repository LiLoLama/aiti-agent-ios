import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundEffect = nil
        appearance.backgroundColor = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 12 / 255, green: 12 / 255, blue: 14 / 255, alpha: 0.92)
            }
            return UIColor(red: 250 / 255, green: 250 / 255, blue: 252 / 255, alpha: 0.96)
        }
        appearance.shadowImage = UIImage()
        appearance.shadowColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0, alpha: 0.0)
                : UIColor(white: 0, alpha: 0.08)
        }

        let selectedColor = UIColor(ExplorerTheme.goldHighlightStart)
        let normalColor = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(white: 1, alpha: 0.7)
            }
            return UIColor(red: 56 / 255, green: 63 / 255, blue: 82 / 255, alpha: 0.9)
        }

        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor
        ]

        appearance.inlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.inlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor
        ]
        appearance.inlineLayoutAppearance.normal.iconColor = normalColor
        appearance.inlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor
        ]

        appearance.compactInlineLayoutAppearance.selected.iconColor = selectedColor
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor
        ]
        appearance.compactInlineLayoutAppearance.normal.iconColor = normalColor
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ChatContainerView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .tag(AppState.Tab.chat)

            SettingsScreen()
                .tabItem {
                    Label("Einstellungen", systemImage: "sparkles")
                }
                .tag(AppState.Tab.settings)

            ProfileScreen()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
                .tag(AppState.Tab.profile)
        }
        .tint(appState.settings.accentColor.color)
        .preferredColorScheme(appState.settings.colorScheme.preferredScheme)
        .explorerBackground()
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState(previewUser: SampleData.previewUser))
}
