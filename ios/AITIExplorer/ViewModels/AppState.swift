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
    private let sessionStore: UserSessionStore
    private var cancellables = Set<AnyCancellable>()

    init(previewUser: UserProfile? = nil, authService: AuthServicing = MockAuthService(), sessionStore: UserSessionStore = UserSessionStore()) {
        self.authService = authService
        self.sessionStore = sessionStore
        let defaults = SampleData.defaultSettings
        self.settings = defaults
        self.currentUser = previewUser ?? sessionStore.load()

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
        sessionStore.save(profile)
        selectedTab = .chat
    }

    func register(name: String, email: String, password: String) async throws {
        let profile = try await authService.register(name: name, email: email, password: password)
        currentUser = profile
        sessionStore.save(profile)
        selectedTab = .profile
    }

    func logout() {
        Task {
            try? await authService.logout()
        }
        currentUser = nil
        sessionStore.clear()
        selectedTab = .chat
    }

    func updateCurrentUser(_ profile: UserProfile) {
        currentUser = profile
        Task {
            try? await authService.updateProfile(profile)
        }
        sessionStore.save(profile)
    }

    func updateSettings(_ settings: AgentSettingsModel) {
        self.settings = settings
    }

    func fetchAllUsers() async throws -> [UserProfile] {
        try await authService.fetchAllProfiles()
    }

    func updateUserStatus(userId: UUID, isActive: Bool) async throws {
        try await authService.updateUserStatus(userId: userId, isActive: isActive)

        if var profile = currentUser, profile.id == userId {
            profile.isActive = isActive
            currentUser = profile
        }
    }

}
