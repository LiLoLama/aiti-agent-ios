import SwiftUI

struct AgentManagementScreen: View {
    @ObservedObject var viewModel: ProfileViewModel

    @State private var newAgentName: String = ""
    @State private var newAgentRole: String = ""
    @State private var newAgentWebhook: String = ""
    @State private var webhookStatus: [UUID: WebhookTestState] = [:]

    var body: some View {
        Form {
            agentsSection
            addAgentSection
        }
        .navigationTitle("Agents verwalten")
        .toolbar { toolbarContent }
        .onDisappear {
            viewModel.saveAgentChanges()
        }
    }

    private var agentsSection: some View {
        Section(header: Text("Deine Agents"), footer: Text("Lege für jeden Agent individuelle Webhooks und Status fest.")) {
            if viewModel.agents.isEmpty {
                Text("Noch keine Agents angelegt. Erstelle unten deinen ersten Agenten.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach($viewModel.agents) { $agent in
                    AgentEditorCard(
                        agent: $agent,
                        status: webhookStatus[agent.wrappedValue.id],
                        onTestWebhook: { testWebhook(for: agent.wrappedValue) },
                        onRemove: {
                            webhookStatus[agent.wrappedValue.id] = nil
                            viewModel.removeAgent(agent.wrappedValue)
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
            TextField("Rolle", text: $newAgentRole)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
            TextField("Webhook URL (optional)", text: $newAgentWebhook)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            Button("Agent erstellen") {
                viewModel.addAgent(
                    name: newAgentName.trimmingCharacters(in: .whitespacesAndNewlines),
                    role: newAgentRole.trimmingCharacters(in: .whitespacesAndNewlines),
                    webhookURLString: newAgentWebhook
                )
                newAgentName = ""
                newAgentRole = ""
                newAgentWebhook = ""
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
    var status: WebhookTestState?
    var onTestWebhook: () -> Void
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name", text: $agent.name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)

            TextField("Rolle", text: $agent.role)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)

            Picker("Status", selection: $agent.status) {
                ForEach(AgentStatus.allCases) { status in
                    Text(status.description).tag(status)
                }
            }
            .pickerStyle(.menu)

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
