import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
#if canImport(AVFAudio)
import AVFAudio
#endif

struct ChatDetailView: View {
    let agent: AgentProfile
    @Binding var draftedMessage: String
    var onSend: (String, [ChatAttachment]) -> Void
    var pendingResponse: Bool

    @Namespace private var bottomID
    @FocusState private var isComposerFocused: Bool
    @State private var attachments: [ChatAttachment] = []
    @State private var showingFileImporter = false
    @State private var showingAudioRecorder = false
    @State private var attachmentError: String?

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(agent: agent)

            Divider()
                .background(.white.opacity(0.1))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(agent.conversation.messages) { message in
                            ChatBubble(message: message, agent: agent)
                                .padding(.horizontal)
                        }

                        if pendingResponse {
                            TypingIndicatorView()
                                .padding(.horizontal)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .padding(.vertical, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissFocusOnInteract($isComposerFocused)
                .background(Color(.systemBackground))
                .onChange(of: agent.conversation.messages.count) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
                .onChange(of: isComposerFocused) { _, focused in
                    guard focused else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                MessageComposer(
                    text: $draftedMessage,
                    attachments: $attachments,
                    onSend: { text, attachments in
                        onSend(text, attachments)
                        draftedMessage = ""
                        self.attachments.removeAll()
                    },
                    onRequestFileAttachment: {
                        showingFileImporter = true
                    },
                    onRequestAudioAttachment: {
                        showingAudioRecorder = true
                    },
                    isFocused: $isComposerFocused
                )
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .background(.thinMaterial)
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .sheet(isPresented: $showingAudioRecorder) {
            AudioRecorderSheet { attachment in
                attachments.append(attachment)
            }
        }
        .alert("Datei konnte nicht hinzugefügt werden", isPresented: Binding(
            get: { attachmentError != nil },
            set: { newValue in if !newValue { attachmentError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(attachmentError ?? "")
        }
    }
}

private extension ChatDetailView {
    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await processImportedFile(from: url)
            }
        case .failure(let error):
            Task { @MainActor in
                attachmentError = error.localizedDescription
            }
        }
    }

    func processImportedFile(from originalURL: URL) async {
        let didAccess = originalURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                originalURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let tempDirectory = FileManager.default.temporaryDirectory
            let destinationURL = tempDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(originalURL.pathExtension)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: originalURL, to: destinationURL)

            let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
            let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0

            let resourceValues = try destinationURL.resourceValues(forKeys: [.contentTypeKey])
            let resolvedType = resourceValues.contentType ?? UTType(filenameExtension: destinationURL.pathExtension)
            let typeDescription = resolvedType?.preferredMIMEType ?? resolvedType?.identifier ?? "public.data"
            let isAudioFile = resolvedType?.conforms(to: .audio) ?? false

            var durationSeconds: Int?
            if isAudioFile {
                let asset = AVURLAsset(url: destinationURL)
                let duration = try await asset.load(.duration)
                let seconds = Int(round(CMTimeGetSeconds(duration)))
                durationSeconds = seconds > 0 ? seconds : nil
            }

            let attachment = ChatAttachment(
                name: originalURL.lastPathComponent,
                size: fileSize,
                type: typeDescription,
                url: destinationURL,
                kind: isAudioFile ? .audio : .file,
                durationSeconds: durationSeconds
            )

            await MainActor.run {
                attachments.append(attachment)
            }
        } catch {
            await MainActor.run {
                attachmentError = error.localizedDescription
            }
        }
    }
}

private struct ChatHeaderView: View {
    let agent: AgentProfile

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .frame(width: 72, height: 72)
                Image(systemName: agent.avatarSystemName)
                    .font(.largeTitle)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(agent.name)
                    .font(.title3.bold())
                Text(agent.role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(agent.status.description, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.green)
                AgentToolBadges(tools: agent.tools)
            }

            Spacer()
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 12)
    }
}

private struct AgentToolBadges: View {
    let tools: [AgentTool]

