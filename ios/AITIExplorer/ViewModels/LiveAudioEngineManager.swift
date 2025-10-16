import Foundation
import AVFoundation

@MainActor
final class LiveAudioEngineManager: ObservableObject {
    enum EngineError: LocalizedError {
        case microphonePermissionDenied
        case engineFailure(Error)
        case sessionConfigurationFailed(Error)

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "Microphone permission is required for live audio."
            case .engineFailure(let error):
                return "The audio engine failed with error: \(error.localizedDescription)"
            case .sessionConfigurationFailed(let error):
                return "Unable to configure the audio session: \(error.localizedDescription)"
            }
        }
    }

    @Published private(set) var isRunning = false
    @Published private(set) var averagePower: Float = .zero
    @Published var activeError: EngineError?

    private let audioSession = AVAudioSession.sharedInstance()
    private let engine = AVAudioEngine()

    func start() async {
        do {
            try await ensureMicrophonePermission()
            try configureSession()
            try startEngine()
            isRunning = true
            activeError = nil
        } catch let error as EngineError {
            activeError = error
        } catch {
            activeError = .engineFailure(error)
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        averagePower = .zero

        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Swallow errors when deactivating.
        }
    }

    private func ensureMicrophonePermission() async throws {
        switch audioSession.recordPermission {
        case .granted:
            return
        case .denied:
            throw EngineError.microphonePermissionDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { continuation.resume(returning: $0) }
            }
            if !granted {
                throw EngineError.microphonePermissionDenied
            }
        @unknown default:
            throw EngineError.microphonePermissionDenied
        }
    }

    private func configureSession() throws {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try audioSession.setActive(true)
        } catch {
            throw EngineError.sessionConfigurationFailed(error)
        }
    }

    private func startEngine() throws {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            guard let channelData = buffer.floatChannelData?.pointee else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }

            let samples = UnsafeBufferPointer(start: channelData, count: frameCount)
            let sumOfSquares = samples.reduce(into: Float.zero) { partialResult, value in
                partialResult += value * value
            }
            let rms = sqrt(sumOfSquares / Float(frameCount))

            Task { @MainActor in
                self.averagePower = rms
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw EngineError.engineFailure(error)
        }
    }
}
