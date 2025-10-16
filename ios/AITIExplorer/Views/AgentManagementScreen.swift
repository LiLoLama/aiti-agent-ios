import SwiftUI

private enum AgentField: Hashable {
    case newName
    case newRole
    case newWebhook
    case agentName(UUID)
    case agentRole(UUID)
    case agentWebhook(UUID)
}

struct AgentManagementScreen: View {
    @ObservedObject var viewModel: ProfileViewModel

    @State private var newAgentName: String = ""
    @State private var newAgentRole: String = ""
    @State private var newAgentWebhook: String = ""
    @State private var webhookStatus: [UUID: WebhookTestState] = [:]
    @FocusState private var focusedField: AgentField?

    var body: some View {
        Form {
            agentsSection
            addAgentSection
        }
        .navigationTitle("Agents verwalten")
        .toolbar { toolbarContent }
        .scrollDismissesKeyboard(.interactively)
        .dismissFocusOnInteract($focusedField)
        .onDisappear {
            viewModel.saveAgentChanges()
        }
    }

    private var agentsSection: some View {
        Section(header: Text("Deine Agents"), footer: Text("Lege für jeden Agent individuelle Webhooks fest.")) {
            if viewModel.agents.isEmpty {
                Text("Noch keine Agents angelegt. Erstelle unten deinen ersten Agenten.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.agents.indices, id: \.self) { index in
                    let agentBinding = $viewModel.agents[index]
                    let agent = viewModel.agents[index]

                    AgentEditorCard(
                        agent: agentBinding,
                        focusedField: $focusedField,
                        status: webhookStatus[agent.id],
                        onTestWebhook: { testWebhook(for: agent) },
                        onRemove: {
                            focusedField = nil
                            webhookStatus[agent.id] = nil
                            viewModel.removeAgent(agent)
                        }
                    )
                }
            }
        }
    }

    private var addAgentSection: some View {
        Section(header: Text("Neuen Agent hinzufügen")) {
            TextField("Name", text: $newAgentName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .newName)
            TextField("Rolle", text: $newAgentRole)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .newRole)
            TextField("Webhook URL (optional)", text: $newAgentWebhook)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .newWebhook)

            Button("Agent erstellen") {
                viewModel.addAgent(
                    name: newAgentName.trimmingCharacters(in: .whitespacesAndNewlines),
                    role: newAgentRole.trimmingCharacters(in: .whitespacesAndNewlines),
                    webhookURLString: newAgentWebhook
                )
                newAgentName = ""
                newAgentRole = ""
                newAgentWebhook = ""
                focusedField = nil
            }
            .disabled(newAgentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Speichern") {
                viewModel.saveAgentChanges(showToast: true)
            }
        }
    }

    private func testWebhook(for agent: AgentProfile) {
        let id = agent.id
        guard let url = agent.webhookURL, !url.absoluteString.isEmpty else {
            webhookStatus[id] = WebhookTestState(message: "Bitte gib eine gültige URL ein.", isError: true, isLoading: false)
            return
        }

        webhookStatus[id] = WebhookTestState(message: "Webhook Test wird gesendet …", isError: false, isLoading: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            webhookStatus[id] = WebhookTestState(message: "Webhook erfolgreich simuliert!", isError: false, isLoading: false)
        }
    }
}

private struct WebhookTestState: Equatable {
    var message: String
    var isError: Bool
    var isLoading: Bool
}

private struct AgentEditorCard: View {
    @Binding var agent: AgentProfile
    var focusedField: FocusState<AgentField?>.Binding
    var status: WebhookTestState?
    var onTestWebhook: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: $agent.name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused(focusedField, equals: .agentName(agent.id))

            TextField("Rolle", text: $agent.role)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
                .focused(focusedField, equals: .agentRole(agent.id))

            HStack {
                Label(agent.status.description, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Color.green)
                Spacer()
            }

            TextField("Webhook URL", text: Binding(
                get: { agent.webhookURL?.absoluteString ?? "" },
                set: { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    agent.webhookURL = trimmed.isEmpty ? nil : URL(string: trimmed)
                }
            ))
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .focused(focusedField, equals: .agentWebhook(agent.id))

            HStack {
                Button("Webhook testen") {
                    onTestWebhook()
                }
                if status?.isLoading == true {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
                Spacer()
                Button("Entfernen", role: .destructive) {
                    onRemove()
                }
            }

            if let status {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon(for: status))
                        .foregroundStyle(status.isError ? Color.red : Color.green)
                    Text(status.message)
                        .font(.caption)
                        .foregroundStyle(status.isError ? Color.red : Color.secondary)
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 8)
    }

    private func statusIcon(for status: WebhookTestState) -> String {
        if status.isLoading {
            return "hourglass"
        }
        return status.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }
}

#Preview {
    NavigationStack {
        AgentManagementScreen(viewModel: ProfileViewModel(appState: AppState(previewUser: SampleData.previewUser)))
    }
}
