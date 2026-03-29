import Foundation
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import GoogleSignIn
import GoogleSignInSwift

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

    /// Current nonce used for Apple Sign-In
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

    // MARK: - Google Sign-In

    func signInWithGoogle() async throws {
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = await windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidCredential
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().signIn(with: credential)
    }

    // MARK: - Apple Sign-In

    /// Prepares and returns a nonce for Apple Sign-In.
    func prepareAppleSignIn() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    /// Completes Apple Sign-In with the authorization result.
    func handleAppleSignIn(_ authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8),
              let nonce = currentNonce else {
            throw AuthError.invalidCredential
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        try await Auth.auth().signIn(with: credential)
        currentNonce = nil
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
            && error.code == FirestoreErrorCode.permissionDenied.rawValue {
            throw AuthError.usernameTaken
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
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
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess { fatalError("Unable to generate nonce.") }
                return random
            }
            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
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
    case noRootViewController

    var errorDescription: String? {
        switch self {
        case .invalidCredential: "Invalid sign-in credential."
        case .notSignedIn: "Not signed in."
        case .usernameTaken: "That username is already taken."
        case .noRootViewController: "Unable to present sign-in."
        }
    }
}
