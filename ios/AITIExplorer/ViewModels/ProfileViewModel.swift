import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile
    @Published var draftName: String
    @Published var draftBio: String
    @Published var agents: [AgentProfile]
    @Published var toastMessage: String?
    @Published var avatarImageData: Data?

    private var appState: AppState?
    private var toastDismissWorkItem: DispatchWorkItem?

    init(appState: AppState? = nil) {
        self.appState = appState
        let profile = appState?.currentUser ?? SampleData.baseUserProfile
        self.profile = profile
        self.draftName = profile.name
        self.draftBio = profile.bio
        self.agents = profile.agents
        self.avatarImageData = profile.avatarImageData

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
            self.avatarImageData = profile.avatarImageData
        }
    }

    private var cancellables = Set<AnyCancellable>()

    func saveProfile() {
        profile.name = draftName
        profile.bio = draftBio
        profile.agents = agents
        profile.avatarImageData = avatarImageData
        persistProfileChanges()
        showToast(message: "Profil gespeichert")
    }

    func addAgent(name: String, role: String, webhookURLString: String, tools: [AgentTool]) {
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
            webhookURL: webhookURL,
            tools: tools
        )
        agents.append(agent)
        saveAgentChanges(showToast: true)
    }

    func removeAgent(_ agent: AgentProfile) {
        agents.removeAll { $0.id == agent.id }
        saveAgentChanges(showToast: true)
    }

    func saveAgentChanges(showToast: Bool = false) {
        persistAgents(shouldShowToast: showToast)
    }
}

private extension ProfileViewModel {
    func persistProfileChanges() {
        appState?.updateCurrentUser(profile)
    }

    func persistAgents(shouldShowToast: Bool = false) {
        profile.agents = agents
        persistProfileChanges()
        if shouldShowToast {
            showToast(message: "Agents aktualisiert")
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
                self?.avatarImageData = profile.avatarImageData
            }
            .store(in: &cancellables)
    }
}

extension ProfileViewModel {
    var statusLabel: String {
        profile.isActive ? "Aktiv" : "Inaktiv"
    }

    var canManageUsers: Bool {
        profile.role.isAdmin
    }

    func updateAvatar(with data: Data?) {
        avatarImageData = data
        profile.avatarImageData = data
    }
}

private extension ProfileViewModel {
    func showToast(message: String) {
        toastDismissWorkItem?.cancel()
        toastMessage = message

        let workItem = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                if self?.toastMessage == message {
                    self?.toastMessage = nil
                }
                self?.toastDismissWorkItem = nil
            }
        }
        toastDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }
}
