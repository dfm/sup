import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    private let db = Firestore.firestore()

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    func updateToken() {
        guard let uid = Auth.auth().currentUser?.uid,
              let token = Messaging.messaging().fcmToken else { return }

        db.collection("users").document(uid).updateData(["deviceToken": token])
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        updateToken()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
