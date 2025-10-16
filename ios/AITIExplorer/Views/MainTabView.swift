import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ChatContainerView()
                .tabItem {
                    Label("Chat", systemImage: "message.fill")
                }
                .tag(AppState.Tab.chat)

            SettingsScreen()
                .tabItem {
                    Label("Einstellungen", systemImage: "gear")
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
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState(previewUser: SampleData.previewUser))
}
