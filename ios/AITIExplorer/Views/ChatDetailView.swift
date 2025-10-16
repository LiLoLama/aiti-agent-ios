import SwiftUI

struct ChatDetailView: View {
    let agent: AgentProfile
    @Binding var draftedMessage: String
    var onSend: (String) -> Void
    var pendingResponse: Bool
    var onShowSearch: () -> Void

    @Namespace private var bottomID

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(agent: agent, onShowSearch: onShowSearch)

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
                .background(Color(.systemBackground))
                .onChange(of: agent.conversation.messages.count) { _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }

            Divider()

            MessageComposer(text: $draftedMessage, onSend: onSend)
                .padding()
                .background(.thinMaterial)
        }
        .ignoresSafeArea(.keyboard)
    }
}

private struct ChatHeaderView: View {
    let agent: AgentProfile
    var onShowSearch: () -> Void

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
                Label(agent.status.description, systemImage: statusIcon)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            Button(action: onShowSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.title3)
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 12)
    }

    private var statusIcon: String {
        switch agent.status {
        case .online:
            return "circle.fill"
        case .offline:
            return "circle"
        case .busy:
            return "clock.fill"
        }
    }

    private var statusColor: Color {
        switch agent.status {
        case .online:
            return .green
        case .offline:
            return .gray
        case .busy:
            return .orange
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

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextEditor(text: $text)
                .frame(minHeight: 44, maxHeight: 120)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

            Button {
                onSend(text)
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3.bold())
                    .foregroundStyle(Color.white)
                    .padding(12)
                    .background(Circle().fill(Color.accentColor))
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}

#Preview {
    ChatDetailView(
        agent: SampleData.previewUser.agents.first!,
        draftedMessage: .constant(""),
        onSend: { _ in },
        pendingResponse: true,
        onShowSearch: {}
    )
}
