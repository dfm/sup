import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
final class AuthService {
    var currentUser: FirebaseAuth.User? { Auth.auth().currentUser }
    var appUser: AppUser?
    var isSignedIn = false
    var hasUsername = false

    /// Called when auth state changes so other services can react
    var onSignOut: (() -> Void)?

    /// Set after sending verification code; used to complete sign-in
    var verificationID: String?

    private var authListener: AuthStateDidChangeListenerHandle?
    private var userListener: ListenerRegistration?
    private let db = Firestore.firestore()

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

    // MARK: - Phone Auth

    func sendVerificationCode(to phoneNumber: String) async throws {
        let id = try await PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil)
        verificationID = id
    }

    func verifyCode(_ code: String) async throws {
        guard let verificationID else {
            throw AuthError.noVerificationID
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: code
        )
        try await Auth.auth().signIn(with: credential)
        self.verificationID = nil
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
}

enum AuthError: LocalizedError {
    case invalidCredential
    case notSignedIn
    case usernameTaken
    case noVerificationID

    var errorDescription: String? {
        switch self {
        case .invalidCredential: "Invalid sign-in credential."
        case .notSignedIn: "Not signed in."
        case .usernameTaken: "That username is already taken."
        case .noVerificationID: "No verification code was sent. Please try again."
        }
    }
}
