import Foundation
import FirebaseFirestore

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var usernameLower: String
    var deviceToken: String?
    var createdAt: Date

    init(username: String, deviceToken: String? = nil) {
        self.username = username
        self.usernameLower = username.lowercased()
        self.deviceToken = deviceToken
        self.createdAt = Date()
    }
}

/// Public profile visible to other users (no sensitive fields like deviceToken)
struct Profile: Identifiable, Codable {
    @DocumentID var id: String?
    var username: String
    var usernameLower: String
    var createdAt: Date

    init(username: String) {
        self.username = username
        self.usernameLower = username.lowercased()
        self.createdAt = Date()
    }
}
