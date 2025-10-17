import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    appearanceCard

                    accentCard

                    resetButton
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

    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                viewModel.save()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.saveStatus == .inProgress {
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                    Text("Speichern")
                        .font(.explorer(.callout, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(ExplorerTheme.goldHighlightStart)
            .disabled(viewModel.saveStatus == .inProgress)
        }
    }

    private var resetButton: some View {
        Button(role: .destructive) {
            viewModel.reset()
        } label: {
            Text("Zurücksetzen")
                .font(.explorer(.callout, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ExplorerTheme.danger)
        .padding(.top, 8)
    }

    private func segmentedOptions<Selection: Hashable, Content: View>(
        for options: [Selection],
        selection: Binding<Selection>,
        @ViewBuilder content: @escaping (Selection) -> Content
    ) -> some View where Selection: Identifiable {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(options, id: \.self) { option in
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
                            .fill(
                                isSelected
                                    ? AnyShapeStyle(ExplorerTheme.goldGradient.opacity(0.18))
                                    : AnyShapeStyle(
                                        ExplorerTheme.secondaryCardBackground(
                                            for: appState.settings.colorScheme.preferredScheme ?? .dark
                                        )
                                    )
                            )
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
