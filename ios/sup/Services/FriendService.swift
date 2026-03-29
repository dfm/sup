import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@Observable
final class FriendService {
    var friends: [Friend] = []
    var incomingRequests: [(friendship: Friendship, username: String)] = []
    var requestCount: Int { incomingRequests.count }

    private let db = Firestore.firestore()
    private let functions = Functions.functions()
    private var friendshipListener: ListenerRegistration?

    deinit {
        friendshipListener?.remove()
    }

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        friendshipListener?.remove()
        friendshipListener = db.collection("friendships")
            .whereField("users", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let docs = snapshot?.documents else { return }
                self.processFriendships(docs, currentUid: uid)
            }
    }

    func stopListening() {
        friendshipListener?.remove()
        friends = []
        incomingRequests = []
    }

    func sendRequest(toUid: String, toUsername: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard uid != toUid else { return }

        let docID = Friendship.docID(uid1: uid, uid2: toUid)

        // Don't overwrite an existing friendship
        let existing = try await db.collection("friendships").document(docID).getDocument()
        if existing.exists { return }

        // Get current user's username
        let userDoc = try await db.collection("users").document(uid).getDocument()
        let currentUsername = try userDoc.data(as: AppUser.self).username

        let friendship = Friendship(
            users: [uid, toUid].sorted(),
            status: .pending,
            requestedBy: uid,
            usernames: [uid: currentUsername, toUid: toUsername],
            createdAt: Date()
        )
        try await db.collection("friendships").document(docID).setData(from: friendship)
    }

    func acceptRequest(friendship: Friendship) async throws {
        guard let id = friendship.id else { return }
        try await db.collection("friendships").document(id)
            .updateData(["status": Friendship.Status.accepted.rawValue])
    }

    func declineRequest(friendship: Friendship) async throws {
        guard let id = friendship.id else { return }
        try await db.collection("friendships").document(id).delete()
    }

    func searchUsers(query: String) async throws -> [UserSearchResult] {
        guard !query.isEmpty else { return [] }

        let result = try await functions.httpsCallable("searchUsers").call(["query": query])

        guard let data = result.data as? [[String: Any]] else { return [] }

        return data.compactMap { item in
            guard let uid = item["uid"] as? String,
                  let username = item["username"] as? String else { return nil }
            return UserSearchResult(id: uid, username: username)
        }
    }

    // MARK: - Private

    private func processFriendships(_ docs: [QueryDocumentSnapshot], currentUid: String) {
        var newFriends: [Friend] = []
        var newRequests: [(Friendship, String)] = []

        for doc in docs {
            guard let friendship = try? doc.data(as: Friendship.self) else { continue }
            let otherUid = friendship.users.first { $0 != currentUid } ?? ""
            let otherUsername = friendship.usernames[otherUid] ?? "unknown"

            switch friendship.status {
            case .accepted:
                newFriends.append(Friend(id: otherUid, username: otherUsername))
            case .pending:
                if friendship.requestedBy != currentUid {
                    newRequests.append((friendship, otherUsername))
                }
            }
        }

        friends = newFriends.sorted { $0.username < $1.username }
        incomingRequests = newRequests
    }
}
