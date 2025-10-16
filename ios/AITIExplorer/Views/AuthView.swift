import SwiftUI

private enum AuthField: Hashable {
    case name
    case email
    case password
    case confirmPassword
}

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: AuthField?

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 820

            ZStack {
                ExplorerTheme.backgroundGradient
                    .ignoresSafeArea()

                if isCompact {
                    compactLayout
                        .padding(.vertical, 32)
                        .padding(.horizontal, 24)
                } else {
                    HStack(spacing: 32) {
                        heroPanel
                            .frame(width: max(proxy.size.width * 0.42, 360))

                        formPanel
                            .frame(maxWidth: 460)
                    }
                    .padding(.horizontal, 48)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissFocusOnInteract($focusedField)
        .onAppear {
            viewModel.attach(appState: appState)
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 28) {
            heroPanel
            formPanel
        }
    }

    private var heroPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(ExplorerTheme.goldGradient.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.6), lineWidth: 1.4)
                )
                .shadow(color: ExplorerTheme.goldHighlightEnd.opacity(0.35), radius: 30, x: 0, y: 22)

            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "bolt.badge.a.fill")
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(ExplorerTheme.goldGradient)
                    .shadow(color: ExplorerTheme.goldHighlightEnd.opacity(0.5), radius: 20, x: 0, y: 14)

                VStack(alignment: .leading, spacing: 12) {
                    Text("AITI Explorer Agent")
                        .font(.explorer(.largeTitle, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textPrimary)

                    Text("Ein Workspace für deine Agents, Datenquellen und Integrationen – immer synchron und bereit für die nächste Mission.")
                        .font(.explorer(.callout))
                        .foregroundStyle(ExplorerTheme.textPrimary.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 8) {
                        featureRow(icon: "sparkles", text: "Gläserne Inbox mit Markdown- und Audio-Support")
                        featureRow(icon: "bolt.fill", text: "Agenten in Echtzeit orchestrieren")
                        featureRow(icon: "link", text: "Webhooks und Tools flexibel anbinden")
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(36)
        }
    }

    private var formPanel: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.mode == .login ? "Willkommen zurück" : "Account anlegen")
                    .font(.explorer(.title2, weight: .semibold))
                    .foregroundStyle(ExplorerTheme.textPrimary)

                Text("Melde dich an, um deine Agents zu steuern oder wechsle in den Registrierungsmodus für einen neuen Zugang.")
                    .font(.explorer(.footnote))
                    .foregroundStyle(ExplorerTheme.textSecondary)
            }

            VStack(spacing: 16) {
                modeToggle

                if viewModel.mode == .register {
                    explorerTextField("Name", text: $viewModel.name)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                }

                explorerTextField("E-Mail", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)

                explorerSecureField("Passwort", text: $viewModel.password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)

                if viewModel.mode == .register {
                    explorerSecureField("Passwort bestätigen", text: $viewModel.confirmPassword)
                        .textContentType(.password)
                        .focused($focusedField, equals: .confirmPassword)
                }
            }

            VStack(spacing: 14) {
                Button {
                    focusedField = nil
                    viewModel.submit()
                } label: {
                    if viewModel.isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text(viewModel.primaryButtonTitle)
                    }
                }
                .buttonStyle(ExplorerPrimaryButtonStyle())
                .disabled(viewModel.isProcessing)

                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                        viewModel.toggleMode()
                    }
                    focusedField = nil
                } label: {
                    Text(viewModel.secondaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ExplorerSecondaryButtonStyle())

                if let errorMessage = viewModel.errorMessage {
                    messageBanner(text: errorMessage, icon: "exclamationmark.triangle.fill", tint: ExplorerTheme.danger)
                }

            }

            footer
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(ExplorerTheme.surface.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.25), lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.45), radius: 45, x: 0, y: 32)
        )
    }

    private var modeToggle: some View {
        HStack(spacing: 12) {
            toggleButton(title: "Anmelden", isSelected: viewModel.mode == .login) {
                viewModel.mode = .login
            }

            toggleButton(title: "Registrieren", isSelected: viewModel.mode == .register) {
                viewModel.mode = .register
            }
        }
    }

    private func toggleButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.explorer(.callout, weight: .medium))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            isSelected
                                ? AnyShapeStyle(ExplorerTheme.goldGradient.opacity(0.25))
                                : AnyShapeStyle(Color.white.opacity(0.04))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isSelected ? ExplorerTheme.goldHighlightStart.opacity(0.55) : ExplorerTheme.divider, lineWidth: 1.1)
                )
                .foregroundStyle(isSelected ? ExplorerTheme.textPrimary : ExplorerTheme.textSecondary)
                .shadow(color: ExplorerTheme.goldHighlightEnd.opacity(isSelected ? 0.25 : 0.05), radius: 12, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private func explorerTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(ExplorerTheme.surfaceElevated.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ExplorerTheme.goldHighlightStart.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .font(.explorer(.callout))
            .foregroundStyle(ExplorerTheme.textPrimary)
    }

    private func explorerSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(ExplorerTheme.surfaceElevated.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(ExplorerTheme.goldHighlightStart.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .font(.explorer(.callout))
            .foregroundStyle(ExplorerTheme.textPrimary)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.explorer(.callout, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textPrimary)
            Text(text)
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textPrimary.opacity(0.9))
        }
    }

    private func messageBanner(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.explorer(.footnote, weight: .semibold))
            Text(text)
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.12))
        )
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Demo-Zugang")
                .font(.explorer(.footnote, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textSecondary)
            Text("E-Mail: demo@aiti.ai • Passwort: SwiftRocks!")
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AuthView()
        .environmentObject(AppState())
}
