import Foundation
import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Tab: Hashable {
        case chat
        case settings
        case profile
    }

    @Published var currentUser: UserProfile?
    @Published var settings: AgentSettingsModel
    @Published var selectedTab: Tab = .chat

    private let authService: AuthServicing
    private var cancellables = Set<AnyCancellable>()

    init(previewUser: UserProfile? = nil, authService: AuthServicing = MockAuthService()) {
        self.authService = authService
        let defaults = SampleData.defaultSettings
        self.settings = defaults
        self.currentUser = previewUser

        $settings
            .dropFirst()
            .sink { newSettings in
                SampleData.saveSettings(newSettings)
            }
            .store(in: &cancellables)
    }

    func login(email: String, password: String) async throws {
        let profile = try await authService.login(email: email, password: password)
        currentUser = profile
        selectedTab = .chat
    }

    func register(name: String, email: String, password: String) async throws {
        let profile = try await authService.register(name: name, email: email, password: password)
        currentUser = profile
        selectedTab = .profile
    }

    func logout() {
        Task {
            try? await authService.logout()
        }
        currentUser = nil
        selectedTab = .chat
    }

    func updateCurrentUser(_ profile: UserProfile) {
        currentUser = profile
        Task {
            try? await authService.updateProfile(profile)
        }
    }

    func updateSettings(_ settings: AgentSettingsModel) {
        self.settings = settings
    }

}