    var body: some View {
        if tools.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tools) { tool in
                        Label(tool.title, systemImage: tool.iconName)
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.accentColor.opacity(0.2))
                            )
                    }
                }
            }
            .padding(.top, 6)
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let agent: AgentProfile

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.author == .agent {
                avatar
            } else {
                Spacer(minLength: 48)
            }

            VStack(alignment: message.author == .agent ? .leading : .trailing, spacing: 10) {
                if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message.content)
                        .padding(16)
                        .foregroundStyle(message.author == .agent ? .primary : Color.white)
                        .background(bubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                if !message.attachments.isEmpty {
                    AttachmentList(attachments: message.attachments)
                }

                Text(message.timeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if message.author == .user {
                avatar
            } else {
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.author == .agent ? .leading : .trailing)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
            Image(systemName: message.author == .agent ? agent.avatarSystemName : "person.fill")
                .font(.subheadline)
        }
    }

    private var bubbleBackground: some ShapeStyle {
        if message.author == .agent {
            return AnyShapeStyle(.thinMaterial)
        } else {
            return AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

private struct AttachmentList: View {
    let attachments: [ChatAttachment]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(attachments) { attachment in
                HStack {
                    Image(systemName: attachment.kind.iconName)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(attachment.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text("\(attachment.formattedSize) • \(attachment.type)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let duration = attachment.durationSeconds {
                        Text("\(duration) s")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

private struct TypingIndicatorView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.thinMaterial)
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "bolt.horizontal.fill").font(.subheadline))

            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animate ? 1.0 : 0.4)
                        .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.12), value: animate)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { animate = true }
    }
}

private struct MessageComposer: View {
    @Binding var text: String
    @Binding var attachments: [ChatAttachment]
    var onSend: (String, [ChatAttachment]) -> Void
    var onRequestFileAttachment: () -> Void
    var onRequestAudioAttachment: () -> Void
    var isFocused: FocusState<Bool>.Binding

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { attachment in
                            AttachmentComposerChip(attachment: attachment) {
                                attachments.removeAll { $0.id == attachment.id }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button(action: onRequestFileAttachment) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
                .accessibilityLabel("Datei hinzufügen")

                TextField("Nachricht schreiben …", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                    .focused(isFocused)

                Button(action: onRequestAudioAttachment) {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .padding(12)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
                .accessibilityLabel("Audio hinzufügen")

                Button {
                    let message = trimmedText
                    guard !message.isEmpty || !attachments.isEmpty else { return }
                    onSend(message, attachments)
                    text = ""
                    isFocused.wrappedValue = false
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3.bold())
                        .foregroundStyle(Color.white)
                        .padding(12)
                        .background(Circle().fill(Color.accentColor))
                }
                .disabled(trimmedText.isEmpty && attachments.isEmpty)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused.wrappedValue)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    isFocused.wrappedValue = false
                }
            }
        }
    }
}

