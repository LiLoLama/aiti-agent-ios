import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                preferencesSection
                webhookSection
            }
            .navigationTitle("Einstellungen")
            .toolbar { toolbarItems }
            .alert("Webhook Test", isPresented: isTestingWebhookBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.webhookMessage ?? "")
            }
        }
        .onAppear {
            viewModel.attach(appState: appState)
        }
    }

    private var isTestingWebhookBinding: Binding<Bool> {
        Binding(
            get: { viewModel.webhookTestStatus == .success || viewModel.webhookTestStatus == .failure },
            set: { _ in viewModel.webhookTestStatus = .idle }
        )
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
            Toggle("Typing-Indikator anzeigen", isOn: $viewModel.settings.showTypingIndicator)
            Toggle("Kompaktes Layout", isOn: $viewModel.settings.preferCompactLayout)

            TextField("Notizen", text: $viewModel.settings.notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var webhookSection: some View {
        Section(header: Text("Webhook"), footer: Text("Nutze Webhooks, um externe Systeme mit Antworten deiner Agents zu versorgen.")) {
            TextField("https://hooks.example.com", text: Binding(
                get: { viewModel.settings.webhookURL?.absoluteString ?? "" },
                set: { viewModel.settings.webhookURL = URL(string: $0) }
            ))
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)

            Button("Webhook testen") {
                viewModel.testWebhook()
            }
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
