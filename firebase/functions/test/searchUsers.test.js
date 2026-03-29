const { createMockDb } = require("./helpers");

jest.mock("firebase-admin/app", () => ({ initializeApp: jest.fn() }));
jest.mock("firebase-admin/firestore", () => ({ getFirestore: jest.fn(() => ({})) }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: jest.fn(() => ({})) }));
jest.mock("firebase-functions/v2/firestore", () => ({
  onDocumentWritten: jest.fn((path, handler) => handler),
  onDocumentCreated: jest.fn((path, handler) => handler),
}));
jest.mock("firebase-functions/v2/https", () => ({
  onCall: jest.fn((handler) => handler),
  HttpsError: class HttpsError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  },
}));

process.env.NODE_ENV = "test";
const functions = require("../index");
const { HttpsError } = require("firebase-functions/v2/https");

describe("searchUsers", () => {
  test("returns matching users by username prefix", async () => {
    const mockDb = createMockDb({
      profiles: {
        uid1: { username: "alice", usernameLower: "alice" },
        uid2: { username: "alicia", usernameLower: "alicia" },
        uid3: { username: "bob", usernameLower: "bob" },
      },
    });
    functions._setDb(mockDb);

    const result = await functions.handleSearchUsers({
      auth: { uid: "other" },
      data: { query: "ali" },
    });

    expect(result).toHaveLength(2);
    expect(result.map((r) => r.username)).toEqual(["alice", "alicia"]);
    expect(result.map((r) => r.uid)).toEqual(["uid1", "uid2"]);
  });

  test("excludes the calling user from results", async () => {
    const mockDb = createMockDb({
      profiles: {
        uid1: { username: "alice", usernameLower: "alice" },
      },
    });
    functions._setDb(mockDb);

    const result = await functions.handleSearchUsers({
      auth: { uid: "uid1" },
      data: { query: "ali" },
    });

    expect(result).toHaveLength(0);
  });

  test("throws unauthenticated error when not signed in", async () => {
    await expect(
      functions.handleSearchUsers({ auth: null, data: { query: "ali" } })
    ).rejects.toThrow();
  });

  test("returns empty array for empty query", async () => {
    const result = await functions.handleSearchUsers({
      auth: { uid: "uid1" },
      data: { query: "" },
    });

    expect(result).toEqual([]);
  });

  test("returns empty array for missing query", async () => {
    const result = await functions.handleSearchUsers({
      auth: { uid: "uid1" },
      data: {},
    });

    expect(result).toEqual([]);
  });
});
