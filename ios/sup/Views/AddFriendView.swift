import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FriendService.self) var friendService

    @State private var query = ""
    @State private var results: [Profile] = []
    @State private var sentTo: Set<String> = []
    @State private var failedTo: Set<String> = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List(results) { user in
                HStack {
                    Text(user.username)
                        .font(.body)

                    Spacer()

                    if sentTo.contains(user.id ?? "") {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if failedTo.contains(user.id ?? "") {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    } else {
                        Button("add") {
                            sendRequest(to: user)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .listStyle(.plain)
            .overlay {
                if results.isEmpty && !query.isEmpty && !isSearching {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "search by username")
            .onChange(of: query) {
                search()
            }
            .navigationTitle("add friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }

    private func search() {
        let current = query
        isSearching = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard query == current else { return }
            results = (try? await friendService.searchUsers(query: current)) ?? []
            isSearching = false
        }
    }

    private func sendRequest(to user: Profile) {
        guard let uid = user.id else { return }
        Task {
            do {
                try await friendService.sendRequest(toUid: uid)
                sentTo.insert(uid)
            } catch {
                failedTo.insert(uid)
            }
        }
    }
}
