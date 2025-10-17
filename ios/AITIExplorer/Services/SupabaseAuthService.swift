import Foundation
import Supabase

final class SupabaseAuthService: AuthServicing {
    private let client: SupabaseClient
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    init(configuration: SupabaseConfiguration) {
        self.client = SupabaseClient(supabaseURL: configuration.url, supabaseKey: configuration.anonKey)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.jsonEncoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.jsonDecoder = decoder
    }

    func login(email: String, password: String) async throws -> UserProfile {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            let userId = try resolveUserID(from: session)
            return try await fetchProfile(for: userId, emailFallback: email)
        } catch {
            throw map(error)
        }
    }

    func register(name: String, email: String, password: String) async throws -> UserProfile {
        do {
            let metadata: [String: AnyJSON] = ["name": .string(name)]
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: metadata
            )
            let userId = try resolveUserID(from: response)

            let profile = UserProfile(id: userId, name: name, email: email)
            try await upsertProfile(profile)

            return try await fetchProfile(for: userId, emailFallback: email)
        } catch {
            throw map(error)
        }
    }

    func logout() async throws {
        do {
            try await client.auth.signOut()
        } catch {
            throw map(error)
        }
    }

    func updateProfile(_ profile: UserProfile) async throws {
        do {
            try await upsertProfile(profile)
        } catch {
            throw map(error)
        }
    }
}

private extension SupabaseAuthService {
    struct ProfileRow: Decodable {
        let id: UUID
        let email: String?
        let displayName: String?
        let avatarUrl: String?
        let agents: String?
        let bio: String?
        let isActive: Bool?
        let name: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case email
            case displayName = "display_name"
            case avatarUrl = "avatar_url"
            case agents
            case bio
            case isActive = "is_active"
            case name
        }
    }

    struct ProfileInput: Encodable {
        let id: UUID
        let email: String?
        let displayName: String?
        let avatarUrl: String?
        let bio: String?
        let agents: String?
        let isActive: Bool?
        let name: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case email
            case displayName = "display_name"
            case avatarUrl = "avatar_url"
            case bio
            case agents
            case isActive = "is_active"
            case name
        }
    }

    func resolveUserID(from response: AuthResponse) throws -> UUID {
        if let sessionUser = response.session?.user {
            return sessionUser.id
        }
        if let currentSessionUser = client.auth.currentSession?.user {
            return currentSessionUser.id
        }
        if let currentUser = client.auth.currentUser {
            return currentUser.id
        }
        return response.user.id
    }

    func resolveUserID(from session: Session) throws -> UUID {
        return session.user.id
    }

    func fetchProfile(for userId: UUID, emailFallback: String) async throws -> UserProfile {
        do {
            let rows: [ProfileRow] = try await client.database
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value

            if let row = rows.first {
                return map(row: row, emailFallback: emailFallback)
            }

            let profile = UserProfile(id: userId, name: emailFallback, email: emailFallback)
            try await upsertProfile(profile)
            return profile
        } catch {
            throw map(error)
        }
    }

    func upsertProfile(_ profile: UserProfile) async throws {
        let agentsString: String?
        if profile.agents.isEmpty {
            agentsString = nil
        } else if let data = try? jsonEncoder.encode(profile.agents), let jsonString = String(data: data, encoding: .utf8) {
            agentsString = jsonString
        } else {
            agentsString = nil
        }

        let input = ProfileInput(
            id: profile.id,
            email: profile.email,
            displayName: profile.name,
            avatarUrl: nil,
            bio: profile.bio.isEmpty ? nil : profile.bio,
            agents: agentsString,
            isActive: profile.isActive,
            name: profile.name
        )

        _ = try await client.database
            .from("profiles")
            .upsert(input, onConflict: "id", returning: .minimal)
            .execute()
    }

    func map(row: ProfileRow, emailFallback: String) -> UserProfile {
        var agents: [AgentProfile] = []
        if let agentsString = row.agents, let data = agentsString.data(using: .utf8) {
            agents = (try? jsonDecoder.decode([AgentProfile].self, from: data)) ?? []
        }

        let name = row.name?.isEmpty == false ? row.name! : (row.displayName?.isEmpty == false ? row.displayName! : emailFallback)
        let email = row.email ?? emailFallback
        let bio = row.bio ?? ""
        let isActive = row.isActive ?? true

        return UserProfile(
            id: row.id,
            name: name,
            email: email,
            bio: bio,
            avatarSystemName: "person.crop.circle.fill",
            avatarImageData: nil,
            isActive: isActive,
            agents: agents
        )
    }

    func map(_ error: Error) -> AuthServiceError {
        let message = error.localizedDescription
        let lowercased = message.lowercased()

        if lowercased.contains("invalid login") || lowercased.contains("invalid credentials") {
            return .invalidCredentials
        }

        if lowercased.contains("user already registered") || lowercased.contains("duplicate key value") {
            return .emailAlreadyRegistered
        }

        if lowercased.contains("not found") || lowercased.contains("no user") {
            return .accountNotFound
        }

        return .unknown(message: message)
    }
}
