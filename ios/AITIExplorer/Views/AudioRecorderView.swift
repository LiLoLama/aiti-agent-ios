import SwiftUI

struct AudioRecorderView: View {
    @StateObject private var viewModel = AudioViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Text("Audio Recorder")
                .font(.title2)
                .bold()

            VStack(spacing: 16) {
                Text(viewModel.formattedRecordingDuration)
                    .font(.system(size: 32, weight: .medium, design: .monospaced))
                    .accessibilityLabel("Aufnahmedauer \(viewModel.formattedRecordingDuration)")

                WaveformView(level: CGFloat(viewModel.waveformLevel))
                    .frame(height: 80)
                    .animation(.easeOut(duration: 0.1), value: viewModel.waveformLevel)

                HStack(spacing: 16) {
                    Button {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            viewModel.startRecording()
                        }
                    } label: {
                        Label(viewModel.isRecording ? "Stop" : "Record", systemImage: viewModel.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title3)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(viewModel.isRecording ? Color.red.opacity(0.85) : Color.accentColor.opacity(0.85))
                            .foregroundStyle(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isPlaying)

                    Button {
                        viewModel.stopRecording()
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                            .font(.title3)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.isRecording)
                }

                HStack(spacing: 16) {
                    Button {
                        if viewModel.isPlaying {
                            viewModel.pause()
                        } else {
                            viewModel.play(url: viewModel.recordedURL)
                        }
                    } label: {
                        Label(viewModel.isPlaying ? "Pause" : "Play", systemImage: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title3)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor.opacity(viewModel.isPlaying ? 0.8 : 0.7))
                            .foregroundStyle(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.recordedURL == nil)

                    Button {
                        viewModel.stopPlayback()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.title3)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                Capsule()
                                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.isPlaying)
                }

                if viewModel.isPlaying {
                    ProgressView(value: viewModel.playbackProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                }

                if let recordedURL = viewModel.recordedURL {
                    VStack(spacing: 4) {
                        Text("Letzte Aufnahme")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(recordedURL.lastPathComponent)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }

                if let errorMessage = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)

                        if viewModel.shouldShowSettingsLink {
                            Button("Einstellungen öffnen") {
                                viewModel.openSettings()
                            }
                            .font(.footnote)
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Spacer()
        }
        .padding()
    }
}

private struct WaveformView: View {
    let level: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let clampedLevel = min(max(level, 0), 1)
            let barCount = Int(max(proxy.size.width / 6, 1))
            let normalized = max(clampedLevel, 0.05)
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    let progress = CGFloat(index) / CGFloat(max(barCount - 1, 1))
                    let heightMultiplier = sin(progress * .pi) * normalized
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(height: max(proxy.size.height * heightMultiplier, 4))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
    }
}

#Preview {
    AudioRecorderView()
}
