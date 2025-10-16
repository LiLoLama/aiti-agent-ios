import Foundation
import Combine

final class AuthViewModel: ObservableObject {
    enum Mode: Hashable {
        case login
        case register
    }

    @Published var mode: Mode = .login
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private var appState: AppState?

    init(appState: AppState? = nil) {
        self.appState = appState
    }

    func attach(appState: AppState) {
        self.appState = appState
    }

    var primaryButtonTitle: String {
        mode == .login ? "Anmelden" : "Account erstellen"
    }

    var secondaryButtonTitle: String {
        mode == .login ? "Account anlegen" : "Ich habe bereits einen Account"
    }

    func toggleMode() {
        mode = mode == .login ? .register : .login
        errorMessage = nil
        infoMessage = nil
    }

    func submit() {
        isProcessing = true
        errorMessage = nil
        infoMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                switch self.mode {
                case .login:
                    guard let appState = self.appState else { throw AuthLifecycleError.missingAppState }
                    try appState.login(email: self.email, password: self.password)
                    DispatchQueue.main.async {
                        self.infoMessage = "Erfolgreich angemeldet. Willkommen zurück!"
                    }
                case .register:
                    guard self.password == self.confirmPassword else {
                        throw RegistrationError.passwordMismatch
                    }
                    guard let appState = self.appState else { throw AuthLifecycleError.missingAppState }
                    try appState.register(name: self.name, email: self.email, password: self.password)
                    DispatchQueue.main.async {
                        self.infoMessage = "Account erstellt! Du kannst dein Profil nun anpassen."
                    }
                }
            } catch let error as RegistrationError {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            } catch let error as AppState.AuthError {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Es ist ein unbekannter Fehler aufgetreten."
                }
            }

            DispatchQueue.main.async {
                self.isProcessing = false
            }
        }
    }

    enum RegistrationError: LocalizedError {
        case passwordMismatch

        var errorDescription: String? {
            switch self {
            case .passwordMismatch:
                return "Die Passwörter stimmen nicht überein."
            }
        }
    }

    enum AuthLifecycleError: LocalizedError {
        case missingAppState

        var errorDescription: String? {
            "Der Applikationsstatus konnte nicht initialisiert werden."
        }
    }
}