private struct AudioRecorderSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onComplete: (ChatAttachment) -> Void

    @State private var permissionStatus: MicrophonePermissionStatus = .undetermined
    @State private var isRecording = false
    @State private var recorder: AVAudioRecorder?
    @State private var recordedURL: URL?
    @State private var recordingFileName: String = ""
    @State private var recordedDuration: TimeInterval = 0
    @State private var startDate: Date?
    @State private var timer: Timer?
    @State private var errorMessage: String?
    @State private var didFinishSuccessfully = false

    private enum MicrophonePermissionStatus {
        case undetermined
        case denied
        case granted
    }

    private var formattedDuration: String {
        let totalSeconds = max(0, Int(recordedDuration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var canAddRecording: Bool {
        recordedURL != nil && !isRecording
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                Text("Sprachaufnahme")
                    .font(.headline)

                if permissionStatus == .denied {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.orange)
                        Text("Bitte erlaube den Mikrofonzugriff in den Systemeinstellungen, um Sprachaufnahmen zu erstellen.")
                            .multilineTextAlignment(.center)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 16) {
                        Text(formattedDuration)
                            .font(.system(size: 44, weight: .semibold, design: .monospaced))

                        if !recordingFileName.isEmpty && !isRecording {
                            Text(recordingFileName)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            if isRecording {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(isRecording ? Color.red : Color.accentColor)
                                    .frame(width: 76, height: 76)
                                    .shadow(color: (isRecording ? Color.red : Color.accentColor).opacity(0.35), radius: 12)
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.title)
                                    .foregroundStyle(Color.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isRecording ? "Aufnahme beenden" : "Aufnahme starten")

                        Text(isRecording ? "Tippe erneut, um die Aufnahme zu beenden." : "Tippe, um eine neue Sprachaufnahme zu starten.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                Spacer()

                HStack {
                    Button("Abbrechen", role: .cancel) {
                        cancelRecording()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Hinzufügen") {
                        finishRecording()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddRecording)
                }
                .padding(.bottom, 8)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isRecording)
        .onAppear {
            prepareSession()
        }
        .onDisappear {
            cleanup(deleteFile: !didFinishSuccessfully)
        }
        .alert("Aufnahme fehlgeschlagen", isPresented: Binding(
            get: { errorMessage != nil },
            set: { newValue in if !newValue { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unbekannter Fehler")
        }
    }

    private func prepareSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        } catch {
            errorMessage = error.localizedDescription
        }

        #if canImport(AVFAudio)
        if #available(iOS 17, *) {
            updatePermissionUsingApplication()
        } else {
            updatePermission(using: session)
        }
        #else
        updatePermission(using: session)
        #endif
    }

    #if canImport(AVFAudio)
    @available(iOS 17, *)
    private func updatePermissionUsingApplication() {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            permissionStatus = .undetermined
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    permissionStatus = granted ? .granted : .denied
                }
            }
        case .granted:
            permissionStatus = .granted
        case .denied:
            permissionStatus = .denied
        @unknown default:
            permissionStatus = .denied
        }
    }
    #endif

    private func updatePermission(using session: AVAudioSession) {
        let permission = session.recordPermission
        switch permission {
        case .undetermined:
            permissionStatus = .undetermined
            session.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    permissionStatus = granted ? .granted : .denied
                }
            }
        case .granted:
            permissionStatus = .granted
        case .denied:
            permissionStatus = .denied
        @unknown default:
            permissionStatus = .denied
        }
    }

    private func startRecording() {
        guard permissionStatus == .granted else { return }
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setActive(true, options: [])

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let baseName = "Sprachmemo-\(formatter.string(from: Date()))"
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(baseName)
                .appendingPathExtension("m4a")

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder?.prepareToRecord()
            recorder?.record()

            recordedURL = fileURL
            recordingFileName = fileURL.lastPathComponent
            recordedDuration = 0
            isRecording = true
            startDate = Date()
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
            cleanup(deleteFile: true)
        }
    }

    private func stopRecording() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        stopTimer()
        if let startDate {
            recordedDuration = Date().timeIntervalSince(startDate)
        }
        startDate = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            // Ignored – the session can remain active if deactivation fails
        }
    }

    private func cancelRecording() {
        cleanup(deleteFile: true)
        dismiss()
    }

    private func finishRecording() {
        if isRecording {
            stopRecording()
        }

        guard let url = recordedURL else { return }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0
            let seconds = max(1, Int(round(recordedDuration)))

            let attachment = ChatAttachment(
                name: recordingFileName.isEmpty ? url.lastPathComponent : recordingFileName,
                size: fileSize,
                type: "audio/m4a",
                url: url,
                kind: .audio,
                durationSeconds: seconds
            )

            didFinishSuccessfully = true
            onComplete(attachment)
            cleanup(deleteFile: false)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            if let startDate {
                recordedDuration = Date().timeIntervalSince(startDate)
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func cleanup(deleteFile: Bool) {
        if isRecording {
            recorder?.stop()
        }
        recorder = nil
        isRecording = false
        stopTimer()
        startDate = nil

        if deleteFile, let url = recordedURL {
            try? FileManager.default.removeItem(at: url)
        }

        recordedURL = nil
        recordingFileName = ""
        recordedDuration = 0
    }
}

private struct AttachmentComposerChip: View {
    let attachment: ChatAttachment
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.kind.iconName)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text(attachment.formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

#Preview {
    ChatDetailView(
        agent: SampleData.previewUser.agents.first!,
        draftedMessage: .constant(""),
        onSend: { _, _ in },
        pendingResponse: true
    )
}
