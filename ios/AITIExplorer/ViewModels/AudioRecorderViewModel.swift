import Foundation
import AVFoundation

@MainActor
final class AudioRecorderViewModel: NSObject, ObservableObject {
    enum RecorderError: LocalizedError {
        case microphonePermissionDenied
        case recorderUnavailable
        case failedToConfigureSession(Error)
        case failedToStart(Error)

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "Microphone access has been denied. Please enable it in Settings."
            case .recorderUnavailable:
                return "Unable to create the audio recorder."
            case .failedToConfigureSession(let error):
                return "Failed to configure the audio session: \(error.localizedDescription)"
            case .failedToStart(let error):
                return "Recording could not be started: \(error.localizedDescription)"
            }
        }
    }

    @Published private(set) var isRecording = false
    @Published private(set) var recordingURL: URL?
    @Published var activeError: RecorderError?

    private let audioSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder?

    deinit {
        audioRecorder?.stop()
    }

    func toggleRecording() async {
        if isRecording {
            stopRecording()
        } else {
            do {
                try await startRecording()
            } catch let error as RecorderError {
                activeError = error
            } catch {
                activeError = .failedToStart(error)
            }
        }
    }

    func startRecording() async throws {
        try await ensureMicrophonePermission()
        try configureSession()

        if let existingURL = recordingURL {
            try? FileManager.default.removeItem(at: existingURL)
        }

        let fileURL = makeRecordingURL()
        let recorder = try makeRecorder(for: fileURL)
        audioRecorder = recorder
        recorder.record()

        recordingURL = fileURL
        isRecording = true
        activeError = nil
    }

    func stopRecording() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recorder.stop()
        audioRecorder = nil
        isRecording = false

        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Not fatal for stopping the recording; log if needed.
        }
    }

    private func ensureMicrophonePermission() async throws {
        if #available(iOS 17, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return
            case .denied:
                throw RecorderError.microphonePermissionDenied
            case .undetermined:
                let granted = await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { isGranted in
                        continuation.resume(returning: isGranted)
                    }
                }
                if !granted {
                    throw RecorderError.microphonePermissionDenied
                }
            @unknown default:
                throw RecorderError.microphonePermissionDenied
            }
        } else {
            switch audioSession.recordPermission {
            case .granted:
                return
            case .denied:
                throw RecorderError.microphonePermissionDenied
            case .undetermined:
                let granted = await withCheckedContinuation { continuation in
                    audioSession.requestRecordPermission { isGranted in
                        continuation.resume(returning: isGranted)
                    }
                }
                if !granted {
                    throw RecorderError.microphonePermissionDenied
                }
            @unknown default:
                throw RecorderError.microphonePermissionDenied
            }
        }
    }

    private func configureSession() throws {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try audioSession.setActive(true)
        } catch {
            throw RecorderError.failedToConfigureSession(error)
        }
    }

    private func makeRecorder(for url: URL) throws -> AVAudioRecorder {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            recorder.prepareToRecord()
            return recorder
        } catch {
            throw RecorderError.failedToStart(error)
        }
    }

    private func makeRecordingURL() -> URL {
        let filename = UUID().uuidString + ".m4a"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}

extension AudioRecorderViewModel: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                activeError = .recorderUnavailable
                recordingURL = nil
            } else {
                recordingURL = recorder.url
            }
            isRecording = false
            audioRecorder = nil
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                // Swallow errors when deactivating the session.
            }
        }
    }
}
