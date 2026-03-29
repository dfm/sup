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

    /// Called when auth state changes so other services can react
    var onSignOut: (() -> Void)?

    private var authListener: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?
    private let db = Firestore.firestore()

    // For Apple Sign-In flow
    private var currentNonce: String?

    init() {
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let wasSignedIn = self?.isSignedIn ?? false
            self?.isSignedIn = user != nil
            if let user {
                self?.listenToUserDoc(uid: user.uid)
            } else {
                self?.userListener?.remove()
                self?.appUser = nil
                self?.hasUsername = false
                if wasSignedIn { self?.onSignOut?() }
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
        currentNonce = nil
        try await Auth.auth().signIn(with: oauthCredential)
    }

    // MARK: - Username Setup

    func setUsername(_ username: String) async throws {
        guard let uid = currentUser?.uid else { throw AuthError.notSignedIn }

        let lower = username.lowercased()

        // Atomically reserve the username via the usernames collection.
        // If the doc already exists, this will fail with a permission error.
        let batch = db.batch()

        let usernameRef = db.collection("usernames").document(lower)
        batch.setData(["uid": uid], forDocument: usernameRef)

        let userRef = db.collection("users").document(uid)
        let user = AppUser(username: username)
        try batch.setData(from: user, forDocument: userRef)

        let profileRef = db.collection("profiles").document(uid)
        let profile = Profile(username: username)
        try batch.setData(from: profile, forDocument: profileRef)

        do {
            try await batch.commit()
        } catch let error as NSError where error.domain == "FIRFirestoreErrorDomain"
            && error.code == 7 /* PERMISSION_DENIED */ {
            throw AuthError.usernameTaken
        }
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
                guard let self else { return }
                guard let snapshot, snapshot.exists else {
                    self.appUser = nil
                    self.hasUsername = false
                    return
                }
                self.appUser = try? snapshot.data(as: AppUser.self)
                self.hasUsername = self.appUser != nil
            }
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let limit = UInt8(256 / charset.count) * UInt8(charset.count)
        var result: [Character] = []
        result.reserveCapacity(length)
        while result.count < length {
            var byte: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &byte)
            guard byte < limit else { continue }
            result.append(charset[Int(byte) % charset.count])
        }
        return String(result)
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
