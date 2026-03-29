const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const COOLDOWN_SECONDS = 60;

let _db = getFirestore();
let _messaging = getMessaging();

function getDb() { return _db; }
function getMsg() { return _messaging; }

// Test-only hooks
if (process.env.NODE_ENV === "test") {
  exports._setDb = (db) => { _db = db; };
  exports._setMessaging = (msg) => { _messaging = msg; };
}
exports.COOLDOWN_SECONDS = COOLDOWN_SECONDS;

/**
 * Callable function: search users by username prefix.
 * Queries the profiles collection server-side (admin SDK bypasses rules).
 */
async function handleSearchUsers(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in");
  }

  const query = request.data?.query;
  if (!query || typeof query !== "string") {
    return [];
  }

  const lower = query.toLowerCase();
  const db = getDb();

  const snapshot = await db.collection("profiles")
    .where("usernameLower", ">=", lower)
    .where("usernameLower", "<=", lower + "\uf8ff")
    .limit(20)
    .get();

  return snapshot.docs
    .filter((doc) => doc.id !== request.auth.uid)
    .map((doc) => ({
      uid: doc.id,
      username: doc.data().username,
    }));
}

/**
 * When a sup document is created or updated, verify friendship,
 * enforce rate limiting, and send a push notification.
 */
async function handleSupWritten(event) {
  const after = event.data?.after?.data();
  if (!after) return;

  const { fromUid, toUid, timestamp } = after;
  const db = getDb();

  // Verify friendship exists and is accepted
  const friendshipId = [fromUid, toUid].sort().join("_");
  const friendshipDoc = await db.collection("friendships").doc(friendshipId).get();
  if (!friendshipDoc.exists || friendshipDoc.data()?.status !== "accepted") {
    // Not friends — delete the sup
    await event.data.after.ref.delete();
    return;
  }

  // Rate limit: check if previous sup was too recent
  const before = event.data?.before?.data();
  if (before?.timestamp) {
    const prevTime = before.timestamp.toDate();
    const newTime = timestamp.toDate();
    const diff = (newTime - prevTime) / 1000;
    if (diff < COOLDOWN_SECONDS) {
      await event.data.after.ref.set(before);
      return;
    }
  }

  // Get sender username from friendship doc, recipient device token from users
  const friendshipData = friendshipDoc.data();
  const senderName = friendshipData?.usernames?.[fromUid] || "someone";

  const recipientDoc = await db.collection("users").doc(toUid).get();
  const deviceToken = recipientDoc.data()?.deviceToken;

  if (!deviceToken) return;

  try {
    await getMsg().send({
      token: deviceToken,
      notification: {
        title: "sup",
        body: `${senderName} says sup`,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
  } catch (err) {
    console.error("Failed to send sup notification:", err.message);
  }
}

/**
 * When a friendship is created with status "pending",
 * notify the recipient of the friend request.
 */
async function handleFriendRequestCreated(event) {
  const data = event.data?.data();
  if (!data || data.status !== "pending") return;

  const { requestedBy, users, usernames } = data;
  const recipientUid = users.find((uid) => uid !== requestedBy);
  if (!recipientUid) return;

  const db = getDb();

  // Sender username is denormalized in the friendship doc
  const senderName = usernames?.[requestedBy] || "someone";

  const recipientDoc = await db.collection("users").doc(recipientUid).get();
  const deviceToken = recipientDoc.data()?.deviceToken;

  if (!deviceToken) return;

  try {
    await getMsg().send({
      token: deviceToken,
      notification: {
        title: "friend request",
        body: `${senderName} wants to be friends`,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });
  } catch (err) {
    console.error("Failed to send friend request notification:", err.message);
  }
}

exports.handleSearchUsers = handleSearchUsers;
exports.handleSupWritten = handleSupWritten;
exports.handleFriendRequestCreated = handleFriendRequestCreated;
exports.searchUsers = onCall(handleSearchUsers);
exports.onSupWritten = onDocumentWritten("sups/{docId}", handleSupWritten);
exports.onFriendRequestCreated = onDocumentCreated("friendships/{docId}", handleFriendRequestCreated);
