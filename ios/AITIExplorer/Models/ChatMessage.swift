import Foundation

enum MessageAuthor: String, Codable, CaseIterable, Identifiable {
    case agent
    case user

    var id: String { rawValue }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var author: MessageAuthor
    var content: String
    var timestamp: Date
    var attachments: [ChatAttachment]

    init(
        id: UUID = UUID(),
        author: MessageAuthor,
        content: String,
        timestamp: Date = Date(),
        attachments: [ChatAttachment] = []
    ) {
        self.id = id
        self.author = author
        self.content = content
        self.timestamp = timestamp
        self.attachments = attachments
    }
}

extension ChatMessage {
    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
