import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct ChatDetailView: View {
    let agent: AgentProfile
    @Binding var draftedMessage: String
    var onSend: (String, [ChatAttachment]) -> Void
    var pendingResponse: Bool

    @Namespace private var bottomID
    @FocusState private var isComposerFocused: Bool
    @State private var attachments: [ChatAttachment] = []
    @State private var showingFileImporter = false
    @State private var attachmentError: String?

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(agent: agent)

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 20) {
                        ForEach(agent.conversation.messages) { message in
                            ChatBubble(message: message, agent: agent)
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
                    .padding(.vertical, 28)
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
            MessageComposer(
                text: $draftedMessage,
                attachments: $attachments,
                onSend: { text, attachments in
                    onSend(text, attachments)
                    draftedMessage = ""
                    self.attachments.removeAll()
                },
                onRequestFileAttachment: { showingFileImporter = true },
                onRequestAudioAttachment: {},
                isFocused: $isComposerFocused
            )
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .background(.ultraThinMaterial)
        }
        .explorerBackground()
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
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
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(ExplorerTheme.surfaceElevated.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(ExplorerTheme.goldHighlightStart.opacity(0.3), lineWidth: 1.2)
                        )
                        .frame(width: 84, height: 84)

                    Image(systemName: agent.avatarSystemName)
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(ExplorerTheme.goldGradient)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(agent.name)
                        .font(.explorer(.title3, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textPrimary)

                    Text(agent.role)
                        .font(.explorer(.footnote))
                        .foregroundStyle(ExplorerTheme.textSecondary)

                    Label(agent.status.description, systemImage: "circle.fill")
                        .font(.explorer(.caption, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(ExplorerTheme.success)
                }

                Spacer()
            }

            if !agent.description.isEmpty {
                Text(agent.description)
                    .font(.explorer(.footnote))
                    .foregroundStyle(ExplorerTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AgentToolBadges(tools: agent.tools)
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(ExplorerTheme.surface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.35), lineWidth: 1.1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 18)
    }
}

private struct AgentToolBadges: View {
    let tools: [AgentTool]

    var body: some View {
        if tools.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tools) { tool in
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .font(.explorer(.caption2, weight: .semibold))
                            Text(tool.name)
                                .font(.explorer(.caption))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(ExplorerTheme.goldGradient.opacity(0.16))
                        )
                        .overlay(
                            Capsule()
                                .stroke(ExplorerTheme.goldHighlightStart.opacity(0.55), lineWidth: 1)
                        )
                        .foregroundStyle(ExplorerTheme.textPrimary)
                    }
                }
            }
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    let agent: AgentProfile

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
            Image(systemName: message.author == .agent ? agent.avatarSystemName : "person.fill")
                .font(.explorer(.callout, weight: .semibold))
                .foregroundStyle(avatarForegroundStyle)
        }
    }

    private var avatarForegroundStyle: AnyShapeStyle {
        if message.author == .agent {
            return AnyShapeStyle(ExplorerTheme.goldGradient)
        } else {
            return AnyShapeStyle(ExplorerTheme.textPrimary)
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
    var onSend: (String, [ChatAttachment]) -> Void
    var onRequestFileAttachment: () -> Void
    var onRequestAudioAttachment: () -> Void
    var isFocused: FocusState<Bool>.Binding

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(attachments) { attachment in
                            AttachmentComposerChip(attachment: attachment) {
                                removeAttachment(attachment)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack(alignment: .bottom, spacing: 14) {
                Button(action: onRequestFileAttachment) {
                    Image(systemName: "paperclip.circle.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.goldGradient)
                        .frame(width: 48, height: 48)
                        .background(
                            Circle()
                                .fill(ExplorerTheme.surfaceElevated.opacity(0.85))
                        )
                        .overlay(
                            Circle()
                                .stroke(ExplorerTheme.goldHighlightStart.opacity(0.35), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Datei hinzufügen")

                Button(action: onRequestAudioAttachment) {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill")
                            .font(.explorer(.callout, weight: .semibold))
                            .foregroundStyle(Color.white)
                        WaveformBars()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [Color(red: 1.0, green: 0.58, blue: 0.7), Color(red: 1.0, green: 0.32, blue: 0.52)], startPoint: .leading, endPoint: .trailing))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: Color(red: 1.0, green: 0.32, blue: 0.52).opacity(0.35), radius: 12, x: 0, y: 8)
                }
                .accessibilityLabel("Audio aufnehmen")

                TextField("Nachricht schreiben …", text: $text, axis: .vertical)
                    .lineLimit(1...6)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(ExplorerTheme.surface.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(ExplorerTheme.goldHighlightStart.opacity(isFocused.wrappedValue ? 0.6 : 0.25), lineWidth: 1.2)
                    )
                    .font(.explorer(.callout))
                    .foregroundStyle(ExplorerTheme.textPrimary)
                    .focused(isFocused)

                Button {
                    let message = trimmedText
                    guard !message.isEmpty || !attachments.isEmpty else { return }
                    onSend(message, attachments)
                    text = ""
                    isFocused.wrappedValue = false
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(ExplorerTheme.goldGradient)
                        )
                        .shadow(color: ExplorerTheme.goldHighlightEnd.opacity(0.45), radius: 18, x: 0, y: 12)
                }
                .disabled(trimmedText.isEmpty && attachments.isEmpty)
                .opacity(trimmedText.isEmpty && attachments.isEmpty ? 0.55 : 1)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(ExplorerTheme.goldHighlightStart.opacity(0.25), lineWidth: 1)
        )
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    isFocused.wrappedValue = false
                }
            }
        }
    }

    private func removeAttachment(_ attachment: ChatAttachment) {
        attachments.removeAll { $0.id == attachment.id }
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

private struct WaveformBars: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { index in
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                phase = 1
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let base: CGFloat = 10
        let variation: CGFloat = [6, 14, 20, 14, 6][index]
        return base + variation * abs(sin(Double(phase) + Double(index)))
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
