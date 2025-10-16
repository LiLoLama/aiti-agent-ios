import Foundation

enum AgentStatus: String, Codable, CaseIterable, Identifiable {
    case online
    case offline
    case busy

    var id: String { rawValue }

    var description: String {
        switch self {
        case .online:
            return "Verfügbar"
        case .offline:
            return "Offline"
        case .busy:
            return "Beschäftigt"
        }
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
    var conversation: Conversation
    var webhookURL: URL?

    init(
        id: UUID = UUID(),
        name: String,
        role: String,
        description: String,
        status: AgentStatus = .online,
        avatarSystemName: String = "bolt.fill",
        conversation: Conversation,
        webhookURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.description = description
        self.status = status
        self.avatarSystemName = avatarSystemName
        self.conversation = conversation
        self.webhookURL = webhookURL
    }
}
