import Foundation

struct SupabaseConfiguration {
    let url: URL
    let anonKey: String
}

enum SupabaseConfigurationLoader {
    enum ConfigurationError: LocalizedError {
        case missingFile
        case invalidFormat
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .missingFile:
                return "SupabaseConfig.plist konnte im App-Bundle nicht gefunden werden."
            case .invalidFormat:
                return "SupabaseConfig.plist enthält keine gültigen Schlüssel."
            case .invalidURL:
                return "Die Supabase-URL in SupabaseConfig.plist ist ungültig."
            }
        }
    }

    static func load() throws -> SupabaseConfiguration {
        guard let fileURL = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist") else {
            throw ConfigurationError.missingFile
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = PropertyListDecoder()
        let raw = try decoder.decode(RawConfiguration.self, from: data)

        guard let url = URL(string: raw.supabaseUrl), !raw.supabaseAnonKey.isEmpty else {
            if URL(string: raw.supabaseUrl) == nil {
                throw ConfigurationError.invalidURL
            }
            throw ConfigurationError.invalidFormat
        }

        return SupabaseConfiguration(url: url, anonKey: raw.supabaseAnonKey)
    }
}

private struct RawConfiguration: Decodable {
    let supabaseUrl: String
    let supabaseAnonKey: String
}
