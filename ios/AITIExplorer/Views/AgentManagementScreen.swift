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
    @State private var newAgentTools: [AgentTool] = []
    @State private var webhookStatus: [UUID: WebhookTestState] = [:]
    @State private var agentPendingRemoval: AgentProfile?
    @FocusState private var focusedField: AgentField?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                headerCard

                agentsSection

                newAgentCard
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
            .padding(.top, 16)
        }
        .navigationTitle("Agents verwalten")
        .toolbar { toolbarContent }
        .explorerBackground()
        .scrollDismissesKeyboard(.interactively)
        .dismissFocusOnInteract($focusedField)
        .confirmationDialog(
            "Agent entfernen?",
            isPresented: Binding(
                get: { agentPendingRemoval != nil },
                set: { newValue in if !newValue { agentPendingRemoval = nil } }
            ),
            presenting: agentPendingRemoval
        ) { agent in
            Button("Agent „\(agent.name)“ löschen", role: .destructive) {
                focusedField = nil
                webhookStatus[agent.id] = nil
                viewModel.removeAgent(agent)
                agentPendingRemoval = nil
            }
            Button("Abbrechen", role: .cancel) {
                agentPendingRemoval = nil
            }
        } message: { agent in
            Text("Soll der Agent „\(agent.name)“ wirklich entfernt werden?")
        }
        .onDisappear {
            viewModel.saveAgentChanges()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deine orchestrierten Agents")
                .font(.explorer(.title3, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textPrimary)

            Text("Aktiviere Workflows, verwalte Tool-Zugriffe und definiere Webhooks pro Agent. Änderungen werden sofort synchronisiert.")
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textSecondary)

            if !viewModel.agents.isEmpty {
                Text("\(viewModel.agents.count) aktive Agenten")
                    .font(.explorer(.caption, weight: .medium))
                    .foregroundStyle(ExplorerTheme.goldGradient)
            }
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(ExplorerTheme.surface.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.35), lineWidth: 1.1)
                )
        )
    }

    private var agentsSection: some View {
        VStack(spacing: 22) {
            if viewModel.agents.isEmpty {
                emptyState
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
                            agentPendingRemoval = agent
                        }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Noch keine Agents angelegt")
                .font(.explorer(.callout, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textSecondary)
            Text("Nutze das Formular unten, um deinen ersten Agenten anzulegen und mit Tools auszustatten.")
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textMuted)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(ExplorerTheme.surface.opacity(0.85))
        )
    }

    private var newAgentCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Neuen Agent hinzufügen")
                .font(.explorer(.headline, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textPrimary)

            explorerTextField("Name", text: $newAgentName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .newName)

            explorerTextField("Rolle", text: $newAgentRole)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .newRole)

            explorerTextField("Webhook URL (optional)", text: $newAgentWebhook)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .newWebhook)

            ToolEditor(title: "Aktive Tools", tools: $newAgentTools)

            Button {
                viewModel.addAgent(
                    name: newAgentName.trimmingCharacters(in: .whitespacesAndNewlines),
                    role: newAgentRole.trimmingCharacters(in: .whitespacesAndNewlines),
                    webhookURLString: newAgentWebhook,
                    tools: newAgentTools
                )
                newAgentName = ""
                newAgentRole = ""
                newAgentWebhook = ""
                newAgentTools = []
                focusedField = nil
            } label: {
                Text("Agent erstellen")
            }
            .buttonStyle(ExplorerPrimaryButtonStyle())
            .disabled(newAgentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(ExplorerTheme.surface.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.3), lineWidth: 1.1)
                )
        )
    }

    private func explorerTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(ExplorerTheme.surface.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(ExplorerTheme.goldHighlightStart.opacity(0.3), lineWidth: 1)
            )
            .font(.explorer(.callout))
            .foregroundStyle(ExplorerTheme.textPrimary)
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

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                viewModel.saveAgentChanges(showToast: true)
            } label: {
                Text("Änderungen sichern")
                    .font(.explorer(.callout, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(ExplorerTheme.goldHighlightStart)
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Agent „\(agent.name)“")
                        .font(.explorer(.headline, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textPrimary)
                    Text(agent.role)
                        .font(.explorer(.footnote))
                        .foregroundStyle(ExplorerTheme.textSecondary)
                }

                Spacer()

                Label(agent.status.description, systemImage: "circle.fill")
                    .font(.explorer(.caption, weight: .semibold))
                    .foregroundStyle(ExplorerTheme.success)
            }

            TextField("Name", text: $agent.name)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(ExplorerTheme.surface.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.3), lineWidth: 1)
                )
                .font(.explorer(.callout))
                .foregroundStyle(ExplorerTheme.textPrimary)
                .focused(focusedField, equals: .agentName(agent.id))

            TextField("Rolle", text: $agent.role)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(true)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(ExplorerTheme.surface.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.3), lineWidth: 1)
                )
                .font(.explorer(.callout))
                .foregroundStyle(ExplorerTheme.textPrimary)
                .focused(focusedField, equals: .agentRole(agent.id))

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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ExplorerTheme.surface.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ExplorerTheme.goldHighlightStart.opacity(0.3), lineWidth: 1)
            )
            .font(.explorer(.callout))
            .foregroundStyle(ExplorerTheme.textPrimary)
            .focused(focusedField, equals: .agentWebhook(agent.id))

            ToolEditor(title: "Aktive Tools", tools: $agent.tools)

            HStack(spacing: 12) {
                Button("Webhook testen") {
                    onTestWebhook()
                }
                .buttonStyle(ExplorerSecondaryButtonStyle())

                if status?.isLoading == true {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(ExplorerTheme.goldHighlightStart)
                }

                Spacer()

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Text("Agent entfernen")
                        .font(.explorer(.callout, weight: .semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(ExplorerTheme.danger.opacity(0.18))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(ExplorerTheme.danger.opacity(0.45), lineWidth: 1)
                        )
                        .foregroundStyle(ExplorerTheme.danger)
                }
                .buttonStyle(.plain)
            }

            if let status {
                StatusMessageView(status: status)
                    .transition(.opacity)
            }
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(ExplorerTheme.surface.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.3), lineWidth: 1.1)
                )
        )
    }
}

