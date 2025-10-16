import SwiftUI

struct AudioRecorderView: View {
    @StateObject private var recorder = AudioRecorderViewModel()
    @State private var showErrorAlert = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Audio Recorder")
                .font(.title2)
                .bold()

            Button(action: toggleRecording) {
                Label(recorder.isRecording ? "Stop Recording" : "Start Recording",
                      systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(recorder.isRecording ? Color.red.opacity(0.8) : Color.accentColor.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            if let url = recorder.recordingURL {
                VStack(spacing: 8) {
                    Text("Latest recording saved to:")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(url.lastPathComponent)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .onChange(of: recorder.activeError) { newValue in
            showErrorAlert = newValue != nil
        }
        .alert("Recording Error", isPresented: $showErrorAlert, presenting: recorder.activeError) { _ in
            Button("OK", role: .cancel) { }
        } message: { error in
            Text(error.errorDescription ?? "An unknown error occurred.")
        }
    }

    private func toggleRecording() {
        Task { await recorder.toggleRecording() }
    }
}

#Preview {
    AudioRecorderView()
}
