# sup — Design Doc

A dead-simple iOS app. Tap a friend, send them a "sup" push notification.

## App Flow

1. **Launch** → check Firebase Auth state
2. **Not signed in** → Apple Sign-In screen
3. **Signed in, no username** → pick a unique username
4. **Signed in with username** → friends list (main screen)

## Screens

### Friends List (main screen)
- List of accepted friends
- Each row: username + when they last supped you
- Tap a row → sends a sup (instant, with haptic feedback)
- Toolbar: "Add Friend" button, friend requests button (with badge count)

### Add Friend
- Search field → search users by username
- Tap result → send friend request

### Friend Requests
- List of pending incoming requests
- Accept / decline each one

## Data Model (Firestore)

### `users/{uid}`
| Field | Type | Description |
|-------|------|-------------|
| username | string | Unique, lowercase |
| usernameLower | string | For case-insensitive search |
| deviceToken | string | FCM token for push notifications |
| createdAt | timestamp | Account creation time |

### `friendships/{uid1}_{uid2}` (uids sorted alphabetically)
| Field | Type | Description |
|-------|------|-------------|
| users | array[string] | [uid1, uid2] sorted |
| status | string | "pending" or "accepted" |
| requestedBy | string | uid of requester |
| createdAt | timestamp | Request time |

### `sups/{fromUid}_{toUid}` (overwritten each time)
| Field | Type | Description |
|-------|------|-------------|
| fromUid | string | Sender |
| toUid | string | Recipient |
| timestamp | timestamp | When the sup was sent |

## Cloud Functions

1. **onSupWritten** — when a sup doc is created/updated, send push notification to recipient
2. **onFriendRequestCreated** — when a friendship doc is created with status "pending", notify the recipient

## Rate Limiting

- Enforced in Cloud Function: if existing sup doc timestamp < 60s ago, reject
- Also enforced client-side for UX (disable button for 60s after tap)

## Tech Stack

- **iOS**: SwiftUI, iOS 17+, Swift 5.9+
- **Auth**: Firebase Auth with Apple Sign-In
- **Database**: Cloud Firestore
- **Push**: Firebase Cloud Messaging (FCM) → APNs
- **Backend**: Firebase Cloud Functions (Node.js)

## Security Rules

- Users can only read/write their own user doc
- Friendships readable by either participant
- Friendship creation requires auth (requestedBy == caller)
- Sups writable only by the fromUid user, readable by either party
- Rate limiting enforced server-side in Cloud Functions
