import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthService.self) var auth
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

            SignInWithAppleButton(.signIn) { request in
                let hashedNonce = auth.prepareAppleSignIn()
                request.requestedScopes = [.email]
                request.nonce = hashedNonce
            } onCompletion: { result in
                Task {
                    do {
                        try await auth.handleAppleSignIn(result)
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 40)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
                .frame(height: 40)
        }
    }
}