private struct StatusMessageView: View {
    let status: WebhookTestState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .foregroundStyle(status.isError ? ExplorerTheme.danger : ExplorerTheme.success)
            Text(status.message)
                .font(.explorer(.caption))
                .foregroundStyle(status.isError ? ExplorerTheme.danger : ExplorerTheme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill((status.isError ? ExplorerTheme.danger : ExplorerTheme.success).opacity(0.12))
        )
    }

    private var statusIcon: String {
        if status.isLoading {
            return "hourglass"
        }
        return status.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }
}

private struct ToolEditor: View {
    let title: String
    @Binding var tools: [AgentTool]
    @State private var draftName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.explorer(.footnote, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(spacing: 12) {
                TextField("Tool hinzufügen", text: $draftName)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(ExplorerTheme.surface.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(ExplorerTheme.goldHighlightStart.opacity(0.3), lineWidth: 1)
                    )
                    .font(.explorer(.callout))
                    .foregroundStyle(ExplorerTheme.textPrimary)

                Button("Hinzufügen") {
                    addTool()
                }
                .buttonStyle(ExplorerSecondaryButtonStyle())
                .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if tools.isEmpty {
                Text("Noch keine Tools hinterlegt. Füge Begriffe wie „Websuche“ oder „Notion API“ hinzu.")
                    .font(.explorer(.caption))
                    .foregroundStyle(ExplorerTheme.textMuted)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(tools) { tool in
                        HStack(spacing: 8) {
                            Text(tool.name)
                                .font(.explorer(.caption, weight: .medium))
                                .foregroundStyle(ExplorerTheme.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Button {
                                remove(tool)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(ExplorerTheme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(ExplorerTheme.surfaceElevated.opacity(0.9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(ExplorerTheme.goldHighlightStart.opacity(0.28), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func addTool() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tools.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            tools.append(AgentTool(name: trimmed))
        }
        draftName = ""
    }

    private func remove(_ tool: AgentTool) {
        tools.removeAll { $0.id == tool.id }
    }
}

#Preview {
    NavigationStack {
        AgentManagementScreen(viewModel: ProfileViewModel(appState: AppState(previewUser: SampleData.previewUser)))
    }
}
