import SwiftUI
import PhotosUI
import UIKit

private enum ProfileField: Hashable {
    case name
    case bio
}

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = ProfileViewModel()
    @FocusState private var focusedField: ProfileField?
    @State private var showAgentManager = false
    @State private var showUserAdministration = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    personalCard

                    statusCards

                    if viewModel.canManageUsers {
                        adminCard
                    }

                    agentsCard

                    sessionCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .padding(.top, 16)
            }
            .navigationTitle("Profil")
        }
        .explorerBackground()
        .scrollDismissesKeyboard(.interactively)
        .dismissFocusOnInteract($focusedField)
        .toast(message: viewModel.toastMessage, isPresented: Binding(
            get: { viewModel.toastMessage != nil },
            set: { newValue in if !newValue { viewModel.toastMessage = nil } }
        ))
        .sheet(isPresented: $showAgentManager) {
            NavigationStack {
                AgentManagementScreen(viewModel: viewModel)
            }
            .explorerBackground()
        }
        .sheet(isPresented: $showUserAdministration) {
            NavigationStack {
                AdminUserManagementScreen()
            }
            .explorerBackground()
        }
        .onAppear {
            viewModel.attach(appState: appState)
        }
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        viewModel.updateAvatar(with: data)
                    }
                }
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private var personalCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        Circle()
                            .fill(elementBackgroundColor)
                            .frame(width: 86, height: 86)
                            .overlay(
                                Circle()
                                    .stroke(ExplorerTheme.goldHighlightStart.opacity(colorScheme == .dark ? 0.35 : 0.24), lineWidth: 1.2)
                            )

                        avatarContent

                        Circle()
                            .fill(ExplorerTheme.goldGradient)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.white)
                            )
                            .shadow(color: ExplorerTheme.goldHighlightEnd.opacity(0.35), radius: 10, x: 0, y: 6)
                            .offset(x: 6, y: 6)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profilbild auswählen")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Dein persönlicher Bereich")
                        .font(.explorer(.title3, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textPrimary)

                    Text("Passe Name, Bio und Agentenzuordnung an. Änderungen werden sofort für dein Team sichtbar.")
                        .font(.explorer(.footnote))
                        .foregroundStyle(ExplorerTheme.textSecondary)
                }
                Spacer()
            }

            TextField("Name", text: $viewModel.draftName)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(elementBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
                .font(.explorer(.callout))
                .foregroundStyle(ExplorerTheme.textPrimary)
                .focused($focusedField, equals: .name)

            TextField("Kurzbeschreibung", text: $viewModel.draftBio, axis: .vertical)
                .lineLimit(2...5)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(elementBackgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(cardBorderColor, lineWidth: 1)
                )
                .font(.explorer(.callout))
                .foregroundStyle(ExplorerTheme.textPrimary)
                .focused($focusedField, equals: .bio)

            Button {
                focusedField = nil
                viewModel.saveProfile()
            } label: {
                Text("Profil speichern")
            }
            .buttonStyle(ExplorerPrimaryButtonStyle())
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(cardBorderColor, lineWidth: 1.2)
                )
        )
    }

    private var statusCards: some View {
        ViewThatFits {
            HStack(spacing: 18) {
                statusTile(title: "Status", subtitle: viewModel.statusLabel, description: nil, accent: ExplorerTheme.success)

                statusTile(title: "Agents", subtitle: "\(viewModel.agents.count)", description: nil, accent: ExplorerTheme.goldHighlightStart)
            }

            VStack(spacing: 18) {
                statusTile(title: "Status", subtitle: viewModel.statusLabel, description: nil, accent: ExplorerTheme.success)

                statusTile(title: "Agents", subtitle: "\(viewModel.agents.count)", description: nil, accent: ExplorerTheme.goldHighlightStart)
            }
        }
    }

    private var adminCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Administration")
                .font(.explorer(.headline, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textPrimary)

            Text("Behalte alle Nutzer im Blick, prüfe ihren Status und reaktiviere Accounts direkt aus der App.")
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textSecondary)

            Button {
                showUserAdministration = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.3.sequence")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.success)
                    Text("Nutzerübersicht öffnen")
                        .font(.explorer(.callout, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(ExplorerTheme.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(elevatedCardBackgroundColor)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(cardBorderColor, lineWidth: 1.1)
                )
        )
    }

    private func statusTile(title: String, subtitle: String, description: String?, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.explorer(.caption, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textSecondary)
                .textCase(.uppercase)
            Text(subtitle)
                .font(.explorer(.title3, weight: .semibold))
                .foregroundStyle(accent)
            if let description, !description.isEmpty {
                Text(description)
                    .font(.explorer(.caption))
                    .foregroundStyle(ExplorerTheme.textMuted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(elementBackgroundColor)
        )
    }

    private var agentsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Agentenverwaltung")
                .font(.explorer(.headline, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textPrimary)

            Text("Organisiere Tool-Zugriffe, Webhooks und Beschreibungen deiner Agents in einer kuratierten Übersicht.")
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textSecondary)

            Button {
                showAgentManager = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.person.crop")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.goldGradient)
                    Text("Agents verwalten")
                        .font(.explorer(.callout, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(ExplorerTheme.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(elevatedCardBackgroundColor)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(cardBorderColor, lineWidth: 1.1)
                )
        )
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session")
                .font(.explorer(.headline, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textPrimary)

            Text("Melde dich ab, um in ein anderes Profil zu wechseln.")
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textSecondary)

            Button(role: .destructive) {
                appState.logout()
            } label: {
                Text("Abmelden")
                    .font(.explorer(.callout, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(ExplorerTheme.danger.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(ExplorerTheme.danger.opacity(0.45), lineWidth: 1.1)
                    )
                    .foregroundStyle(ExplorerTheme.danger)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(cardBackgroundColor)
        )
    }
}

private extension ProfileScreen {
    var avatarContent: some View {
        Group {
            if let data = viewModel.avatarImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: viewModel.profile.avatarSystemName)
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .foregroundStyle(ExplorerTheme.goldGradient)
            }
        }
        .frame(width: 86, height: 86)
        .clipShape(Circle())
    }

    var cardBackgroundColor: Color {
        colorScheme == .dark ? ExplorerTheme.surface.opacity(0.92) : Color.white.opacity(0.97)
    }

    var elevatedCardBackgroundColor: Color {
        colorScheme == .dark ? ExplorerTheme.surfaceElevated.opacity(0.9) : Color.white.opacity(0.96)
    }

    var elementBackgroundColor: Color {
        colorScheme == .dark ? ExplorerTheme.surface.opacity(0.85) : Color.white
    }

    var cardBorderColor: Color {
        ExplorerTheme.goldHighlightStart.opacity(colorScheme == .dark ? 0.3 : 0.2)
    }
}

private struct ToastModifier: ViewModifier {
    let message: String
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.explorer(.footnote, weight: .medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(toastBackgroundColor)
                        )
                        .overlay(
                            Capsule()
                                .stroke(toastBorderColor, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 8)
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: isPresented)
    }
}

private extension ToastModifier {
    var toastBackgroundColor: Color {
        colorScheme == .dark ? ExplorerTheme.surface.opacity(0.9) : Color.white.opacity(0.96)
    }

    var toastBorderColor: Color {
        ExplorerTheme.goldHighlightStart.opacity(colorScheme == .dark ? 0.4 : 0.25)
    }
}

private extension View {
    func toast(message: String?, isPresented: Binding<Bool>) -> some View {
        modifier(ToastModifier(message: message ?? "", isPresented: isPresented))
    }
}

#Preview {
    ProfileScreen()
        .environmentObject(AppState(previewUser: SampleData.previewUser))
}
