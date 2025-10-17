import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var email: String
    var bio: String
    var avatarSystemName: String
    var avatarImageData: Data?
    var isActive: Bool
    var role: UserRole
    var agents: [AgentProfile]

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        bio: String = "",
        avatarSystemName: String = "person.crop.circle.fill",
        avatarImageData: Data? = nil,
        isActive: Bool = true,
        role: UserRole = .user,
        agents: [AgentProfile] = []
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.bio = bio
        self.avatarSystemName = avatarSystemName
        self.avatarImageData = avatarImageData
        self.isActive = isActive
        self.role = role
        self.agents = agents
    }
}
