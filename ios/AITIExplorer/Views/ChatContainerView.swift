import SwiftUI
import UIKit

struct ChatContainerView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChatViewModel()
    @State private var draftedMessage: String = ""
    @State private var showSearchSheet = false
    @StateObject private var profileViewModel = ProfileViewModel()
    @State private var isPresentingAgentManager = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var navigationPath = NavigationPath()

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                splitLayout
            }
        }
        .explorerBackground()
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
            .explorerBackground()
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isPresentingAgentManager) {
            NavigationStack {
                AgentManagementScreen(viewModel: profileViewModel)
            }
            .explorerBackground()
        }
    }

    private var splitLayout: some View {
        NavigationSplitView(columnVisibility: .constant(.automatic)) {
            chatList { agent in
                viewModel.select(agent: agent)
            }
            .navigationTitle("Workspace")
        } detail: {
            if let agent = viewModel.selectedAgent {
                ChatDetailView(
                    agent: agent,
                    userAvatarImageData: appState.currentUser?.avatarImageData,
                    userAvatarSystemName: appState.currentUser?.avatarSystemName ?? "person.fill",
                    draftedMessage: $draftedMessage,
                    onSend: { text, attachments in
                        viewModel.sendMessage(text, attachments: attachments)
                        draftedMessage = ""
                    },
                    pendingResponse: viewModel.pendingResponse
                )
                .toolbar { toolbarItems }
            } else {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "message.badge.waveform.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(ExplorerTheme.goldGradient)
                    Text("Kein Agent ausgewählt")
                        .font(.explorer(.title3, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textPrimary)
                    Text("Wähle links einen Agenten oder erstelle einen neuen, um mit deiner Arbeit zu starten.")
                        .font(.explorer(.footnote))
                        .foregroundStyle(ExplorerTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)
                    Spacer()
                }
                .explorerBackground()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var compactLayout: some View {
        NavigationStack(path: $navigationPath) {
            chatList { agent in
                viewModel.select(agent: agent)
                navigationPath = NavigationPath()
                navigationPath.append(agent.id)
            }
            .navigationTitle("Workspace")
            .navigationDestination(for: UUID.self) { id in
                if let agent = viewModel.agents.first(where: { $0.id == id }) {
                    ChatDetailView(
                        agent: agent,
                        userAvatarImageData: appState.currentUser?.avatarImageData,
                        userAvatarSystemName: appState.currentUser?.avatarSystemName ?? "person.fill",
                        draftedMessage: $draftedMessage,
                        onSend: { text, attachments in
                            viewModel.sendMessage(text, attachments: attachments)
                            draftedMessage = ""
                        },
                        pendingResponse: viewModel.pendingResponse
                    )
                    .toolbar { toolbarItems }
                }
            }
        }
    }

    private func chatList(onSelect: @escaping (AgentProfile) -> Void) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                LazyVStack(spacing: 18) {
                    ForEach(viewModel.agents) { agent in
                        let isSelected = agent.id == viewModel.selectedAgentID
                        Button {
                            onSelect(agent)
                        } label: {
                            AgentOverviewCard(agent: agent, isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    isPresentingAgentManager = true
                } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(ExplorerTheme.goldGradient.opacity(0.2))
                                Image(systemName: "sparkle.magnifyingglass")
                                    .foregroundStyle(ExplorerTheme.goldGradient)
                            }
                            .frame(width: 44, height: 44)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Neuen Agent anlegen")
                                    .font(.explorer(.callout, weight: .semibold))
                                    .foregroundStyle(ExplorerTheme.textPrimary)
                                Text("Öffnet die Agent-Verwaltung")
                                    .font(.explorer(.caption))
                                    .foregroundStyle(ExplorerTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(ExplorerTheme.textSecondary)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(ExplorerTheme.surface.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(ExplorerTheme.goldHighlightStart.opacity(0.35), lineWidth: 1.1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
        }
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
            .tint(ExplorerTheme.goldHighlightStart)
        }
    }
}

private struct AgentOverviewCard: View {
    let agent: AgentProfile
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AnyShapeStyle(ExplorerTheme.surfaceElevated.opacity(0.9)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(ExplorerTheme.goldHighlightStart.opacity(0.25), lineWidth: 1)
                        )
                        .frame(width: 64, height: 64)

                    avatarImage
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(agent.name)
                        .font(.explorer(.headline, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textPrimary)

                    Text(agent.role)
                        .font(.explorer(.footnote))
                        .foregroundStyle(ExplorerTheme.textSecondary)

                    if !agent.tools.isEmpty {
                        Text(agent.tools.namesJoined())
                            .font(.explorer(.caption))
                            .foregroundStyle(ExplorerTheme.textMuted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(agent.conversation.lastUpdated, style: .time)
                        .font(.explorer(.caption))
                        .foregroundStyle(ExplorerTheme.textMuted)

                    Label(agent.status.description, systemImage: "circle.fill")
                        .font(.explorer(.caption2, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(ExplorerTheme.success)
                }
            }

            Text(agent.conversation.preview)
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(backgroundFillStyle)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(isSelected ? ExplorerTheme.goldHighlightStart.opacity(0.6) : ExplorerTheme.divider, lineWidth: isSelected ? 1.4 : 1)
                )
        )
        .shadow(color: Color.black.opacity(isSelected ? 0.42 : 0.28), radius: isSelected ? 32 : 22, x: 0, y: isSelected ? 24 : 18)
    }

    private var backgroundFillStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(ExplorerTheme.goldGradient.opacity(0.14))
        } else {
            return AnyShapeStyle(ExplorerTheme.surface.opacity(0.9))
        }
    }
}

private extension AgentOverviewCard {
    var avatarImage: some View {
        Group {
            if let data = agent.avatarImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: agent.avatarSystemName)
                    .resizable()
                    .scaledToFit()
                    .padding(14)
                    .foregroundStyle(ExplorerTheme.goldGradient)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

#Preview {
    ChatContainerView()
        .environmentObject(AppState(previewUser: SampleData.previewUser))
}
