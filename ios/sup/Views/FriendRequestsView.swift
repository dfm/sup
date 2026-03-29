import SwiftUI

struct FriendRequestsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FriendService.self) var friendService

    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if friendService.incomingRequests.isEmpty {
                    ContentUnavailableView(
                        "no requests",
                        systemImage: "tray",
                        description: Text("friend requests will show up here")
                    )
                } else {
                    List(friendService.incomingRequests, id: \.user.id) { item in
                        HStack {
                            Text(item.user.username)
                                .font(.body)

                            Spacer()

                            Button {
                                accept(item.friendship)
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }

                            Button {
                                decline(item.friendship)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("requests")
            .navigationBarTitleDisplayMode(.inline)
            .alert("error", isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("ok") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }

    private func accept(_ friendship: Friendship) {
        Task {
            do {
                try await friendService.acceptRequest(friendship: friendship)
            } catch {
                self.error = "couldn't accept request"
            }
        }
    }

    private func decline(_ friendship: Friendship) {
        Task {
            do {
                try await friendService.declineRequest(friendship: friendship)
            } catch {
                self.error = "couldn't decline request"
            }
        }
    }
}
