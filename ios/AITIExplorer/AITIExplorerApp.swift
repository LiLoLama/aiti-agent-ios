import SwiftUI

@main
struct AITIExplorerApp: App {
    @StateObject private var appState: AppState

    init() {
        do {
            let configuration = try SupabaseConfigurationLoader.load()
            let authService = SupabaseAuthService(configuration: configuration)
            _appState = StateObject(wrappedValue: AppState(authService: authService))
        } catch {
            assertionFailure("Supabase-Konfiguration konnte nicht geladen werden: \(error.localizedDescription)")
            _appState = StateObject(wrappedValue: AppState())
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
