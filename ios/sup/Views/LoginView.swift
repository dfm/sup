import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthService.self) var auth
    @Environment(\.colorScheme) var colorScheme

    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("sup")
                .font(.system(size: 64, weight: .black, design: .rounded))

            Text("ping your friends")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                // Apple Sign-In
                SignInWithAppleButton(.signIn) { request in
                    let hashedNonce = auth.prepareAppleSignIn()
                    request.requestedScopes = [.fullName]
                    request.nonce = hashedNonce
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)

                // Google Sign-In
                Button {
                    signInWithGoogle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "g.circle.fill")
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 40)

            if isLoading {
                ProgressView()
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 40)
            }

            Spacer()
                .frame(height: 40)
        }
    }

    // MARK: - Actions

    private func signInWithGoogle() {
        isLoading = true
        error = nil
        Task {
            do {
                try await auth.signInWithGoogle()
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        isLoading = true
        error = nil
        Task {
            do {
                let authorization = try result.get()
                try await auth.handleAppleSignIn(authorization)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
