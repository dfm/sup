# sup

A dead-simple iOS app. Tap a friend, send them a "sup" push notification.

## Project Structure

```
ios/sup/          # SwiftUI iOS app
  App/            # App entry point & delegate
  Models/         # Firestore data models
  Views/          # SwiftUI views
  Services/       # Auth, friends, sups, notifications
firebase/         # Firebase backend
  functions/      # Cloud Functions (push notifications, rate limiting)
  firestore.rules # Security rules
```

## Setup

### Firebase

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Authentication** with Phone Number provider
3. Enable **Cloud Firestore**
4. Enable **Cloud Messaging**
5. Download `GoogleService-Info.plist` and add it to the Xcode project
6. Deploy backend:
   ```bash
   cd firebase
   npm install --prefix functions
   firebase deploy
   ```

### iOS (Xcode)

1. Open Xcode → File → New Project → iOS App (SwiftUI, Swift)
2. Copy the files from `ios/sup/` into your project
3. Add Firebase SDK via Swift Package Manager:
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Select: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseMessaging`
4. Add `GoogleService-Info.plist` to the project
5. Enable capabilities: **Push Notifications**, **Background Modes** (Remote notifications)
6. Build and run

## Design

See [DESIGN.md](DESIGN.md) for the full design doc.
