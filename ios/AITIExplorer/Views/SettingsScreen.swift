import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    hero

                    appearanceCard

                    accentCard

                    infoCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .padding(.top, 16)
            }
            .navigationTitle("Einstellungen")
            .toolbar { toolbarItems }
        }
        .explorerBackground()
        .onAppear {
            viewModel.attach(appState: appState)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Arbeite im perfekten Licht")
                .font(.explorer(.title2, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textPrimary)

            Text("Steuere Erscheinungsbild und Akzentfarben deines Workspaces. Änderungen greifen sofort und werden pro Benutzerprofil gespeichert.")
                .font(.explorer(.callout))
                .foregroundStyle(ExplorerTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    ExplorerTheme.goldGradient
                        .opacity(0.16)
                        .blendMode(.screen)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.4), lineWidth: 1.2)
                )
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(ExplorerTheme.goldGradient)
                .frame(width: 80, height: 80)
                .blur(radius: 12)
                .offset(x: 30, y: -40)
        }
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Farbschema")
                .font(.explorer(.headline, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textPrimary)

            Text("Wechsle zwischen hellem und dunklem Modus oder folge den Systemeinstellungen deines Geräts.")
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textSecondary)

            segmentedOptions(for: ColorSchemeOption.allCases, selection: $viewModel.settings.colorScheme) { option in
                Text(option.title)
                    .font(.explorer(.callout, weight: .medium))
            }
        }
        .explorerCard()
    }

    private var accentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Akzentfarben")
                .font(.explorer(.headline, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textPrimary)

            Text("Stimme Buttons, Statusindikatoren und Highlights auf deine Brand-Farben ab.")
                .font(.explorer(.footnote))
                .foregroundStyle(ExplorerTheme.textSecondary)

            segmentedOptions(for: AccentColorOption.allCases, selection: $viewModel.settings.accentColor) { option in
                HStack(spacing: 10) {
                    Circle()
                        .fill(option.color)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                    Text(option.title)
                        .font(.explorer(.callout, weight: .medium))
                }
            }
        }
        .explorerCard()
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Alle Änderungen werden automatisch für dein Profil gesichert.", systemImage: "sparkles")
                .font(.explorer(.callout, weight: .medium))
                .foregroundStyle(ExplorerTheme.textPrimary)

            if viewModel.saveStatus == .success {
                Label("Gespeichert!", systemImage: "checkmark.seal.fill")
                    .font(.explorer(.footnote, weight: .medium))
                    .foregroundStyle(ExplorerTheme.success)
            } else if viewModel.saveStatus == .inProgress {
                Label("Speichern …", systemImage: "clock")
                    .font(.explorer(.footnote, weight: .medium))
                    .foregroundStyle(ExplorerTheme.textSecondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ExplorerTheme.secondaryCardBackground(for: appState.settings.colorScheme.preferredScheme ?? .dark))
        )
    }

    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                viewModel.reset()
            } label: {
                Text("Zurücksetzen")
                    .font(.explorer(.callout, weight: .medium))
                    .foregroundStyle(ExplorerTheme.textSecondary)
            }

            Button {
                viewModel.save()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.saveStatus == .inProgress {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text("Speichern")
                }
            }
            .buttonStyle(ExplorerPrimaryButtonStyle())
            .frame(width: 150)
            .disabled(viewModel.saveStatus == .inProgress)
        }
    }

    private func segmentedOptions<Selection: Hashable, Content: View>(
        for options: [Selection],
        selection: Binding<Selection>,
        @ViewBuilder content: @escaping (Selection) -> Content
    ) -> some View where Selection: Identifiable {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(options) { option in
                let isSelected = option == selection.wrappedValue
                Button {
                    selection.wrappedValue = option
                } label: {
                    HStack(spacing: 10) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ExplorerTheme.goldGradient)
                        }
                        content(option)
                            .foregroundStyle(isSelected ? ExplorerTheme.textPrimary : ExplorerTheme.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isSelected ? ExplorerTheme.goldGradient.opacity(0.18) : ExplorerTheme.secondaryCardBackground(for: appState.settings.colorScheme.preferredScheme ?? .dark))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected ? ExplorerTheme.goldHighlightStart.opacity(0.55) : ExplorerTheme.divider,
                                lineWidth: isSelected ? 1.4 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    SettingsScreen()
        .environmentObject(AppState(previewUser: SampleData.previewUser))
}
