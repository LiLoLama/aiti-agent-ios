import Foundation

final class MockAuthService: AuthServicing {
    private var registeredUsers: [MockCredentials]

    init(registeredUsers: [MockCredentials]? = nil) {
        if let registeredUsers {
            self.registeredUsers = registeredUsers
        } else {
            self.registeredUsers = []
        }
    }

    func login(email: String, password: String) async throws -> UserProfile {
        guard let credentials = registeredUsers.first(where: { $0.email.lowercased() == email.lowercased() }) else {
            throw AuthServiceError.accountNotFound
        }

        guard credentials.password == password else {
            throw AuthServiceError.invalidCredentials
        }

        return credentials.profile
    }

    func register(name: String, email: String, password: String) async throws -> UserProfile {
        guard !registeredUsers.contains(where: { $0.email.lowercased() == email.lowercased() }) else {
            throw AuthServiceError.emailAlreadyRegistered
        }

        var profile = SampleData.baseUserProfile
        profile.id = UUID()
        profile.name = name
        profile.email = email

        let credentials = MockCredentials(email: email, password: password, profile: profile)
        registeredUsers.append(credentials)
        return profile
    }

    func logout() async throws {}

    func updateProfile(_ profile: UserProfile) async throws {
        if let index = registeredUsers.firstIndex(where: { $0.email.lowercased() == profile.email.lowercased() }) {
            registeredUsers[index].profile = profile
        }
    }

    func fetchAllProfiles() async throws -> [UserProfile] {
        registeredUsers.map { $0.profile }
    }

    func updateUserStatus(userId: UUID, isActive: Bool) async throws {
        guard let index = registeredUsers.firstIndex(where: { $0.profile.id == userId }) else { return }
        registeredUsers[index].profile.isActive = isActive
    }
}

struct MockCredentials: Identifiable, Hashable {
    var id = UUID()
    let email: String
    var password: String
    var profile: UserProfile
}
