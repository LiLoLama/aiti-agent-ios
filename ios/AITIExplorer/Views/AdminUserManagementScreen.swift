import SwiftUI

struct AdminUserManagementScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = AdminUserManagementViewModel()

    var body: some View {
        ZStack {
            content

            if viewModel.isLoading && viewModel.users.isEmpty {
                ProgressView("Lade Nutzer …")
                    .font(.explorer(.body))
                    .foregroundStyle(ExplorerTheme.textSecondary)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Nutzerübersicht")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.loadUsers()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Nutzerliste aktualisieren")
            }
        }
        .onAppear {
            viewModel.attach(appState: appState)
            viewModel.loadUsersIfNeeded()
        }
        .alert("Fehler", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { newValue in
                if !newValue {
                    viewModel.alertMessage = nil
                }
            }
        ), presenting: viewModel.alertMessage) { _ in
            Button("OK", role: .cancel) {
                viewModel.alertMessage = nil
            }
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.users.isEmpty {
            if viewModel.isLoading {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                emptyState
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 18) {
                    ForEach(viewModel.users) { user in
                        userCard(for: user)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.3")
                .font(.system(size: 44))
                .foregroundStyle(ExplorerTheme.textSecondary.opacity(0.7))

            Text("Noch keine Nutzer gefunden")
                .font(.explorer(.headline, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textPrimary)

            Text("Ziehe zum Aktualisieren nach unten oder tippe auf den Button oben rechts, um die Liste aus Supabase zu laden.")
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if !viewModel.isLoading {
                Button {
                    viewModel.loadUsers()
                } label: {
                    Text("Nutzer laden")
                        .font(.explorer(.callout, weight: .semibold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(ExplorerTheme.goldGradient)
                        )
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func userCard(for user: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(user.name.isEmpty ? user.email : user.name)
                        .font(.explorer(.title3, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textPrimary)
                    Text(user.email)
                        .font(.explorer(.footnote))
                        .foregroundStyle(ExplorerTheme.textSecondary)
                }
                Spacer()
                statusBadge(isActive: user.isActive)
            }

            Divider()
                .opacity(colorScheme == .dark ? 0.2 : 0.12)

            HStack(spacing: 14) {
                Button {
                    viewModel.toggleActivation(for: user)
                } label: {
                    Label(user.isActive ? "Deaktivieren" : "Aktivieren",
                          systemImage: user.isActive ? "person.crop.circle.badge.xmark" : "person.crop.circle.badge.checkmark")
                        .font(.explorer(.callout, weight: .semibold))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(user.isActive ? ExplorerTheme.danger.opacity(0.16) : ExplorerTheme.success.opacity(0.18))
                        )
                        .foregroundStyle(user.isActive ? ExplorerTheme.danger : ExplorerTheme.success)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isUpdating(userId: user.id))

                if viewModel.isUpdating(userId: user.id) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(ExplorerTheme.textSecondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
        )
    }

    private func statusBadge(isActive: Bool) -> some View {
        Text(isActive ? "Aktiv" : "Inaktiv")
            .font(.explorer(.caption, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isActive ? ExplorerTheme.success.opacity(0.15) : ExplorerTheme.danger.opacity(0.15))
            )
            .foregroundStyle(isActive ? ExplorerTheme.success : ExplorerTheme.danger)
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? ExplorerTheme.surface.opacity(0.92) : Color.white.opacity(0.97)
    }

    private var cardBorderColor: Color {
        ExplorerTheme.goldHighlightStart.opacity(colorScheme == .dark ? 0.35 : 0.22)
    }
}

#Preview {
    NavigationStack {
        AdminUserManagementScreen()
            .environmentObject(AppState(previewUser: SampleData.previewUser))
            .explorerBackground()
    }
}
