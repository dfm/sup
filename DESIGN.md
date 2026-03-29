# sup — Design Doc

A dead-simple iOS app. Tap a friend, send them a "sup" push notification.

## App Flow

1. **Launch** → check Firebase Auth state
2. **Not signed in** → Phone Number Auth screen
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

### `users/{uid}` (private — owner-read only)
| Field | Type | Description |
|-------|------|-------------|
| username | string | Unique |
| usernameLower | string | For case-insensitive search |
| deviceToken | string | FCM token for push notifications |
| createdAt | timestamp | Account creation time |

### `profiles/{uid}` (public — readable by any authenticated user)
| Field | Type | Description |
|-------|------|-------------|
| username | string | Unique |
| usernameLower | string | For case-insensitive search |
| createdAt | timestamp | Account creation time |

### `usernames/{usernameLower}` (atomic uniqueness enforcement)
| Field | Type | Description |
|-------|------|-------------|
| uid | string | Owner's uid |

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

1. **onSupWritten** — verifies friendship, enforces rate limit, sends push notification
2. **onFriendRequestCreated** — when a friendship doc is created with status "pending", notify the recipient

## Rate Limiting

- Enforced in Cloud Function: if existing sup doc timestamp < 60s ago, reject
- Also enforced client-side for UX (disable button for 60s after tap)

## Tech Stack

- **iOS**: SwiftUI, iOS 17+, Swift 5.9+
- **Auth**: Firebase Auth with Phone Number Auth
- **Database**: Cloud Firestore
- **Push**: Firebase Cloud Messaging (FCM) → APNs
- **Backend**: Firebase Cloud Functions (Node.js)

## Security Rules

- `users/{uid}`: owner-only read/write (contains deviceToken)
- `profiles/{uid}`: readable by any auth user, writable by owner with field validation
- `usernames/{usernameLower}`: create-only (enforces atomic uniqueness)
- `friendships`: readable by participants, only non-requester can accept, only status field can change on update, doc ID and users array must be sorted
- `sups`: doc ID must match `{fromUid}_{toUid}`, server-side friendship verification
- Rate limiting enforced server-side in Cloud Functions
