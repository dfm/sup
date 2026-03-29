/**
 * Test helpers for mocking Firestore and Messaging.
 */

function createMockDb(collections = {}) {
  // collections: { "collectionName": { "docId": { ...data } } }
  return {
    collection: (name) => ({
      doc: (id) => ({
        get: async () => ({
          data: () => (collections[name] && collections[name][id]) || null,
          exists: !!(collections[name] && collections[name][id]),
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

function makeSupEvent({ beforeData, afterData, refSet, refDelete }) {
  return {
    data: {
      before: beforeData ? { data: () => beforeData } : { data: () => null },
      after: {
        data: () => afterData,
        ref: {
          set: refSet || jest.fn(),
          delete: refDelete || jest.fn(),
        },
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
