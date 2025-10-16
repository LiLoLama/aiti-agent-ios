import SwiftUI

struct ChatContainerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @State private var draftedMessage: String = ""
    @State private var showSearchSheet = false

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.automatic)) {
            chatList
        } detail: {
            if let agent = viewModel.selectedAgent {
                ChatDetailView(
                    agent: agent,
                    draftedMessage: $draftedMessage,
                    onSend: { text in
                        viewModel.sendMessage(text)
                        draftedMessage = ""
                    },
                    pendingResponse: viewModel.pendingResponse,
                    onShowSearch: {
                        showSearchSheet.toggle()
                        viewModel.isSearching = true
                    }
                )
                .toolbar { toolbarItems }
                .navigationTitle(agent.name)
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
        }
        .sheet(isPresented: $showSearchSheet) {
            NavigationStack {
                SearchResultsView(
                    query: $viewModel.searchQuery,
                    results: viewModel.searchResults,
                    isSearching: viewModel.isSearching
                )
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            viewModel.isSearching = false
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Chats")
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                showSearchSheet.toggle()
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
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(agent.conversation.lastUpdated, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(agent.status.description, systemImage: statusIcon)
                    .font(.caption2)
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, 6)
    }

    private var statusIcon: String {
        switch agent.status {
        case .online:
            return "circle.fill"
        case .offline:
            return "circle"
        case .busy:
            return "clock"
        }
    }

    private var statusColor: Color {
        switch agent.status {
        case .online:
            return .green
        case .offline:
            return .gray
        case .busy:
            return .orange
        }
    }
}

#Preview {
    ChatContainerView()
        .environmentObject(AppState(previewUser: SampleData.previewUser))
}
