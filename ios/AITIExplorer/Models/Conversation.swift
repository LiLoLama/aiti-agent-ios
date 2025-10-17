import Foundation

enum AgentStatus: String, Codable, Identifiable {
    case online

    var id: String { rawValue }

    var description: String {
        "Verfügbar"
    }
}

struct Conversation: Identifiable, Codable, Hashable {
    let id: UUID
    var agentId: UUID
    var title: String
    var lastUpdated: Date
    var messages: [ChatMessage]

    init(
        id: UUID = UUID(),
        agentId: UUID,
        title: String,
        lastUpdated: Date = Date(),
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.agentId = agentId
        self.title = title
        self.lastUpdated = lastUpdated
        self.messages = messages
    }

    var preview: String {
        messages.last?.content ?? "Beschreibe dein nächstes Projekt und starte den AI Agent."
    }

    mutating func append(_ message: ChatMessage) {
        messages.append(message)
        lastUpdated = message.timestamp
    }
}

struct AgentProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var role: String
    var description: String
    var status: AgentStatus
    var avatarSystemName: String
    var avatarImageData: Data?
    var conversation: Conversation
    var webhookURL: URL?
    var tools: [AgentTool]

    init(
        id: UUID = UUID(),
        name: String,
        role: String,
        description: String,
        status: AgentStatus = .online,
        avatarSystemName: String = "bolt.fill",
        avatarImageData: Data? = nil,
        conversation: Conversation,
        webhookURL: URL? = nil,
        tools: [AgentTool] = []
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.description = description
        self.status = status
        self.avatarSystemName = avatarSystemName
        self.avatarImageData = avatarImageData
        self.conversation = conversation
        self.webhookURL = webhookURL
        self.tools = tools
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case role
        case description
        case status
        case avatarSystemName
        case avatarImageData
        case conversation
        case webhookURL
        case tools
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(String.self, forKey: .role)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decode(AgentStatus.self, forKey: .status)
        avatarSystemName = try container.decode(String.self, forKey: .avatarSystemName)
        avatarImageData = try container.decodeIfPresent(Data.self, forKey: .avatarImageData)
        conversation = try container.decode(Conversation.self, forKey: .conversation)
        webhookURL = try container.decodeIfPresent(URL.self, forKey: .webhookURL)
        tools = try container.decodeIfPresent([AgentTool].self, forKey: .tools) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(description, forKey: .description)
        try container.encode(status, forKey: .status)
        try container.encode(avatarSystemName, forKey: .avatarSystemName)
        try container.encodeIfPresent(avatarImageData, forKey: .avatarImageData)
        try container.encode(conversation, forKey: .conversation)
        try container.encodeIfPresent(webhookURL, forKey: .webhookURL)
        try container.encode(tools, forKey: .tools)
    }
}
