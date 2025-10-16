import SwiftUI

private enum ProfileField: Hashable {
    case name
    case bio
}

struct ProfileScreen: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @FocusState private var focusedField: ProfileField?

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                agentManagementSection
                sessionSection
            }
            .navigationTitle("Profil")
            .scrollDismissesKeyboard(.interactively)
            .dismissFocusOnInteract($focusedField)
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
        Section {
            TextField("Name", text: $viewModel.draftName)
                .focused($focusedField, equals: .name)
            TextField("Beschreibung", text: $viewModel.draftBio, axis: .vertical)
                .lineLimit(2...5)
                .focused($focusedField, equals: .bio)

            LabeledContent("Status") {
                Label(viewModel.statusLabel, systemImage: viewModel.profile.isActive ? "checkmark.circle.fill" : "xmark.circle")
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(viewModel.profile.isActive ? Color.green : Color.secondary)
            }

            LabeledContent("Agenten insgesamt") {
                Text("\(viewModel.agents.count)")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            Text(viewModel.statusDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Profil speichern") {
                viewModel.saveProfile()
                focusedField = nil
            }
        }
        header: {
            Text("Dein Profil")
        }
        footer: {
            Text(viewModel.agentCountText)
        }
    }

    private var agentManagementSection: some View {
        Section {
            NavigationLink {
                AgentManagementScreen(viewModel: viewModel)
            } label: {
                Label("Agents verwalten", systemImage: "person.3.sequence")
            }
        }
        header: {
            Text("Agents")
        }
        footer: {
            Text("Verwalte deine Agents und ihre Webhook-Integrationen in einem eigenen Bereich.")
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
