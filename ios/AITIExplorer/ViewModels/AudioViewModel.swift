import AVFoundation
import Foundation
import UIKit

enum RecorderError: LocalizedError {
    case permissionDenied
    case sessionConfigurationFailed(underlying: Error?)
    case recorderSetupFailed(underlying: Error?)
    case recordingFailed
    case playerSetupFailed(underlying: Error?)
    case filePersistenceFailed(underlying: Error?)
    case maximumDurationReached

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Mikrofonzugriff verweigert. Bitte erlaube den Zugriff in den Einstellungen."
        case .sessionConfigurationFailed:
            return "Die Audio-Sitzung konnte nicht vorbereitet werden. Bitte versuche es erneut."
        case .recorderSetupFailed:
            return "Der Recorder konnte nicht gestartet werden."
        case .recordingFailed:
            return "Die Aufnahme ist fehlgeschlagen."
        case .playerSetupFailed:
            return "Die Aufnahme konnte nicht wiedergegeben werden."
        case .filePersistenceFailed:
            return "Die Aufnahmedatei konnte nicht gespeichert werden."
        case .maximumDurationReached:
            return "Die maximale Aufnahmedauer von 3 Minuten wurde erreicht."
        }
    }
}

@MainActor
final class AudioViewModel: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordedURL: URL?
    @Published var errorMessage: String?
    @Published var recordingDuration: TimeInterval = 0
    @Published var waveformLevel: Float = 0
    @Published var shouldShowSettingsLink = false
    @Published var playbackProgress: Double = 0

    private let audioSession = AVAudioSession.sharedInstance()
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var playbackTimer: Timer?
    private var activeRecordingURL: URL?
    private let maxDuration: TimeInterval = 180
    private let fileManager = FileManager.default
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var wasPlayingBeforeInterruption = false

    override init() {
        super.init()
        cleanupTemporaryFiles()
        observeAudioSessionNotifications()
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
        recordingTimer?.invalidate()
        playbackTimer?.invalidate()
    }

    func startRecording() {
        guard !isRecording else { return }
        stopPlayback()

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.beginRecording()
        }
    }

    @discardableResult
    func stopRecording() -> URL? {
        guard isRecording else { return recordedURL }

        let currentTime = recorder?.currentTime ?? recordingDuration
        recorder?.stop()
        recorder = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        waveformLevel = 0
        recordingDuration = currentTime
        isRecording = false
        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignore errors when deactivating the session.
        }

        if let activeRecordingURL {
            recordedURL = activeRecordingURL
        }
        activeRecordingURL = nil

        return recordedURL
    }

    func play(url: URL?) {
        guard let url else { return }
        guard !isRecording else {
            _ = stopRecording()
            return
        }

        if recordedURL != url {
            recordedURL = url
        }

        if let player, !isPlaying, player.url == url {
            player.play()
            isPlaying = true
            errorMessage = nil
            startPlaybackTimer()
            return
        }

        if isPlaying {
            stopPlayback()
        }

        do {
            try audioSession.setActive(true, options: [])
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
            playbackProgress = 0
            errorMessage = nil
            startPlaybackTimer()
        } catch {
            handleError(.playerSetupFailed(underlying: error))
        }
    }

    func pause() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
        stopPlaybackTimer()
    }

    func stopPlayback() {
        guard player != nil else { return }
        player?.stop()
        player = nil
        isPlaying = false
        playbackProgress = 0
        stopPlaybackTimer()
        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignore cleanup errors.
        }
    }

    func persistRecording(to destinationURL: URL) throws {
        guard let sourceURL = recordedURL else {
            throw RecorderError.filePersistenceFailed(underlying: nil)
        }

        let directory = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            recordedURL = destinationURL
        } catch {
            throw RecorderError.filePersistenceFailed(underlying: error)
        }
    }

    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
    }

    var formattedRecordingDuration: String {
        let duration = max(recordingDuration, 0)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func beginRecording() async {
        do {
            try await ensurePermission()
            try configureAudioSession()
            let url = try prepareRecorder()
            recorder?.record()
            isRecording = true
            shouldShowSettingsLink = false
            errorMessage = nil
            activeRecordingURL = url
            recordedURL = nil
            recordingDuration = 0
            startRecordingTimer()
        } catch let error as RecorderError {
            handleError(error)
        } catch {
            handleError(.recorderSetupFailed(underlying: error))
        }
    }

    private func ensurePermission() async throws {
        switch currentRecordPermission() {
        case .granted:
            return
        case .denied:
            throw RecorderError.permissionDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
            guard granted else {
                throw RecorderError.permissionDenied
            }
        @unknown default:
            throw RecorderError.permissionDenied
        }
    }

    private func configureAudioSession() throws {
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true, options: [])
        } catch {
            throw RecorderError.sessionConfigurationFailed(underlying: error)
        }
    }

    private func prepareRecorder() throws -> URL {
        let fileName = "aiti-recording-\(UUID().uuidString).m4a"
        let url = fileManager.temporaryDirectory.appendingPathComponent(fileName)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()
        } catch {
            throw RecorderError.recorderSetupFailed(underlying: error)
        }

        return url
    }

    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let recorder = self.recorder else { return }
                recorder.updateMeters()
                let power = recorder.averagePower(forChannel: 0)
                self.waveformLevel = self.normalizedPower(power)
                self.recordingDuration = recorder.currentTime

                if recorder.currentTime >= self.maxDuration {
                    _ = self.stopRecording()
                    self.handleError(.maximumDurationReached)
                }
            }
        }
        if let recordingTimer {
            RunLoop.main.add(recordingTimer, forMode: .common)
        }
    }

    private func startPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.playbackProgress = player.duration > 0 ? player.currentTime / player.duration : 0
            }
        }
        if let playbackTimer {
            RunLoop.main.add(playbackTimer, forMode: .common)
        }
    }

    private func stopPlaybackTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func observeAudioSessionNotifications() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleInterruption(notification: notification)
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleRouteChange(notification: notification)
            }
        }
    }

    private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            if isRecording {
                _ = stopRecording()
                handleError(.recordingFailed)
            }
            if isPlaying {
                pause()
            }
        case .ended:
            do {
                try audioSession.setActive(true, options: [])
            } catch {
                handleError(.sessionConfigurationFailed(underlying: error))
            }
            if wasPlayingBeforeInterruption,
               let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    player?.play()
                    isPlaying = true
                    startPlaybackTimer()
                }
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        let route = audioSession.currentRoute

        switch reason {
        case .oldDeviceUnavailable, .noSuitableRouteForCategory:
            if isRecording {
                _ = stopRecording()
            }
            if isPlaying {
                stopPlayback()
            }
        case .categoryChange, .override:
            if route.inputs.isEmpty, isRecording {
                _ = stopRecording()
            }
            if route.outputs.isEmpty, isPlaying {
                stopPlayback()
            }
        default:
            break
        }
    }

    private func handleError(_ error: RecorderError) {
        errorMessage = error.errorDescription
        if case .permissionDenied = error {
            shouldShowSettingsLink = true
        } else {
            shouldShowSettingsLink = false
        }
    }

    private func normalizedPower(_ decibels: Float) -> Float {
        let level = max(0.000_000_01, powf(10, decibels / 20))
        return min(max(level, 0), 1)
    }

    private func currentRecordPermission() -> AVAudioSession.RecordPermission {
        if #available(iOS 17, *) {
            switch AVAudioApplication.shared.recordPermission {
            case AVAudioApplication.recordPermission.undetermined:
                return .undetermined
            case AVAudioApplication.recordPermission.denied:
                return .denied
            case AVAudioApplication.recordPermission.granted:
                return .granted
            @unknown default:
                return .undetermined
            }
        } else {
            return audioSession.recordPermission
        }
    }

    private func requestRecordPermission(_ handler: @escaping (Bool) -> Void) {
        if #available(iOS 17, *) {
            AVAudioApplication.requestRecordPermission { allowed in
                handler(allowed)
            }
        } else {
            audioSession.requestRecordPermission { allowed in
                handler(allowed)
            }
        }
    }

    private func cleanupTemporaryFiles() {
        let tempDirectory = fileManager.temporaryDirectory
        let expirationDate = Date().addingTimeInterval(-3 * 24 * 60 * 60)

        guard let enumerator = fileManager.enumerator(at: tempDirectory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]) else {
            return
        }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "m4a" else { continue }
            let resourceValues = try? fileURL.resourceValues(forKeys: [.creationDateKey])
            if let creationDate = resourceValues?.creationDate, creationDate < expirationDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}

extension AudioViewModel: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                self.handleError(.recorderSetupFailed(underlying: error))
            } else {
                self.handleError(.recordingFailed)
            }
            _ = self.stopRecording()
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            self.waveformLevel = 0
            if flag {
                if let activeRecordingURL = self.activeRecordingURL {
                    self.recordedURL = activeRecordingURL
                }
                self.activeRecordingURL = nil
            } else {
                self.handleError(.recordingFailed)
            }
            self.isRecording = false
        }
    }
}

extension AudioViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.stopPlaybackTimer()
            self.playbackProgress = 1
            self.isPlaying = false
            if !flag {
                self.handleError(.playerSetupFailed(underlying: nil))
            }
            do {
                try self.audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                // Ignore cleanup errors.
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.stopPlayback()
            if let error {
                self.handleError(.playerSetupFailed(underlying: error))
            } else {
                self.handleError(.playerSetupFailed(underlying: nil))
            }
        }
    }
}
