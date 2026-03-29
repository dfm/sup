import SwiftUI
import FirebaseCore
import FirebaseMessaging

@main
struct SupApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var authService = AuthService()
    @State private var friendService = FriendService()
    @State private var supService = SupService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(friendService)
                .environment(supService)
                .onAppear {
                    // Clean up listeners on sign-out
                    authService.onSignOut = { [friendService, supService] in
                        friendService.stopListening()
                        supService.stopListening()
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    let notificationService = NotificationService()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = notificationService
        Messaging.messaging().delegate = notificationService

        Task {
            _ = await notificationService.requestPermission()
            notificationService.updateToken()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}
