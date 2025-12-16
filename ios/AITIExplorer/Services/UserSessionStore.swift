import Foundation

struct UserSessionStore {
    private enum Keys {
        static let currentUser = "aiti.currentUser"
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func load() -> UserProfile? {
        guard let data = defaults.data(forKey: Keys.currentUser) else {
            return nil
        }

        return try? decoder.decode(UserProfile.self, from: data)
    }

    func save(_ profile: UserProfile) {
        guard let data = try? encoder.encode(profile) else {
            return
        }

        defaults.set(data, forKey: Keys.currentUser)
    }

    func clear() {
        defaults.removeObject(forKey: Keys.currentUser)
    }
}
