import SwiftUI

struct UsernameSetupView: View {
    @Environment(AuthService.self) var auth
    @State private var username = ""
    @State private var error: String?
    @State private var isLoading = false

    private var isValid: Bool {
        username.count >= 3 && username.count <= 20
            && username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("pick a username")
                .font(.title.bold())

            TextField("username", text: $username)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 40)

            Button {
                submit()
            } label: {
                if isLoading {
                    ProgressView()
                } else {
                    Text("let's go")
                        .font(.headline)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValid || isLoading)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
    }

    private func submit() {
        isLoading = true
        error = nil
        Task {
            do {
                try await auth.setUsername(username)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
