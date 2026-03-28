import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

@Observable
final class AuthService {
    var currentUser: FirebaseAuth.User? { Auth.auth().currentUser }
    var appUser: AppUser?
    var isSignedIn = false
    var hasUsername = false

    private var authListener: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?
    private let db = Firestore.firestore()

    // For Apple Sign-In flow
    private var currentNonce: String?

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.isSignedIn = user != nil
            if let user {
                self?.listenToUserDoc(uid: user.uid)
            } else {
                self?.userListener?.remove()
                self?.appUser = nil
                self?.hasUsername = false
            }
        }
    }

    deinit {
        if let authListener { Auth.auth().removeStateDidChangeListener(authListener) }
        userListener?.remove()
    }

    // MARK: - Apple Sign-In

    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async throws {
        let authorization = try result.get()
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            throw AuthError.invalidCredential
        }

        let oauthCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        try await Auth.auth().signIn(with: oauthCredential)
    }

    // MARK: - Username Setup

    func setUsername(_ username: String) async throws {
        guard let uid = currentUser?.uid else { throw AuthError.notSignedIn }

        // Check uniqueness
        let snapshot = try await db.collection("users")
            .whereField("usernameLower", isEqualTo: username.lowercased())
            .getDocuments()

        if !snapshot.documents.isEmpty {
            throw AuthError.usernameTaken
        }

        let user = AppUser(username: username)
        try db.collection("users").document(uid).setData(from: user)
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
    }

    // MARK: - Private

    private func listenToUserDoc(uid: String) {
        userListener?.remove()
        userListener = db.collection("users").document(uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let snapshot, snapshot.exists else {
                    self?.appUser = nil
                    self?.hasUsername = false
                    return
                }
                self.appUser = try? snapshot.data(as: AppUser.self)
                self.hasUsername = self.appUser != nil
            }
    }

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum AuthError: LocalizedError {
    case invalidCredential
    case notSignedIn
    case usernameTaken

    var errorDescription: String? {
        switch self {
        case .invalidCredential: "Invalid sign-in credential."
        case .notSignedIn: "Not signed in."
        case .usernameTaken: "That username is already taken."
        }
    }
}
