const { createMockDb, createMockMessaging, makeFriendshipEvent } = require("./helpers");

jest.mock("firebase-admin/app", () => ({ initializeApp: jest.fn() }));
jest.mock("firebase-admin/firestore", () => ({ getFirestore: jest.fn(() => ({})) }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: jest.fn(() => ({})) }));
jest.mock("firebase-functions/v2/firestore", () => ({
  onDocumentWritten: jest.fn((path, handler) => handler),
  onDocumentCreated: jest.fn((path, handler) => handler),
}));

process.env.NODE_ENV = "test";
const functions = require("../index");

describe("onFriendRequestCreated", () => {
  let mockMessaging;

  beforeEach(() => {
    mockMessaging = createMockMessaging();
    functions._setMessaging(mockMessaging);
  });

  test("sends push notification for pending friend request", async () => {
    const mockDb = createMockDb({
      profiles: { alice: { username: "alice" } },
      users: { bob: { deviceToken: "bob-token" } },
    });
    functions._setDb(mockDb);

    const event = makeFriendshipEvent({
      status: "pending",
      requestedBy: "alice",
      users: ["alice", "bob"],
    });

    await functions.handleFriendRequestCreated(event);

    const sent = mockMessaging.getSent();
    expect(sent).toHaveLength(1);
    expect(sent[0].token).toBe("bob-token");
    expect(sent[0].notification.title).toBe("friend request");
    expect(sent[0].notification.body).toBe("alice wants to be friends");
  });

  test("does not send notification for accepted status", async () => {
    const event = makeFriendshipEvent({
      status: "accepted",
      requestedBy: "alice",
      users: ["alice", "bob"],
    });

    await functions.handleFriendRequestCreated(event);

    expect(mockMessaging.getSent()).toHaveLength(0);
  });

  test("does not send notification when recipient has no device token", async () => {
    const mockDb = createMockDb({
      profiles: { alice: { username: "alice" } },
      users: { bob: {} },
    });
    functions._setDb(mockDb);

    const event = makeFriendshipEvent({
      status: "pending",
      requestedBy: "alice",
      users: ["alice", "bob"],
    });

    await functions.handleFriendRequestCreated(event);

    expect(mockMessaging.getSent()).toHaveLength(0);
  });

  test("returns early when event data is null", async () => {
    const event = { data: { data: () => null } };

    await functions.handleFriendRequestCreated(event);

    expect(mockMessaging.getSent()).toHaveLength(0);
  });

  test("uses 'someone' when sender has no username", async () => {
    const mockDb = createMockDb({
      profiles: { alice: {} },
      users: { bob: { deviceToken: "bob-token" } },
    });
    functions._setDb(mockDb);

    const event = makeFriendshipEvent({
      status: "pending",
      requestedBy: "alice",
      users: ["alice", "bob"],
    });

    await functions.handleFriendRequestCreated(event);

    const sent = mockMessaging.getSent();
    expect(sent[0].notification.body).toBe("someone wants to be friends");
  });

  test("correctly identifies recipient when requestedBy is second in array", async () => {
    const mockDb = createMockDb({
      profiles: { bob: { username: "bob" } },
      users: { alice: { deviceToken: "alice-token" } },
    });
    functions._setDb(mockDb);

    const event = makeFriendshipEvent({
      status: "pending",
      requestedBy: "bob",
      users: ["alice", "bob"],
    });

    await functions.handleFriendRequestCreated(event);

    const sent = mockMessaging.getSent();
    expect(sent).toHaveLength(1);
    expect(sent[0].token).toBe("alice-token");
    expect(sent[0].notification.body).toBe("bob wants to be friends");
  });
});
