import SwiftUI

struct FriendsListView: View {
    @Environment(AuthService.self) var auth
    @Environment(FriendService.self) var friendService
    @Environment(SupService.self) var supService

    @State private var showAddFriend = false
    @State private var showRequests = false
    @State private var lastTapped: String?
    @State private var error: String?
    @State private var hasStartedListening = false

    var body: some View {
        NavigationStack {
            Group {
                if friendService.friends.isEmpty {
                    ContentUnavailableView(
                        "no friends yet",
                        systemImage: "person.2",
                        description: Text("tap + to add a friend")
                    )
                } else {
                    List(friendService.friends) { friend in
                        FriendRow(
                            friend: friend,
                            lastSup: supService.lastSups[friend.id],
                            canSup: supService.canSup(toUid: friend.id),
                            justSent: lastTapped == friend.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sendSup(to: friend)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("sup")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showRequests = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                    }
                    .overlay(alignment: .topTrailing) {
                        if friendService.requestCount > 0 {
                            Text("\(friendService.requestCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.red, in: Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("error", isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("ok") { error = nil }
            } message: {
                Text(error ?? "")
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .sheet(isPresented: $showRequests) {
                FriendRequestsView()
            }
            .task {
                guard !hasStartedListening else { return }
                hasStartedListening = true
                friendService.startListening()
                supService.startListening()
            }
        }
    }

    private func sendSup(to friend: Friend) {
        guard supService.canSup(toUid: friend.id) else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        lastTapped = friend.id

        Task {
            do {
                try await supService.sendSup(toUid: friend.id)
            } catch {
                self.error = "couldn't send sup"
            }
            try? await Task.sleep(for: .seconds(1))
            if lastTapped == friend.id { lastTapped = nil }
        }
    }
}

struct FriendRow: View {
    let friend: Friend
    let lastSup: SupMessage?
    let canSup: Bool
    let justSent: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.username)
                    .font(.headline)

                if let sup = lastSup {
                    Text("supped you \(sup.timestamp.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if justSent {
                Text("sent!")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            } else if !canSup {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .opacity(canSup ? 1 : 0.5)
    }
}
