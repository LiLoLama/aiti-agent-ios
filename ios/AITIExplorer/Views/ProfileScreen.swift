import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                agentManagementSection
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

    private var agentManagementSection: some View {
        Section(header: Text("Agents"), footer: Text("Verwalte deine Agents und ihre Webhook-Integrationen in einem eigenen Bereich.")) {
            NavigationLink {
                AgentManagementScreen(viewModel: viewModel)
            } label: {
                Label("Agents verwalten", systemImage: "person.3.sequence")
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
