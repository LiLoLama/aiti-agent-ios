import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import UIKit
import PhotosUI

struct ChatDetailView: View {
    let agent: AgentProfile
    let userAvatarImageData: Data?
    let userAvatarSystemName: String
    @Binding var draftedMessage: String
    var onSend: (String, [ChatAttachment]) -> Void
    var pendingResponse: Bool

    @Namespace private var bottomID
    @FocusState private var isComposerFocused: Bool
    @StateObject private var audioRecorderViewModel = AudioViewModel()
    @State private var attachments: [ChatAttachment] = []
    @State private var showingFileImporter = false
    @State private var showingAttachmentSourceDialog = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoPickerItem: PhotosPickerItem?
    @State private var attachmentError: String?
    @State private var activeAudioAttachmentID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        ForEach(agent.conversation.messages) { message in
                            ChatBubble(
                                message: message,
                                agent: agent,
                                userAvatarImageData: userAvatarImageData,
                                userAvatarSystemName: userAvatarSystemName
                            )
                                .padding(.horizontal, 20)
                                .padding(.top, message.author == .agent ? 0 : 6)
                        }

                        if pendingResponse {
                            TypingIndicatorView()
                                .padding(.horizontal, 20)
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomID)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .scrollDismissesKeyboard(.interactively)
                .dismissFocusOnInteract($isComposerFocused)
                .onChange(of: agent.conversation.messages.count) {
                    withAnimation(.easeInOut(duration: 0.32)) {
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
                    audioViewModel: audioRecorderViewModel,
                    activeAudioAttachmentID: activeAudioAttachmentID,
                    onSend: { text, attachments in
                        onSend(text, attachments)
                        draftedMessage = ""
                        self.attachments.removeAll()
                        resetInlineAudioStateAfterSend()
                    },
                    onRequestFileAttachment: { showingAttachmentSourceDialog = true },
                    onAudioButtonTapped: handleAudioButtonTapped,
                    onAudioPlaybackTapped: toggleAudioPlayback,
                    onRemoveAttachment: removeAttachment(_:),
                    onRemoveAudio: removeInlineAudioAttachment,
                    isFocused: $isComposerFocused
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .background(.ultraThinMaterial)
        }
        .explorerBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ChatNavigationTitleView(agent: agent)
            }
        }
        .confirmationDialog(
            "Anhang hinzufügen",
            isPresented: $showingAttachmentSourceDialog,
            titleVisibility: .visible
        ) {
            Button("Foto-Mediathek") {
                showingPhotoPicker = true
            }
            Button("Dateien") {
                showingFileImporter = true
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoPickerItem,
            matching: .images
        )
        .onChange(of: selectedPhotoPickerItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                await handlePhotoSelection(item)
                await MainActor.run {
                    selectedPhotoPickerItem = nil
                    showingPhotoPicker = false
                }
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

    func handlePhotoSelection(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                let contentType = item.supportedContentTypes.first
                let fileExtension = contentType?.preferredFilenameExtension ?? "dat"
                let fileName = "Foto.\(fileExtension)"
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(fileExtension)

                try data.write(to: tempURL, options: .atomic)

                let typeDescription = contentType?.preferredMIMEType ?? contentType?.identifier ?? "public.image"

                let attachment = ChatAttachment(
                    name: fileName,
                    size: data.count,
                    type: typeDescription,
                    url: tempURL,
                    kind: .file
                )

                await MainActor.run {
                    attachments.append(attachment)
                }
            } else {
                await MainActor.run {
                    attachmentError = "Das Foto konnte nicht geladen werden."
                }
            }
        } catch {
            await MainActor.run {
                attachmentError = error.localizedDescription
            }
        }
    }

    func appendRecordedAudio(from url: URL) async -> ChatAttachment? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.intValue ?? 0

            let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey])
            let contentType = resourceValues.contentType ?? UTType(filenameExtension: url.pathExtension)
            let typeDescription = contentType?.preferredMIMEType ?? contentType?.identifier ?? "public.audio"

            let asset = AVURLAsset(url: url)
            let durationTime = try await asset.load(.duration)
            let secondsValue = Int(round(CMTimeGetSeconds(durationTime)))
            let durationSeconds = secondsValue > 0 ? secondsValue : nil

            let attachment = ChatAttachment(
                name: url.lastPathComponent,
                size: fileSize,
                type: typeDescription,
                url: url,
                kind: .audio,
                durationSeconds: durationSeconds
            )

            return await MainActor.run {
                attachments.append(attachment)
                return attachment
            }
        } catch {
            await MainActor.run {
                attachmentError = error.localizedDescription
            }
            return nil
        }
    }

    func handleAudioButtonTapped() {
        if audioRecorderViewModel.isRecording {
            guard let url = audioRecorderViewModel.stopRecording() else {
                return
            }

            Task {
                if let attachment = await appendRecordedAudio(from: url) {
                    await MainActor.run {
                        activeAudioAttachmentID = attachment.id
                    }
                } else {
                    await MainActor.run {
                        removeInlineAudioAttachment()
                    }
                }
            }
        } else {
            startInlineRecording()
        }
    }

    func startInlineRecording() {
        if let activeID = activeAudioAttachmentID,
           let attachment = attachments.first(where: { $0.id == activeID }) {
            removeAttachment(attachment)
        }

        audioRecorderViewModel.stopPlayback()
        audioRecorderViewModel.errorMessage = nil
        audioRecorderViewModel.shouldShowSettingsLink = false
        if activeAudioAttachmentID == nil, let existingURL = audioRecorderViewModel.recordedURL {
            try? FileManager.default.removeItem(at: existingURL)
        }
        audioRecorderViewModel.recordedURL = nil
        audioRecorderViewModel.recordingDuration = 0
        audioRecorderViewModel.waveformLevel = 0
        activeAudioAttachmentID = nil
        audioRecorderViewModel.startRecording()
    }

    func toggleAudioPlayback() {
        if audioRecorderViewModel.isPlaying {
            audioRecorderViewModel.pause()
        } else {
            audioRecorderViewModel.play(url: audioRecorderViewModel.recordedURL)
        }
    }

    func removeAttachment(_ attachment: ChatAttachment) {
        attachments.removeAll { $0.id == attachment.id }

        guard attachment.id == activeAudioAttachmentID else { return }

        audioRecorderViewModel.stopPlayback()
        if let url = attachment.url {
            try? FileManager.default.removeItem(at: url)
        }
        audioRecorderViewModel.recordedURL = nil
        audioRecorderViewModel.recordingDuration = 0
        audioRecorderViewModel.waveformLevel = 0
        audioRecorderViewModel.errorMessage = nil
        audioRecorderViewModel.shouldShowSettingsLink = false
        activeAudioAttachmentID = nil
    }

    func removeInlineAudioAttachment() {
        guard let activeID = activeAudioAttachmentID else {
            audioRecorderViewModel.stopPlayback()
            audioRecorderViewModel.recordedURL = nil
            audioRecorderViewModel.recordingDuration = 0
            audioRecorderViewModel.waveformLevel = 0
            return
        }

        if let attachment = attachments.first(where: { $0.id == activeID }) {
            removeAttachment(attachment)
        } else {
            audioRecorderViewModel.stopPlayback()
            if let url = audioRecorderViewModel.recordedURL {
                try? FileManager.default.removeItem(at: url)
            }
            audioRecorderViewModel.recordedURL = nil
            audioRecorderViewModel.recordingDuration = 0
            audioRecorderViewModel.waveformLevel = 0
            audioRecorderViewModel.errorMessage = nil
            audioRecorderViewModel.shouldShowSettingsLink = false
            activeAudioAttachmentID = nil
        }
    }

    func resetInlineAudioStateAfterSend() {
        activeAudioAttachmentID = nil
        audioRecorderViewModel.stopPlayback()
        audioRecorderViewModel.recordedURL = nil
        audioRecorderViewModel.recordingDuration = 0
        audioRecorderViewModel.waveformLevel = 0
        audioRecorderViewModel.errorMessage = nil
        audioRecorderViewModel.shouldShowSettingsLink = false
    }
}

