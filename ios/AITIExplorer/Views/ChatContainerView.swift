import SwiftUI

struct ChatContainerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @State private var draftedMessage: String = ""
    @State private var showSearchSheet = false
    @StateObject private var profileViewModel = ProfileViewModel()
    @State private var isPresentingAgentManager = false

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.automatic)) {
            chatList
        } detail: {
            if let agent = viewModel.selectedAgent {
                ChatDetailView(
                    agent: agent,
                    draftedMessage: $draftedMessage,
                    onSend: { text, attachments in
                        viewModel.sendMessage(text, attachments: attachments)
                        draftedMessage = ""
                    },
                    pendingResponse: viewModel.pendingResponse
                )
                .toolbar { toolbarItems }
            } else {
                ContentUnavailableView(
                    "Kein Agent ausgewählt",
                    systemImage: "message.badge.waveform.fill",
                    description: Text("Lege in deinem Profil einen Agenten an oder aktiviere ihn." )
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            viewModel.attach(appState: appState)
            if viewModel.selectedAgent == nil, let agent = appState.currentUser?.agents.first {
                viewModel.select(agent: agent)
            }
            viewModel.isShowingOverviewOnPhone = false
            viewModel.isSearching = false
            profileViewModel.attach(appState: appState)
        }
        .sheet(isPresented: $showSearchSheet, onDismiss: {
            viewModel.isSearching = false
        }) {
            NavigationStack {
                SearchResultsView(
                    query: $viewModel.searchQuery,
                    results: viewModel.searchResults,
                    isSearching: viewModel.isSearching
                )
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isPresentingAgentManager) {
            NavigationStack {
                AgentManagementScreen(viewModel: profileViewModel)
            }
        }
    }

    private var chatList: some View {
        List(selection: $viewModel.selectedAgentID) {
            Section("Deine Agents") {
                ForEach(viewModel.agents) { agent in
                    ChatListRow(agent: agent)
                        .tag(agent.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.select(agent: agent)
                        }
                }
            }

            Section {
                Button {
                    isPresentingAgentManager = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Neuen Agent anlegen")
                                .font(.headline)
                            Text("Öffnet die Agent-Verwaltung")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.accentColor.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Chats")
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                if showSearchSheet {
                    showSearchSheet = false
                } else {
                    viewModel.isSearching = true
                    showSearchSheet = true
                }
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Chats durchsuchen")
        }
    }
}

private struct ChatListRow: View {
    let agent: AgentProfile

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                Image(systemName: agent.avatarSystemName)
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.headline)
                Text(agent.conversation.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !agent.tools.isEmpty {
                    Text(agent.tools.map { $0.title }.joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(agent.conversation.lastUpdated, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(agent.status.description, systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(Color.green)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ChatContainerView()
        .environmentObject(AppState(previewUser: SampleData.previewUser))
}
