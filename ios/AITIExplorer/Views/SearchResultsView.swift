import SwiftUI

struct SearchResultsView: View {
    @Binding var query: String
    let results: [ChatMessage]
    let isSearching: Bool

    var body: some View {
        List {
            Section(header: Text("Suche")) {
                TextField("Nachrichten durchsuchen", text: $query)
                    .textFieldStyle(.roundedBorder)
            }

            Section(header: Text("Ergebnisse")) {
                if isSearching && results.isEmpty {
                    ProgressView("Suche läuft …")
                        .frame(maxWidth: .infinity)
                } else if results.isEmpty {
                    ContentUnavailableView.search
                } else {
                    ForEach(results) { message in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(message.content)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(4)

                            Text(message.timeLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Chat durchsuchen")
    }
}

#Preview {
    SearchResultsView(
        query: .constant("Launch"),
        results: SampleData.previewUser.agents.first!.conversation.messages,
        isSearching: false
    )
}
