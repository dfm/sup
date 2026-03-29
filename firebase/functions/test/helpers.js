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
      where: (field, op, value) => ({
        where: (field2, op2, value2) => ({
          limit: (n) => ({
            get: async () => {
              const col = collections[name] || {};
              const docs = Object.entries(col)
                .filter(([, data]) => {
                  const v = data[field];
                  if (op === ">=" && op2 === "<=") {
                    return v >= value && v <= value2;
                  }
                  return true;
                })
                .slice(0, n)
                .map(([id, data]) => ({
                  id,
                  data: () => data,
                }));
              return { docs };
            },
          }),
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
