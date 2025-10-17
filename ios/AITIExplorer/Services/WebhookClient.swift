import Foundation
import UniformTypeIdentifiers

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

        return try await performRequest(
            url: agent.webhookURL,
            payload: payload,
            defaultSuccessMessage: "Webhook hat keine Nachricht zurückgesendet.",
            binaryAttachments: payload.binaryAttachments
        )
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
    func performRequest<Payload: Encodable>(
        url: URL?,
        payload: Payload,
        defaultSuccessMessage: String,
        binaryAttachments: [WebhookBinaryAttachment] = []
    ) async throws -> WebhookReply {
        guard let url else {
            throw WebhookError.missingURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let bodyData: Data
        if binaryAttachments.isEmpty {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                bodyData = try encoder.encode(payload)
            } catch {
                throw WebhookError.encoding(error)
            }
        } else {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            let jsonData: Data
            do {
                jsonData = try encoder.encode(payload)
            } catch {
                throw WebhookError.encoding(error)
            }

            var multipartBody = Data()
            multipartBody.append("--\(boundary)\r\n")
            multipartBody.append("Content-Disposition: form-data; name=\"payload\"\r\n")
            multipartBody.append("Content-Type: application/json; charset=utf-8\r\n\r\n")
            multipartBody.append(jsonData)
            multipartBody.append("\r\n")

            for attachment in binaryAttachments {
                multipartBody.append("--\(boundary)\r\n")
                multipartBody.append("Content-Disposition: form-data; name=\"\(attachment.fieldName)\"; filename=\"\(attachment.filename)\"\r\n")
                multipartBody.append("Content-Type: \(attachment.mimeType)\r\n\r\n")
                multipartBody.append(attachment.data)
                multipartBody.append("\r\n")
            }

            multipartBody.append("--\(boundary)--\r\n")
            bodyData = multipartBody
        }

        request.httpBody = bodyData

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
        let attachments: [ChatWebhookPayload.AttachmentPayload]
        let binaryAttachments: [WebhookBinaryAttachment]

        private enum CodingKeys: String, CodingKey {
            case id
            case author
            case content
            case timestamp
            case attachments
        }
    }

    struct AttachmentPayload: Encodable {
        let id: UUID
        let name: String
        let size: Int
        let type: String
        let kind: String
        let durationSeconds: Int?
        let data: String?
        let binaryFieldName: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case size
            case type
            case kind
            case durationSeconds
            case data
            case binaryFieldName
        }
    }

    let agent: AgentPayload
    let message: MessagePayload
    let conversation: [MessagePayload]
    let sentAt: Date
    let binaryAttachments: [WebhookBinaryAttachment]

    init(agent: AgentProfile, message: ChatMessage, conversation: [ChatMessage]) async throws {
        self.agent = AgentPayload(id: agent.id, name: agent.name, role: agent.role, description: agent.description)
        let currentMessage = try await MessagePayload(message: message, collectBinary: true)
        self.message = currentMessage
        if let latestMessage = conversation.last {
            self.conversation = [try await MessagePayload(message: latestMessage, collectBinary: false)]
        } else {
            self.conversation = [try await MessagePayload(message: message, collectBinary: false)]
        }
        self.sentAt = Date()
        self.binaryAttachments = currentMessage.binaryAttachments
    }

    private enum CodingKeys: String, CodingKey {
        case agent
        case message
        case conversation
        case sentAt
    }
}

private extension ChatWebhookPayload.MessagePayload {
    init(message: ChatMessage, collectBinary: Bool) async throws {
        self.id = message.id
        self.author = message.author.rawValue
        self.content = message.content
        self.timestamp = message.timestamp

        var builtAttachments: [ChatWebhookPayload.AttachmentPayload] = []
        var binaries: [WebhookBinaryAttachment] = []
        for (index, attachment) in message.attachments.enumerated() {
            let payload = try await ChatWebhookPayload.AttachmentPayload(
                attachment: attachment,
                includeBinary: collectBinary,
                index: index,
                binaryCollector: &binaries
            )
            builtAttachments.append(payload)
        }

        self.attachments = builtAttachments
        self.binaryAttachments = binaries
    }
}

private extension ChatWebhookPayload.AttachmentPayload {
    init(attachment: ChatAttachment, includeBinary: Bool, index: Int, binaryCollector: inout [WebhookBinaryAttachment]) async throws {
        self.id = attachment.id
        self.name = attachment.name
        self.size = attachment.size
        self.type = attachment.type
        self.kind = attachment.kind.rawValue
        self.durationSeconds = attachment.durationSeconds

        if let url = attachment.url {
            let rawData = try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url)
            }.value
            self.data = rawData.base64EncodedString()

            if includeBinary {
                let fieldName = "file\(index)"
                let resolvedType = UTType(mimeType: attachment.type)
                    ?? UTType(attachment.type)
                    ?? UTType(filenameExtension: URL(fileURLWithPath: attachment.name).pathExtension)
                let mimeType = resolvedType?.preferredMIMEType
                    ?? (attachment.type.contains("/") ? attachment.type : "application/octet-stream")

                let binary = WebhookBinaryAttachment(
                    fieldName: fieldName,
                    filename: attachment.name,
                    mimeType: mimeType,
                    data: rawData
                )
                binaryCollector.append(binary)
                self.binaryFieldName = fieldName
            } else {
                self.binaryFieldName = nil
            }
        } else {
            self.data = nil
            self.binaryFieldName = nil
        }
    }
}

private struct WebhookBinaryAttachment {
    let fieldName: String
    let filename: String
    let mimeType: String
    let data: Data
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
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

