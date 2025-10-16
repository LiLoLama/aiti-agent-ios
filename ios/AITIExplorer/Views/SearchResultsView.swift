import SwiftUI

struct SearchResultsView: View {
    @Binding var query: String
    let results: [ChatMessage]
    let isSearching: Bool
    @FocusState private var queryFieldFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Chat durchsuchen")
                        .font(.explorer(.title3, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textPrimary)

                    TextField("Nachrichten durchsuchen", text: $query)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(ExplorerTheme.surface.opacity(0.85))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(ExplorerTheme.goldHighlightStart.opacity(0.35), lineWidth: 1)
                        )
                        .font(.explorer(.callout))
                        .foregroundStyle(ExplorerTheme.textPrimary)
                        .focused($queryFieldFocused)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Ergebnisse")
                        .font(.explorer(.footnote, weight: .semibold))
                        .foregroundStyle(ExplorerTheme.textSecondary)
                        .textCase(.uppercase)

                    if isSearching && results.isEmpty {
                        ProgressView("Suche läuft …")
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(ExplorerTheme.surface.opacity(0.85))
                            )
                    } else if results.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Keine Treffer")
                                .font(.explorer(.callout, weight: .semibold))
                                .foregroundStyle(ExplorerTheme.textSecondary)
                            Text("Passe deine Suche an oder überprüfe andere Chats.")
                                .font(.explorer(.footnote))
                                .foregroundStyle(ExplorerTheme.textMuted)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(ExplorerTheme.surface.opacity(0.85))
                        )
                    } else {
                        VStack(spacing: 16) {
                            ForEach(results) { message in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(message.content)
                                        .font(.explorer(.callout))
                                        .foregroundStyle(ExplorerTheme.textPrimary)
                                        .lineLimit(4)

                                    Text(message.timeLabel)
                                        .font(.explorer(.caption2))
                                        .foregroundStyle(ExplorerTheme.textMuted)
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(ExplorerTheme.surface.opacity(0.85))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(ExplorerTheme.goldHighlightStart.opacity(0.25), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .explorerBackground()
        .scrollDismissesKeyboard(.interactively)
        .dismissFocusOnInteract($queryFieldFocused)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SearchResultsView(
        query: .constant("Launch"),
        results: SampleData.previewUser.agents.first!.conversation.messages,
        isSearching: false
    )
}
