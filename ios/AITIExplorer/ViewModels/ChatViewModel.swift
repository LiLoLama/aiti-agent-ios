import Foundation
import Combine

final class ChatViewModel: ObservableObject {
    @Published private(set) var agents: [AgentProfile] = []
    @Published var selectedAgentID: UUID?
    @Published var searchQuery: String = ""
    @Published var searchResults: [ChatMessage] = []
    @Published var isSearching = false
    @Published var isShowingOverviewOnPhone = false
    @Published var pendingResponse = false

    private var appState: AppState?
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState? = nil) {
        self.appState = appState
        configureBindings()
    }

    func attach(appState: AppState) {
        self.appState = appState
        configureBindings()
        if selectedAgentID == nil, let agent = appState.currentUser?.agents.first {
            selectedAgentID = agent.id
        }
    }

    var selectedAgent: AgentProfile? {
        agents.first(where: { $0.id == selectedAgentID })
    }

    func select(agent: AgentProfile) {
        selectedAgentID = agent.id
        isShowingOverviewOnPhone = false
    }

    func sendMessage(_ text: String, attachments: [ChatAttachment]) {
        guard var agent = selectedAgent else {
            return
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else {
            return
        }

        let content = trimmed.isEmpty && !attachments.isEmpty ? "Audio-Nachricht" : trimmed
        let userMessage = ChatMessage(author: .user, content: content, attachments: attachments)
        agent.conversation.append(userMessage)
        update(agent)

        pendingResponse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            let reply = ChatMessage(
                author: .agent,
                content: "Danke für deine Nachricht! Ich kümmere mich darum und melde mich mit einem Vorschlag."
            )
            self.append(message: reply, to: agent)
            self.pendingResponse = false
        }
    }

    func deleteConversation(for agent: AgentProfile) {
        guard let index = agents.firstIndex(where: { $0.id == agent.id }) else { return }
        var updatedAgent = agent
        updatedAgent.conversation.messages.removeAll()
        updatedAgent.conversation.lastUpdated = Date()
        update(updatedAgent)
    }

    private func append(message: ChatMessage, to agent: AgentProfile) {
        var updatedAgent = agent
        updatedAgent.conversation.append(message)
        update(updatedAgent)
    }

    private func update(_ agent: AgentProfile) {
        guard let appState = appState, var user = appState.currentUser else { return }
        if let index = user.agents.firstIndex(where: { $0.id == agent.id }) {
            user.agents[index] = agent
            appState.updateCurrentUser(user)
        }
    }

    private func performSearch(query: String) {
        guard let agent = selectedAgent else {
            searchResults = []
            return
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true
        let lowercased = trimmed.lowercased()
        searchResults = agent.conversation.messages.filter { message in
            message.content.lowercased().contains(lowercased)
        }
        isSearching = false
    }
}

private extension ChatViewModel {
    func configureBindings() {
        cancellables.removeAll()

        appState?.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self else { return }
                self.agents = user?.agents ?? []
                if let first = self.agents.first, self.selectedAgentID == nil {
                    self.selectedAgentID = first.id
                }
            }
            .store(in: &cancellables)

        $searchQuery
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }
}
