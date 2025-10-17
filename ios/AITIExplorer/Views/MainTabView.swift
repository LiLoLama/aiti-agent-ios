import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.black.opacity(0.6))
        appearance.shadowImage = UIImage()
        appearance.shadowColor = .clear
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(ExplorerTheme.goldHighlightStart)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(ExplorerTheme.goldHighlightStart)
        ]
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(ExplorerTheme.textMuted)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(ExplorerTheme.textMuted)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ChatContainerView()
                .tabItem {
                    Image(systemName: "message.fill")
                        .accessibilityLabel("Workspace")
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
