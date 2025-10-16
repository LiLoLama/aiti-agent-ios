import Foundation

final class SettingsViewModel: ObservableObject {
    @Published var settings: AgentSettingsModel
    @Published var saveStatus: SaveStatus = .idle
    @Published var webhookTestStatus: SaveStatus = .idle
    @Published var webhookMessage: String?

    enum SaveStatus {
        case idle
        case success
        case failure
        case inProgress
    }

    private var appState: AppState?

    init(appState: AppState? = nil) {
        self.appState = appState
        self.settings = appState?.settings ?? SampleData.defaultSettings
    }

    func attach(appState: AppState) {
        self.appState = appState
        self.settings = appState.settings
    }

    func save() {
        saveStatus = .inProgress
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            self.appState?.updateSettings(self.settings)
            self.saveStatus = .success
        }
    }

    func reset() {
        if let appState {
            settings = appState.settings
        }
        saveStatus = .idle
    }

    func testWebhook() {
        guard settings.webhookURL != nil else {
            webhookMessage = "Bitte hinterlege zuerst eine gültige URL."
            webhookTestStatus = .failure
            return
        }

        webhookTestStatus = .inProgress
        webhookMessage = "Webhook Test wird gesendet …"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.webhookMessage = "Webhook erfolgreich simuliert!"
            self?.webhookTestStatus = .success
        }
    }
}
