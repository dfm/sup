import Foundation
import FirebaseFirestore

struct Friendship: Identifiable, Codable {
    @DocumentID var id: String?
    var users: [String]
    var status: Status
    var requestedBy: String
    var usernames: [String: String]
    var createdAt: Date

    enum Status: String, Codable {
        case pending
        case accepted
    }

    static func docID(uid1: String, uid2: String) -> String {
        [uid1, uid2].sorted().joined(separator: "_")
    }

    /// Returns the username of the other user in this friendship.
    func otherUsername(currentUid: String) -> String {
        let otherUid = users.first { $0 != currentUid } ?? ""
        return usernames[otherUid] ?? "unknown"
    }
}

/// Lightweight type representing a friend, derived from a Friendship doc.
struct Friend: Identifiable {
    let id: String
    let username: String
}

/// Search result returned from the searchUsers Cloud Function.
struct UserSearchResult: Identifiable {
    let id: String
    let username: String
}
