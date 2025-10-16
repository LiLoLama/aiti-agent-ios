import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                preferencesSection
            }
            .navigationTitle("Einstellungen")
            .toolbar { toolbarItems }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            viewModel.attach(appState: appState)
        }
    }

    private var appearanceSection: some View {
        Section(header: Text("Darstellung")) {
            Picker("Farbschema", selection: $viewModel.settings.colorScheme) {
                ForEach(ColorSchemeOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            Picker("Akzentfarbe", selection: $viewModel.settings.accentColor) {
                ForEach(AccentColorOption.allCases) { option in
                    HStack {
                        Circle()
                            .fill(option.color)
                            .frame(width: 16, height: 16)
                        Text(option.title)
                    }
                    .tag(option)
                }
            }
        }
    }

    private var preferencesSection: some View {
        Section(header: Text("Chat Verhalten")) {
            Toggle("Sende-Sound abspielen", isOn: $viewModel.settings.playSendSound)
        }
    }

    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if viewModel.saveStatus == .inProgress {
                ProgressView()
            }
            Button("Zurücksetzen") {
                viewModel.reset()
            }
            Button("Speichern") {
                viewModel.save()
            }
            .disabled(viewModel.saveStatus == .inProgress)
        }
    }
}

#Preview {
    SettingsScreen()
        .environmentObject(AppState(previewUser: SampleData.previewUser))
}
