import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var email: String
    var bio: String
    var avatarSystemName: String
    var isActive: Bool
    var agents: [AgentProfile]

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        bio: String = "",
        avatarSystemName: String = "person.crop.circle.fill",
        isActive: Bool = true,
        agents: [AgentProfile] = []
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.bio = bio
        self.avatarSystemName = avatarSystemName
        self.isActive = isActive
        self.agents = agents
    }
}
