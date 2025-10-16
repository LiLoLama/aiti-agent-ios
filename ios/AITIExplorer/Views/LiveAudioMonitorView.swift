import SwiftUI

struct LiveAudioMonitorView: View {
    @StateObject private var engine = LiveAudioEngineManager()
    @State private var showErrorAlert = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Live Audio Monitor")
                .font(.title2)
                .bold()

            VStack(spacing: 12) {
                Text(String(format: "Current RMS: %.4f", engine.averagePower))
                    .font(.headline)
                ProgressView(value: min(engine.averagePower * 4, 1))
                    .tint(.green)
            }
            .frame(maxWidth: .infinity)

            Button(engine.isRunning ? "Stop Monitoring" : "Start Monitoring") {
                if engine.isRunning {
                    engine.stop()
                } else {
                    Task { await engine.start() }
                }
            }
            .font(.title3)
            .padding()
            .frame(maxWidth: .infinity)
            .background(engine.isRunning ? Color.red.opacity(0.8) : Color.accentColor.opacity(0.8))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
        .onChange(of: engine.activeError) { newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Audio Engine Error", isPresented: $showErrorAlert, presenting: engine.activeError) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.errorDescription ?? "An unknown error occurred.")
        }
    }
}

#Preview {
    LiveAudioMonitorView()
}
