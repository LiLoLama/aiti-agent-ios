import SwiftUI

struct ChatDetailView: View {
    let agent: AgentProfile
    @Binding var draftedMessage: String
    var onSend: (String) -> Void
    var pendingResponse: Bool

    @Namespace private var bottomID
    @FocusState private var isComposerFocused: Bool

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
                .onTapGesture {
                    isComposerFocused = false
                }
                .background(Color(.systemBackground))
                .onChange(of: agent.conversation.messages.count) { _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
                .onChange(of: isComposerFocused) { focused in
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
                    onSend: onSend,
                    isFocused: $isComposerFocused
                )
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .background(.thinMaterial)
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
            }

            Spacer()
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 12)
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
                Text(message.content)
                    .padding(16)
                    .foregroundStyle(message.author == .agent ? .primary : Color.white)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

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
    var onSend: (String) -> Void
    var isFocused: FocusState<Bool>.Binding

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Nachricht schreiben …", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                .focused(isFocused)

            Button {
                let message = trimmedText
                guard !message.isEmpty else { return }
                onSend(message)
                text = ""
                isFocused.wrappedValue = false
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3.bold())
                    .foregroundStyle(Color.white)
                    .padding(12)
                    .background(Circle().fill(Color.accentColor))
            }
            .disabled(trimmedText.isEmpty)
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

#Preview {
    ChatDetailView(
        agent: SampleData.previewUser.agents.first!,
        draftedMessage: .constant(""),
        onSend: { _ in },
        pendingResponse: true
    )
}
