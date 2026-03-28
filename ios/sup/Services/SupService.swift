import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
final class SupService {
    /// Most recent sup received from each friend: [fromUid: SupMessage]
    var lastSups: [String: SupMessage] = [:]

    /// Tracks cooldown: [toUid: Date when cooldown expires]
    var cooldowns: [String: Date] = [:]

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private let cooldownSeconds: TimeInterval = 60

    deinit {
        listener?.remove()
    }

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        listener?.remove()
        listener = db.collection("sups")
            .whereField("toUid", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let docs = snapshot?.documents else { return }
                var sups: [String: SupMessage] = [:]
                for doc in docs {
                    if let sup = try? doc.data(as: SupMessage.self) {
                        sups[sup.fromUid] = sup
                    }
                }
                self.lastSups = sups
            }
    }

    func stopListening() {
        listener?.remove()
        lastSups = [:]
    }

    func canSup(toUid: String) -> Bool {
        if let expiry = cooldowns[toUid], Date() < expiry {
            return false
        }
        return true
    }

    func sendSup(toUid: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard canSup(toUid: toUid) else { return }

        let sup = SupMessage(fromUid: uid, toUid: toUid, timestamp: Date())
        let docID = SupMessage.docID(from: uid, to: toUid)

        try db.collection("sups").document(docID).setData(from: sup)

        await MainActor.run {
            self.cooldowns[toUid] = Date().addingTimeInterval(self.cooldownSeconds)
        }
    }
}
