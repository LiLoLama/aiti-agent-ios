import Foundation

struct WebhookReply {
    let text: String
}

enum WebhookError: LocalizedError {
    case missingURL
    case invalidResponse
    case server(status: Int, body: String?)
    case transport(Error)
    case encoding(Error)

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "Für diesen Agenten ist kein Webhook konfiguriert."
        case .invalidResponse:
            return "Die Antwort des Webhooks war ungültig."
        case let .server(status, body):
            if let body, !body.isEmpty {
                return "Webhook antwortete mit Status \(status): \(body)"
            }
            return "Webhook antwortete mit Status \(status)."
        case let .transport(error):
            return "Der Webhook konnte nicht erreicht werden: \(error.localizedDescription)"
        case let .encoding(error):
            return "Die Nachricht konnte nicht vorbereitet werden: \(error.localizedDescription)"
        }
    }
}

final class WebhookClient {
    static let shared = WebhookClient()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func sendChatMessage(agent: AgentProfile, message: ChatMessage) async throws -> WebhookReply {
        guard agent.webhookURL != nil else {
            throw WebhookError.missingURL
        }

        let payload: ChatWebhookPayload
        do {
            payload = try await ChatWebhookPayload(agent: agent, message: message, conversation: agent.conversation.messages)
        } catch {
            throw WebhookError.encoding(error)
        }

        return try await performRequest(url: agent.webhookURL, payload: payload, defaultSuccessMessage: "Webhook hat keine Nachricht zurückgesendet.")
    }

    func testWebhook(for agent: AgentProfile) async throws -> WebhookReply {
        guard agent.webhookURL != nil else {
            throw WebhookError.missingURL
        }

        let payload = WebhookTestPayload(agent: agent)
        return try await performRequest(url: agent.webhookURL, payload: payload, defaultSuccessMessage: "Webhook antwortete erfolgreich, aber ohne Inhalt.")
    }
}

private extension WebhookClient {
    func performRequest<Payload: Encodable>(url: URL?, payload: Payload, defaultSuccessMessage: String) async throws -> WebhookReply {
        guard let url else {
            throw WebhookError.missingURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            throw WebhookError.encoding(error)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw WebhookError.invalidResponse
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let bodyText = String(data: data, encoding: .utf8)
                throw WebhookError.server(status: httpResponse.statusCode, body: bodyText)
            }

            guard !data.isEmpty else {
                return WebhookReply(text: defaultSuccessMessage)
            }

            if let replyPayload = try? decoder.decode(WebhookReplyPayload.self, from: data), let message = replyPayload.primaryMessage {
                return WebhookReply(text: message)
            }

            if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                return WebhookReply(text: text)
            }

            return WebhookReply(text: defaultSuccessMessage)
        } catch let error as WebhookError {
            throw error
        } catch {
            throw WebhookError.transport(error)
        }
    }
}

private struct WebhookReplyPayload: Decodable {
    let reply: String?
    let message: String?
    let content: String?
    let response: String?
    let text: String?

    var primaryMessage: String? {
        let candidates = [reply, message, content, response, text]
        for candidate in candidates {
            if let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }
}

private struct ChatWebhookPayload: Encodable {
    struct AgentPayload: Encodable {
        let id: UUID
        let name: String
        let role: String
        let description: String
    }

    struct MessagePayload: Encodable {
        let id: UUID
        let author: String
        let content: String
        let timestamp: Date
        let attachments: [AttachmentPayload]
    }

    struct AttachmentPayload: Encodable {
        let id: UUID
        let name: String
        let size: Int
        let type: String
        let kind: String
        let durationSeconds: Int?
        let data: String?
    }

    let agent: AgentPayload
    let message: MessagePayload
    let conversation: [MessagePayload]
    let sentAt: Date

    init(agent: AgentProfile, message: ChatMessage, conversation: [ChatMessage]) async throws {
        self.agent = AgentPayload(id: agent.id, name: agent.name, role: agent.role, description: agent.description)
        self.message = try await MessagePayload(message: message)
        self.conversation = try await conversation.asyncMap { try await MessagePayload(message: $0) }
        self.sentAt = Date()
    }
}

private extension ChatWebhookPayload.MessagePayload {
    init(message: ChatMessage) async throws {
        self.id = message.id
        self.author = message.author.rawValue
        self.content = message.content
        self.timestamp = message.timestamp
        self.attachments = try await message.attachments.asyncMap { try await ChatWebhookPayload.AttachmentPayload(attachment: $0) }
    }
}

private extension ChatWebhookPayload.AttachmentPayload {
    init(attachment: ChatAttachment) async throws {
        self.id = attachment.id
        self.name = attachment.name
        self.size = attachment.size
        self.type = attachment.type
        self.kind = attachment.kind.rawValue
        self.durationSeconds = attachment.durationSeconds

        if let url = attachment.url {
            self.data = try await Task.detached(priority: .userInitiated) {
                let data = try Data(contentsOf: url)
                return data.base64EncodedString()
            }.value
        } else {
            self.data = nil
        }
    }
}

private struct WebhookTestPayload: Encodable {
    struct AgentPayload: Encodable {
        let id: UUID
        let name: String
        let role: String
    }

    let agent: AgentPayload
    let event: String
    let sentAt: Date

    init(agent: AgentProfile) {
        self.agent = AgentPayload(id: agent.id, name: agent.name, role: agent.role)
        self.event = "webhook.test"
        self.sentAt = Date()
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)
        for element in self {
            let value = try await transform(element)
            values.append(value)
        }
        return values
    }
}