private struct ChatNavigationTitleView: View {
    let agent: AgentProfile

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ExplorerTheme.surfaceElevated.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(ExplorerTheme.goldHighlightStart.opacity(0.3), lineWidth: 1)
                    )

                avatar
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.explorer(.headline, weight: .semibold))
                    .foregroundStyle(ExplorerTheme.textPrimary)

                Label(agent.status.description, systemImage: "circle.fill")
                    .font(.explorer(.caption2, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(ExplorerTheme.success)
            }
        }
    }
}

private extension ChatNavigationTitleView {
    var avatar: some View {
        Group {
            if let data = agent.avatarImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: agent.avatarSystemName)
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .foregroundStyle(ExplorerTheme.goldGradient)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let agent: AgentProfile
    let userAvatarImageData: Data?
    let userAvatarSystemName: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            if message.author == .agent {
                avatar
            } else {
                Spacer(minLength: 48)
            }

            VStack(alignment: message.author == .agent ? .leading : .trailing, spacing: 12) {
                if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(message.content)
                        .font(.explorer(.body))
                        .foregroundStyle(message.author == .agent ? ExplorerTheme.textPrimary : Color.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(bubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: bubbleShadow, radius: 14, x: 0, y: 10)
                }

                if !message.attachments.isEmpty {
                    AttachmentList(attachments: message.attachments)
                }

                Text(message.timeLabel)
                    .font(.explorer(.caption2))
                    .foregroundStyle(ExplorerTheme.textMuted)
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
                .fill(ExplorerTheme.surfaceElevated.opacity(0.95))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.25), lineWidth: 1)
                )
            avatarImage
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        }
    }

    private var avatarImage: some View {
        Group {
            if message.author == .agent {
                if let data = agent.avatarImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: agent.avatarSystemName)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .foregroundStyle(ExplorerTheme.goldGradient)
                }
            } else {
                if let data = userAvatarImageData,
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: userAvatarSystemName)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .foregroundStyle(ExplorerTheme.textPrimary)
                }
            }
        }
    }

    private var bubbleBackground: AnyShapeStyle {
        if message.author == .agent {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [ExplorerTheme.surface.opacity(0.92), ExplorerTheme.surfaceElevated.opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [ExplorerTheme.goldHighlightStart, ExplorerTheme.goldHighlightEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private var bubbleShadow: Color {
        message.author == .agent ? Color.black.opacity(0.28) : ExplorerTheme.goldHighlightEnd.opacity(0.32)
    }
}

private struct AttachmentList: View {
    let attachments: [ChatAttachment]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(attachments) { attachment in
                HStack(spacing: 12) {
                    Image(systemName: attachment.kind.iconName)
                        .foregroundStyle(ExplorerTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(attachment.name)
                            .font(.explorer(.footnote, weight: .medium))
                            .foregroundStyle(ExplorerTheme.textPrimary)
                            .lineLimit(1)
                        Text("\(attachment.formattedSize) • \(attachment.type)")
                            .font(.explorer(.caption2))
                            .foregroundStyle(ExplorerTheme.textMuted)
                            .lineLimit(1)
                    }

                    Spacer()

                    if let duration = attachment.durationSeconds {
                        Text("\(duration) s")
                            .font(.explorer(.caption2, weight: .semibold))
                            .foregroundStyle(ExplorerTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ExplorerTheme.surfaceElevated.opacity(0.85))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }
}

private struct TypingIndicatorView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(ExplorerTheme.surfaceElevated.opacity(0.9))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "bolt.horizontal.fill").font(.explorer(.caption, weight: .semibold)))

            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(ExplorerTheme.textSecondary)
                        .frame(width: 10, height: 10)
                        .scaleEffect(animate ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.12),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(ExplorerTheme.surface.opacity(0.92))
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ExplorerTheme.surface.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ExplorerTheme.goldHighlightStart.opacity(0.2), lineWidth: 1)
        )
        .onAppear { animate = true }
    }
}

