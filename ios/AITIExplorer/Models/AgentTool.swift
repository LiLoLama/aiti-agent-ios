import Foundation

struct AgentTool: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

extension AgentTool {
    init(from decoder: Decoder) throws {
        let container = try? decoder.singleValueContainer()
        if let rawValue = try? container?.decode(String.self) {
            self.init(name: rawValue)
            return
        }

        let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
        let id = try keyedContainer.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let name = try keyedContainer.decode(String.self, forKey: .name)
        self.init(id: id, name: name)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }
}

extension Array where Element == AgentTool {
    func namesJoined() -> String {
        map { $0.name }.joined(separator: " • ")
    }
}
