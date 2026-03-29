import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) var auth

    var body: some View {
        Group {
            if !auth.isSignedIn {
                LoginView()
            } else if !auth.hasUsername {
                UsernameSetupView()
            } else {
                FriendsListView()
            }
        }
        .animation(.default, value: auth.isSignedIn)
        .animation(.default, value: auth.hasUsername)
    }
}