private struct MessageComposer: View {
    @Binding var text: String
    @Binding var attachments: [ChatAttachment]
    @ObservedObject var audioViewModel: AudioViewModel
    var activeAudioAttachmentID: UUID?
    var onSend: (String, [ChatAttachment]) -> Void
    var onRequestFileAttachment: () -> Void
    var onAudioButtonTapped: () -> Void
    var onAudioPlaybackTapped: () -> Void
    var onRemoveAttachment: (ChatAttachment) -> Void
    var onRemoveAudio: () -> Void
    var isFocused: FocusState<Bool>.Binding

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var inlineAudioVisible: Bool {
        audioViewModel.isRecording || audioViewModel.recordedURL != nil
    }

    private var displayedAttachments: [ChatAttachment] {
        attachments.filter { $0.id != activeAudioAttachmentID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if inlineAudioVisible {
                InlineAudioRecorderBar(
                    isRecording: audioViewModel.isRecording,
                    durationText: audioViewModel.formattedRecordingDuration,
                    waveformLevel: CGFloat(audioViewModel.waveformLevel),
                    isPlaying: audioViewModel.isPlaying,
                    playbackProgress: audioViewModel.playbackProgress,
                    onPlayPause: onAudioPlaybackTapped,
                    onRemove: audioViewModel.isRecording ? nil : onRemoveAudio
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let errorMessage = audioViewModel.errorMessage {
                InlineAudioErrorView(
                    message: errorMessage,
                    showSettings: audioViewModel.shouldShowSettingsLink,
                    openSettings: audioViewModel.openSettings
                )
            }

            if !displayedAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(displayedAttachments) { attachment in
                            AttachmentComposerChip(attachment: attachment) {
                                onRemoveAttachment(attachment)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack(alignment: .center, spacing: 12) {
                Button(action: onRequestFileAttachment) {
                    circularAccessory(systemName: "paperclip")
                }
                .accessibilityLabel("Datei hinzufügen")

                TextField("Nachricht schreiben …", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(ExplorerTheme.surface.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(ExplorerTheme.goldHighlightStart.opacity(isFocused.wrappedValue ? 0.6 : 0.25), lineWidth: 1.1)
                    )
                    .font(.explorer(.callout))
                    .foregroundStyle(ExplorerTheme.textPrimary)
                    .focused(isFocused)

                Button(action: onAudioButtonTapped) {
                    Image(systemName: audioViewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(audioViewModel.isRecording ? AnyShapeStyle(Color.white) : AnyShapeStyle(ExplorerTheme.goldGradient))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(audioViewModel.isRecording ? Color.red.opacity(0.85) : ExplorerTheme.surfaceElevated.opacity(0.9))
                        )
                        .overlay(
                            Circle()
                                .stroke(audioViewModel.isRecording ? Color.red.opacity(0.7) : ExplorerTheme.goldHighlightStart.opacity(0.35), lineWidth: 1)
                        )
                        .animation(.easeInOut(duration: 0.2), value: audioViewModel.isRecording)
                }
                .accessibilityLabel(audioViewModel.isRecording ? "Aufnahme stoppen" : "Audio aufnehmen")

                Button {
                    let message = trimmedText
                    guard !message.isEmpty || !attachments.isEmpty else { return }
                    onSend(message, attachments)
                    text = ""
                    isFocused.wrappedValue = false
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(ExplorerTheme.goldGradient)
                        )
                        .shadow(color: ExplorerTheme.goldHighlightEnd.opacity(0.4), radius: 14, x: 0, y: 10)
                }
                .disabled(trimmedText.isEmpty && attachments.isEmpty)
                .opacity(trimmedText.isEmpty && attachments.isEmpty ? 0.55 : 1)
            }
        }
        .padding(.vertical, 2)
    }

    private func circularAccessory(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(ExplorerTheme.goldGradient)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(ExplorerTheme.surfaceElevated.opacity(0.9))
            )
            .overlay(
                Circle()
                    .stroke(ExplorerTheme.goldHighlightStart.opacity(0.35), lineWidth: 1)
            )
    }
}

private struct InlineAudioRecorderBar: View {
    var isRecording: Bool
    var durationText: String
    var waveformLevel: CGFloat
    var isPlaying: Bool
    var playbackProgress: Double
    var onPlayPause: () -> Void
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            if isRecording {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(Color.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.red.opacity(0.85)))
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.6), lineWidth: 1)
                    )

