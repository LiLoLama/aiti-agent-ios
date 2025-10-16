import Foundation
import Combine

final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile
    @Published var draftName: String
    @Published var draftBio: String
    @Published var agents: [AgentProfile]
    @Published var toastMessage: String?

    private var appState: AppState?

    init(appState: AppState? = nil) {
        self.appState = appState
        let profile = appState?.currentUser ?? SampleData.previewUser
        self.profile = profile
        self.draftName = profile.name
        self.draftBio = profile.bio
        self.agents = profile.agents

        configureBindings()
    }

    func attach(appState: AppState) {
        self.appState = appState
        configureBindings()
        if let profile = appState.currentUser {
            self.profile = profile
            self.draftName = profile.name
            self.draftBio = profile.bio
            self.agents = profile.agents
        }
    }

    private var cancellables = Set<AnyCancellable>()

    func saveProfile() {
        profile.name = draftName
        profile.bio = draftBio
        profile.agents = agents
        persistProfileChanges()
        toastMessage = "Profil gespeichert"
    }

    func addAgent(name: String, role: String, webhookURLString: String) {
        guard !name.isEmpty else { return }
        let agentId = UUID()
        let conversation = Conversation(agentId: agentId, title: "Neuer Chat")
        let trimmedWebhook = webhookURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let webhookURL = trimmedWebhook.isEmpty ? nil : URL(string: trimmedWebhook)
        let agent = AgentProfile(
            id: agentId,
            name: name,
            role: role.isEmpty ? "Individueller Agent" : role,
            description: "Neuer individueller Agent.",
            conversation: conversation,
            webhookURL: webhookURL
        )
        agents.append(agent)
        saveAgentChanges(showToast: true)
    }

    func removeAgent(_ agent: AgentProfile) {
        agents.removeAll { $0.id == agent.id }
        saveAgentChanges(showToast: true)
    }

    func saveAgentChanges(showToast: Bool = false) {
        persistAgents(showToast: showToast)
    }
}

private extension ProfileViewModel {
    func persistProfileChanges() {
        appState?.updateCurrentUser(profile)
    }

    func persistAgents(showToast: Bool = false) {
        profile.agents = agents
        persistProfileChanges()
        if showToast {
            toastMessage = "Agents aktualisiert"
        }
    }

    func configureBindings() {
        cancellables.removeAll()

        appState?.$currentUser
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.profile = profile
                self?.draftName = profile.name
                self?.draftBio = profile.bio
                self?.agents = profile.agents
            }
            .store(in: &cancellables)
    }
}

extension ProfileViewModel {
    var statusLabel: String {
        profile.isActive ? "Aktiv" : "Inaktiv"
    }

    var statusDescription: String {
        profile.isActive ? "Dein Account ist aktiv und einsatzbereit." : "Dein Account ist aktuell inaktiv."
    }

    var agentCountText: String {
        let count = agents.count
        if count == 0 {
            return "Noch keine Agenten erstellt"
        }
        if count == 1 {
            return "1 Agent erstellt"
        }
        return "\(count) Agenten erstellt"
    }
}
