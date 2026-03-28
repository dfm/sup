import Foundation
import FirebaseFirestore

struct Friendship: Identifiable, Codable {
    @DocumentID var id: String?
    var users: [String]
    var status: Status
    var requestedBy: String
    var createdAt: Date

    enum Status: String, Codable {
        case pending
        case accepted
    }

    static func docID(uid1: String, uid2: String) -> String {
        [uid1, uid2].sorted().joined(separator: "_")
    }
}
