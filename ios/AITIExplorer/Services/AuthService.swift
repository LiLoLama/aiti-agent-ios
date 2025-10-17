import Foundation

protocol AuthServicing {
    func login(email: String, password: String) async throws -> UserProfile
    func register(name: String, email: String, password: String) async throws -> UserProfile
    func logout() async throws
    func updateProfile(_ profile: UserProfile) async throws
}

enum AuthServiceError: LocalizedError {
    case accountNotFound
    case invalidCredentials
    case emailAlreadyRegistered
    case configurationMissing(String)
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .accountNotFound:
            return "Für diese E-Mail existiert noch kein Account."
        case .invalidCredentials:
            return "Die Kombination aus E-Mail und Passwort ist nicht korrekt."
        case .emailAlreadyRegistered:
            return "Diese E-Mail-Adresse ist bereits registriert."
        case .configurationMissing(let message):
            return "Die Supabase-Konfiguration ist unvollständig: \(message)"
        case .unknown(let message):
            return message
        }
    }
}
