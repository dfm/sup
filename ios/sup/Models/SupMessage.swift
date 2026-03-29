import Foundation
import FirebaseFirestore

struct SupMessage: Identifiable, Codable {
    @DocumentID var id: String?
    var fromUid: String
    var toUid: String
    var timestamp: Date

    static func docID(from fromUid: String, to toUid: String) -> String {
        "\(fromUid)_\(toUid)"
    }
}
