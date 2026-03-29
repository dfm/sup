import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) var auth

    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var codeSent = false
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

            if !codeSent {
                phoneNumberStep
            } else {
                verificationStep
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

    // MARK: - Step 1: Phone number

    private var phoneNumberStep: some View {
        VStack(spacing: 16) {
            TextField("+1 (555) 123-4567", text: $phoneNumber)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(.horizontal, 40)

            Button {
                sendCode()
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("send code")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.black)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(phoneNumber.isEmpty || isLoading)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Step 2: Verification code

    private var verificationStep: some View {
        VStack(spacing: 16) {
            Text("enter the code sent to \(phoneNumber)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("123456", text: $verificationCode)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                verify()
            } label: {
                Group {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("verify")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.black)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(verificationCode.isEmpty || isLoading)
            .padding(.horizontal, 40)

            Button("use a different number") {
                codeSent = false
                verificationCode = ""
                error = nil
            }
            .font(.caption)
        }
    }

    // MARK: - Actions

    private func sendCode() {
        isLoading = true
        error = nil
        Task {
            do {
                try await auth.sendVerificationCode(to: phoneNumber)
                codeSent = true
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func verify() {
        isLoading = true
        error = nil
        Task {
            do {
                try await auth.verifyCode(verificationCode)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
