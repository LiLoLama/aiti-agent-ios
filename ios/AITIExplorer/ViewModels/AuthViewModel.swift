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
    }

    func submit() {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil

        Task { [weak self] in
            guard let self else { return }

            do {
                switch self.mode {
                case .login:
                    guard let appState = self.appState else { throw AuthLifecycleError.missingAppState }
                    try await appState.login(email: self.email, password: self.password)
                case .register:
                    guard self.password == self.confirmPassword else {
                        throw RegistrationError.passwordMismatch
                    }
                    guard let appState = self.appState else { throw AuthLifecycleError.missingAppState }
                    try await appState.register(name: self.name, email: self.email, password: self.password)
                }
            } catch let error as RegistrationError {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            } catch let error as AuthServiceError {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            } catch let error as AuthLifecycleError {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Es ist ein unbekannter Fehler aufgetreten."
                }
            }

            await MainActor.run {
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
