import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        VStack {
            Spacer(minLength: 40)

            VStack(spacing: 16) {
                Image(systemName: "bolt.badge.a.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.linearGradient(colors: [Color.yellow, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing))

                Text("AITI Explorer Agent")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Verwalte deine AI Agents, Chats und Integrationen an einem Ort.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            .padding(.bottom, 24)

            formSection
                .padding()
                .frame(maxWidth: 480)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 14)
                .padding(.horizontal)

            Spacer()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(LinearGradient(colors: [.black, Color(.sRGB, red: 0.1, green: 0.1, blue: 0.12, opacity: 1)], startPoint: .top, endPoint: .bottom))
        .onReceive(appState.$currentUser) { user in
            if user != nil {
                viewModel.infoMessage = nil
            }
        }
        .onAppear {
            viewModel.attach(appState: appState)
            viewModel.infoMessage = "Nutze demo@aiti.ai und SwiftRocks! zum Testen."
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Modus", selection: $viewModel.mode) {
                Text("Anmelden").tag(AuthViewModel.Mode.login)
                Text("Registrieren").tag(AuthViewModel.Mode.register)
            }
            .pickerStyle(.segmented)

            if viewModel.mode == .register {
                TextField("Name", text: $viewModel.name)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)
            }

            TextField("E-Mail", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)

            SecureField("Passwort", text: $viewModel.password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)

            if viewModel.mode == .register {
                SecureField("Passwort bestätigen", text: $viewModel.confirmPassword)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
            }

            Button(action: viewModel.submit) {
                if viewModel.isProcessing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(viewModel.primaryButtonTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)

            Button(viewModel.secondaryButtonTitle) {
                withAnimation(.spring()) {
                    viewModel.toggleMode()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }

            if let info = viewModel.infoMessage {
                Label(info, systemImage: "info.circle.fill")
                    .foregroundStyle(.green)
                    .font(.footnote)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Demo-Zugang")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("E-Mail: demo@aiti.ai • Passwort: SwiftRocks!")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }
}

#Preview {
    AuthView()
        .environmentObject(AppState())
}
