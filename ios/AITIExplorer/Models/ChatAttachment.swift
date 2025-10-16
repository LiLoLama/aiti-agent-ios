import Foundation

enum AttachmentKind: String, Codable, CaseIterable, Identifiable {
    case file
    case audio

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .file:
            return "doc.fill"
        case .audio:
            return "waveform.circle.fill"
        }
    }
}

struct ChatAttachment: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var size: Int
    var type: String
    var url: URL?
    var kind: AttachmentKind
    var durationSeconds: Int?

    init(
        id: UUID = UUID(),
        name: String,
        size: Int,
        type: String,
        url: URL? = nil,
        kind: AttachmentKind,
        durationSeconds: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.type = type
        self.url = url
        self.kind = kind
        self.durationSeconds = durationSeconds
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}
