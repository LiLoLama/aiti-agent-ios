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
                        // Audio recording has been removed; the button remains for future use.
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
