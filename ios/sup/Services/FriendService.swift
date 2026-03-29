import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
final class FriendService {
    var friends: [Profile] = []
    var incomingRequests: [(friendship: Friendship, user: Profile)] = []
    var requestCount: Int { incomingRequests.count }

    private let db = Firestore.firestore()
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
                Task { await self.processFriendships(docs, currentUid: uid) }
            }
    }

    func stopListening() {
        friendshipListener?.remove()
        friends = []
        incomingRequests = []
    }

    func sendRequest(toUid: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard uid != toUid else { return }

        let docID = Friendship.docID(uid1: uid, uid2: toUid)

        // Don't overwrite an existing friendship
        let existing = try await db.collection("friendships").document(docID).getDocument()
        if existing.exists { return }

        let friendship = Friendship(
            users: [uid, toUid].sorted(),
            status: .pending,
            requestedBy: uid,
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

    func searchUsers(query: String) async throws -> [Profile] {
        guard !query.isEmpty else { return [] }
        let lower = query.lowercased()

        let snapshot = try await db.collection("profiles")
            .whereField("usernameLower", isGreaterThanOrEqualTo: lower)
            .whereField("usernameLower", isLessThanOrEqualTo: lower + "\u{f8ff}")
            .limit(to: 20)
            .getDocuments()

        let currentUid = Auth.auth().currentUser?.uid
        return snapshot.documents.compactMap { doc in
            guard doc.documentID != currentUid else { return nil }
            return try? doc.data(as: Profile.self)
        }
    }

    // MARK: - Private

    private func processFriendships(_ docs: [QueryDocumentSnapshot], currentUid: String) async {
        var newFriends: [Profile] = []
        var newRequests: [(Friendship, Profile)] = []

        // Fetch all friend profiles in parallel
        await withTaskGroup(of: (Friendship, Profile?)?.self) { group in
            for doc in docs {
                guard let friendship = try? doc.data(as: Friendship.self) else { continue }
                let otherUid = friendship.users.first { $0 != currentUid } ?? ""

                group.addTask { [db] in
                    guard let userDoc = try? await db.collection("profiles").document(otherUid).getDocument(),
                          let profile = try? userDoc.data(as: Profile.self) else { return nil }
                    return (friendship, profile)
                }
            }

            for await result in group {
                guard let (friendship, profile) = result, let profile else { continue }
                switch friendship.status {
                case .accepted:
                    newFriends.append(profile)
                case .pending:
                    if friendship.requestedBy != currentUid {
                        newRequests.append((friendship, profile))
                    }
                }
            }
        }

        await MainActor.run {
            self.friends = newFriends.sorted { $0.username < $1.username }
            self.incomingRequests = newRequests
        }
    }
}