                MiniWaveformView(
                    level: waveformLevel,
                    isRecording: true,
                    isPlaying: false
                )
                .frame(height: 28)
                .animation(.easeOut(duration: 0.12), value: waveformLevel)

                Text(durationText)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(ExplorerTheme.textPrimary)
            } else {
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(ExplorerTheme.goldGradient)
                        )
                }
                .buttonStyle(.plain)

                MiniWaveformView(
                    level: CGFloat(playbackProgress),
                    isRecording: false,
                    isPlaying: isPlaying
                )
                .frame(height: 28)
                .animation(.easeOut(duration: 0.25), value: playbackProgress)
                .animation(.easeOut(duration: 0.25), value: isPlaying)

                Text(durationText)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(ExplorerTheme.textPrimary)

                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ExplorerTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Aufnahme entfernen")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ExplorerTheme.surface.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ExplorerTheme.goldHighlightStart.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct InlineAudioErrorView: View {
    let message: String
    let showSettings: Bool
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message)
                .font(.explorer(.caption))
                .foregroundStyle(ExplorerTheme.danger)
                .multilineTextAlignment(.leading)

            if showSettings {
                Button("Einstellungen öffnen", action: openSettings)
                    .font(.explorer(.caption, weight: .semibold))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ExplorerTheme.danger.opacity(0.12))
        )
    }
}

