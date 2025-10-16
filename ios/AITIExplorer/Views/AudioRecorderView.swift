import SwiftUI

struct AudioRecorderView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Audio Recorder")
                .font(.title2)
                .bold()

            Button {
                // Audio recording functionality has been removed intentionally.
            } label: {
                Label("Start Recording", systemImage: "mic.circle")
                    .font(.title3)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor.opacity(0.8))
                    .foregroundStyle(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    AudioRecorderView()
}
