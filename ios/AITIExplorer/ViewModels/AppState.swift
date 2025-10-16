import Foundation
import Combine
import SwiftUI

final class AppState: ObservableObject {
    enum Tab: Hashable {
        case chat
        case settings
        case profile
    }

    @Published var currentUser: UserProfile?
    @Published var settings: AgentSettingsModel
    @Published var selectedTab: Tab = .chat

    private(set) var registeredUsers: [UserCredentials]

    private var cancellables = Set<AnyCancellable>()

    init(previewUser: UserProfile? = nil) {
        let defaults = SampleData.defaultSettings
        self.settings = defaults
        self.registeredUsers = [SampleData.demoCredentials]
        self.currentUser = previewUser

        $settings
            .dropFirst()
            .sink { newSettings in
                SampleData.saveSettings(newSettings)
            }
            .store(in: &cancellables)
    }

    func login(email: String, password: String) throws {
        guard let credentials = registeredUsers.first(where: { $0.email.lowercased() == email.lowercased() }) else {
            throw AuthError.accountNotFound
        }

        guard credentials.password == password else {
            throw AuthError.invalidPassword
        }

        currentUser = credentials.profile
        selectedTab = .chat
    }

    func register(name: String, email: String, password: String) throws {
        guard !registeredUsers.contains(where: { $0.email.lowercased() == email.lowercased() }) else {
            throw AuthError.emailAlreadyRegistered
        }

        var newProfile = SampleData.previewUser
        newProfile.id = UUID()
        newProfile.name = name
        newProfile.email = email

        let credentials = UserCredentials(email: email, password: password, profile: newProfile)
        registeredUsers.append(credentials)
        currentUser = newProfile
        selectedTab = .profile
    }

    func logout() {
        currentUser = nil
        selectedTab = .chat
    }

    func updateCurrentUser(_ profile: UserProfile) {
        currentUser = profile
        if let index = registeredUsers.firstIndex(where: { $0.email.lowercased() == profile.email.lowercased() }) {
            registeredUsers[index].profile = profile
        }
    }

    func updateSettings(_ settings: AgentSettingsModel) {
        self.settings = settings
    }

    enum AuthError: LocalizedError {
        case accountNotFound
        case invalidPassword
        case emailAlreadyRegistered

        var errorDescription: String? {
            switch self {
            case .accountNotFound:
                return "Für diese E-Mail existiert noch kein Account."
            case .invalidPassword:
                return "Das Passwort ist nicht korrekt."
            case .emailAlreadyRegistered:
                return "Diese E-Mail ist bereits registriert."
            }
        }
    }
}

struct UserCredentials: Identifiable, Hashable {
    var id = UUID()
    let email: String
    var password: String
    var profile: UserProfile
}
