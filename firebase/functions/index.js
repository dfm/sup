const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const COOLDOWN_SECONDS = 60;

// Exported for testability; production code uses the real instances.
let _db = getFirestore();
let _messaging = getMessaging();

function getDb() { return _db; }
function getMsg() { return _messaging; }

// Allow tests to swap in mocks
exports._setDb = (db) => { _db = db; };
exports._setMessaging = (msg) => { _messaging = msg; };
exports.COOLDOWN_SECONDS = COOLDOWN_SECONDS;

/**
 * When a sup document is created or updated, send a push notification
 * to the recipient. Enforces rate limiting server-side.
 */
async function handleSupWritten(event) {
  const after = event.data?.after?.data();
  if (!after) return;

  const { fromUid, toUid, timestamp } = after;

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

  const db = getDb();
  const [senderDoc, recipientDoc] = await Promise.all([
    db.collection("users").doc(fromUid).get(),
    db.collection("users").doc(toUid).get(),
  ]);

  const senderName = senderDoc.data()?.username || "someone";
  const deviceToken = recipientDoc.data()?.deviceToken;

  if (!deviceToken) return;

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
    db.collection("users").doc(requestedBy).get(),
    db.collection("users").doc(recipientUid).get(),
  ]);

  const senderName = senderDoc.data()?.username || "someone";
  const deviceToken = recipientDoc.data()?.deviceToken;

  if (!deviceToken) return;

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
}

exports.handleSupWritten = handleSupWritten;
exports.handleFriendRequestCreated = handleFriendRequestCreated;
exports.onSupWritten = onDocumentWritten("sups/{docId}", handleSupWritten);
exports.onFriendRequestCreated = onDocumentCreated("friendships/{docId}", handleFriendRequestCreated);