private struct MiniWaveformView: View {
    var level: CGFloat
    var isRecording: Bool
    var isPlaying: Bool

    var body: some View {
        GeometryReader { proxy in
            let clampedLevel = min(max(level, 0), 1)
            let barCount = max(Int(proxy.size.width / 5), 8)
            let amplitude = isRecording
                ? max(clampedLevel, 0.08)
                : (isPlaying ? max(0.35 + clampedLevel * 0.35, 0.28) : 0.28)

            struct WaveformBar: Identifiable {
                let id: Int
                let progress: CGFloat
            }

            let bars: [WaveformBar] = (0..<barCount).map { index in
                let progress = CGFloat(index) / CGFloat(max(barCount - 1, 1))
                return WaveformBar(id: index, progress: progress)
            }

            HStack(alignment: .center, spacing: 3) {
                ForEach(bars) { bar in
                    let base = sin(bar.progress * .pi)
                    let heightMultiplier = max(base * amplitude, 0.12)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(isRecording ? Color.red.opacity(0.85) : ExplorerTheme.goldGradient)
                        .frame(height: max(proxy.size.height * heightMultiplier, 4))
                        .opacity(isRecording ? 0.95 : (isPlaying ? 0.9 : 0.75))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
    }
}

private struct AttachmentComposerChip: View {
    let attachment: ChatAttachment
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: attachment.kind.iconName)
                .font(.explorer(.caption, weight: .semibold))
                .foregroundStyle(ExplorerTheme.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.name)
                    .font(.explorer(.caption, weight: .medium))
                    .lineLimit(1)
                    .foregroundStyle(ExplorerTheme.textPrimary)
                Text(attachment.formattedSize)
                    .font(.explorer(.caption2))
                    .foregroundStyle(ExplorerTheme.textMuted)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.explorer(.caption))
                    .foregroundStyle(ExplorerTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ExplorerTheme.surface.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ExplorerTheme.goldHighlightStart.opacity(0.25), lineWidth: 1)
        )
    }
}

#Preview {
    ChatDetailView(
        agent: SampleData.previewUser.agents.first!,
        userAvatarImageData: SampleData.previewUser.avatarImageData,
        userAvatarSystemName: SampleData.previewUser.avatarSystemName,
        draftedMessage: .constant(""),
        onSend: { _, _ in },
        pendingResponse: true
    )
}
