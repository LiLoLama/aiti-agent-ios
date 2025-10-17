import Foundation

final class MockAuthService: AuthServicing {
    private var registeredUsers: [MockCredentials]

    init(registeredUsers: [MockCredentials]? = nil) {
        if let registeredUsers {
            self.registeredUsers = registeredUsers
        } else {
            let baseProfile = SampleData.baseUserProfile
            let credentials = MockCredentials(email: baseProfile.email, password: "SwiftRocks!", profile: baseProfile)
            self.registeredUsers = [credentials]
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
}

struct MockCredentials: Identifiable, Hashable {
    var id = UUID()
    let email: String
    var password: String
    var profile: UserProfile
}
