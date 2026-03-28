/**
 * Test helpers for mocking Firestore and Messaging.
 */

function createMockDb(usersData = {}) {
  return {
    collection: (name) => ({
      doc: (id) => ({
        get: async () => ({
          data: () => usersData[id] || null,
          exists: !!usersData[id],
        }),
      }),
    }),
  };
}

function createMockMessaging() {
  const sent = [];
  return {
    send: async (msg) => { sent.push(msg); },
    getSent: () => sent,
  };
}

function makeTimestamp(date) {
  return { toDate: () => date };
}

function makeSupEvent({ beforeData, afterData, refSet }) {
  return {
    data: {
      before: beforeData ? { data: () => beforeData } : { data: () => null },
      after: {
        data: () => afterData,
        ref: { set: refSet || jest.fn() },
      },
    },
  };
}

function makeFriendshipEvent(docData) {
  return {
    data: {
      data: () => docData,
    },
  };
}

module.exports = {
  createMockDb,
  createMockMessaging,
  makeTimestamp,
  makeSupEvent,
  makeFriendshipEvent,
};
