import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var newAgentName: String = ""
    @State private var newAgentRole: String = ""

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                agentSection
                sessionSection
            }
            .navigationTitle("Profil")
        }
        .toast(message: viewModel.toastMessage, isPresented: Binding(
            get: { viewModel.toastMessage != nil },
            set: { newValue in if !newValue { viewModel.toastMessage = nil } }
        ))
        .onAppear {
            viewModel.attach(appState: appState)
        }
    }

    private var profileSection: some View {
        Section(header: Text("Dein Profil")) {
            TextField("Name", text: $viewModel.draftName)
            TextField("Bio", text: $viewModel.draftBio, axis: .vertical)
                .lineLimit(2...5)
            Toggle("Aktiv", isOn: $viewModel.isActive)

            Button("Profil speichern") {
                viewModel.saveProfile()
            }
        }
    }

    private var agentSection: some View {
        Section(header: Text("Agents"), footer: Text("Aktiviere oder deaktiviere Agents, um ihren Status zu simulieren.")) {
            ForEach(viewModel.agents) { agent in
                HStack {
                    VStack(alignment: .leading) {
                        Text(agent.name)
                        Text(agent.role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        Button(agent.status == .online ? "Als offline markieren" : "Als online markieren") {
                            viewModel.toggleAgent(agent)
                        }
                        Button("Agent entfernen", role: .destructive) {
                            viewModel.removeAgent(agent)
                        }
                    } label: {
                        Label(agent.status.description, systemImage: agent.status == .online ? "checkmark.circle.fill" : "clock")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Agent Name", text: $newAgentName)
                TextField("Rolle", text: $newAgentRole)
                Button("Agent hinzufügen") {
                    viewModel.addAgent(name: newAgentName, role: newAgentRole)
                    newAgentName = ""
                    newAgentRole = ""
                }
                .disabled(newAgentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var sessionSection: some View {
        Section {
            Button("Abmelden", role: .destructive) {
                appState.logout()
            }
        }
    }
}

private struct ToastModifier: ViewModifier {
    let message: String
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                VStack {
                    Spacer()
                    Text(message)
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .shadow(radius: 8)
                        .padding()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: isPresented)
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
