const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
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

  // Look up sender username and recipient device token
  const [senderDoc, recipientDoc] = await Promise.all([
    db.collection("profiles").doc(fromUid).get(),
    db.collection("users").doc(toUid).get(),
  ]);

  const senderName = senderDoc.data()?.username || "someone";
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

  const { requestedBy, users } = data;
  const recipientUid = users.find((uid) => uid !== requestedBy);
  if (!recipientUid) return;

  const db = getDb();
  const [senderDoc, recipientDoc] = await Promise.all([
    db.collection("profiles").doc(requestedBy).get(),
    db.collection("users").doc(recipientUid).get(),
  ]);

  const senderName = senderDoc.data()?.username || "someone";
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

exports.handleSupWritten = handleSupWritten;
exports.handleFriendRequestCreated = handleFriendRequestCreated;
exports.onSupWritten = onDocumentWritten("sups/{docId}", handleSupWritten);
exports.onFriendRequestCreated = onDocumentCreated("friendships/{docId}", handleFriendRequestCreated);
