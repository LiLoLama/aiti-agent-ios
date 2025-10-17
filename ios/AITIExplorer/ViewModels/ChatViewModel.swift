import Foundation
import Combine

@MainActor
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

        guard agent.webhookURL != nil else {
            let infoMessage = ChatMessage(
                author: .agent,
                content: "Für diesen Agenten ist kein Webhook hinterlegt. Bitte füge eine gültige URL hinzu, um Antworten zu erhalten."
            )
            append(message: infoMessage, to: agent)
            pendingResponse = false
            return
        }

        let targetAgent = agent
        Task { [weak self] in
            guard let self else { return }
            do {
                let reply = try await WebhookClient.shared.sendChatMessage(agent: targetAgent, message: userMessage)
                await MainActor.run {
                    let responseMessage = ChatMessage(author: .agent, content: reply.text)
                    self.append(message: responseMessage, to: targetAgent)
                    self.pendingResponse = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(
                        author: .agent,
                        content: "Der Webhook konnte nicht aufgerufen werden: \(error.localizedDescription)"
                    )
                    self.append(message: errorMessage, to: targetAgent)
                    self.pendingResponse = false
                }
            }
        }
    }

    func deleteConversation(for agent: AgentProfile) {
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
