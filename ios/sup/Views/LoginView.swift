import SwiftUI
import GoogleSignIn

struct LoginView: View {
    @Environment(AuthService.self) var auth
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("sup")
                .font(.system(size: 64, weight: .black, design: .rounded))

            Text("ping your friends")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                signIn()
            } label: {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "person.circle.fill")
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.black)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isLoading)
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

    private func signIn() {
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
}
