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
