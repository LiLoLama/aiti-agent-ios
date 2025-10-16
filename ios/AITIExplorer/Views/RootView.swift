import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.currentUser != nil {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: appState.currentUser)
        .explorerBackground()
    }
}

#Preview {
    RootView()
        .environmentObject(AppState(previewUser: SampleData.previewUser))
}
