import Foundation

enum UserRole: String, Codable, Hashable {
    case admin
    case member
    case user
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = (try? container.decode(String.self))?.lowercased() ?? ""
        self = UserRole(rawValue: value) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .unknown:
            try container.encodeNil()
        default:
            try container.encode(rawValue)
        }
    }

    init(from string: String?) {
        let normalized = string?.lowercased() ?? ""
        self = UserRole(rawValue: normalized) ?? .unknown
    }

    var isAdmin: Bool {
        self == .admin
    }
}
