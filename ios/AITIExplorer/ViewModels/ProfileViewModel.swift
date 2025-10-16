import Foundation
import Combine

final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile
    @Published var draftName: String
    @Published var draftBio: String
    @Published var isActive: Bool
    @Published var agents: [AgentProfile]
    @Published var toastMessage: String?

    private var appState: AppState?

    init(appState: AppState? = nil) {
        self.appState = appState
        let profile = appState?.currentUser ?? SampleData.previewUser
        self.profile = profile
        self.draftName = profile.name
        self.draftBio = profile.bio
        self.isActive = profile.isActive
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
            self.isActive = profile.isActive
            self.agents = profile.agents
        }
    }

    private var cancellables = Set<AnyCancellable>()

    func saveProfile() {
        profile.name = draftName
        profile.bio = draftBio
        profile.isActive = isActive
        profile.agents = agents
        appState?.updateCurrentUser(profile)
        toastMessage = "Profil gespeichert"
    }

    func toggleAgent(_ agent: AgentProfile) {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        var updated = agent
        updated.status = agent.status == .online ? .offline : .online
        agents[index] = updated
        saveProfile()
    }

    func addAgent(name: String, role: String) {
        guard !name.isEmpty else { return }
        let agentId = UUID()
        let conversation = Conversation(agentId: agentId, title: "Neuer Chat")
        let agent = AgentProfile(
            id: agentId,
            name: name,
            role: role.isEmpty ? "Individueller Agent" : role,
            description: "Neuer individueller Agent.",
            conversation: conversation
        )
        agents.append(agent)
        saveProfile()
    }

    func removeAgent(_ agent: AgentProfile) {
        agents.removeAll { $0.id == agent.id }
        saveProfile()
    }
}

private extension ProfileViewModel {
    func configureBindings() {
        cancellables.removeAll()

        appState?.$currentUser
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profile in
                self?.profile = profile
                self?.draftName = profile.name
                self?.draftBio = profile.bio
                self?.isActive = profile.isActive
                self?.agents = profile.agents
            }
            .store(in: &cancellables)
    }
}
