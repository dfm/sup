import SwiftUI

struct FriendRequestsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FriendService.self) var friendService

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
                                Task { try? await friendService.acceptRequest(friendship: item.friendship) }
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }

                            Button {
                                Task { try? await friendService.declineRequest(friendship: item.friendship) }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }
}
