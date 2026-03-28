const { createMockDb, createMockMessaging, makeTimestamp, makeSupEvent } = require("./helpers");

// Must mock firebase-admin and firebase-functions before requiring index.js
jest.mock("firebase-admin/app", () => ({ initializeApp: jest.fn() }));
jest.mock("firebase-admin/firestore", () => ({ getFirestore: jest.fn(() => ({})) }));
jest.mock("firebase-admin/messaging", () => ({ getMessaging: jest.fn(() => ({})) }));
jest.mock("firebase-functions/v2/firestore", () => ({
  onDocumentWritten: jest.fn((path, handler) => handler),
  onDocumentCreated: jest.fn((path, handler) => handler),
}));

const functions = require("../index");

describe("onSupWritten", () => {
  let mockMessaging;

  beforeEach(() => {
    mockMessaging = createMockMessaging();
    functions._setMessaging(mockMessaging);
  });

  test("sends push notification on new sup", async () => {
    const mockDb = createMockDb({
      alice: { username: "alice" },
      bob: { deviceToken: "bob-token" },
    });
    functions._setDb(mockDb);

    const event = makeSupEvent({
      beforeData: null,
      afterData: {
        fromUid: "alice",
        toUid: "bob",
        timestamp: makeTimestamp(new Date()),
      },
    });

    await functions.handleSupWritten(event);

    const sent = mockMessaging.getSent();
    expect(sent).toHaveLength(1);
    expect(sent[0].token).toBe("bob-token");
    expect(sent[0].notification.title).toBe("sup");
    expect(sent[0].notification.body).toBe("alice says sup");
  });

  test("does not send notification when recipient has no device token", async () => {
    const mockDb = createMockDb({
      alice: { username: "alice" },
      bob: {},
    });
    functions._setDb(mockDb);

    const event = makeSupEvent({
      beforeData: null,
      afterData: {
        fromUid: "alice",
        toUid: "bob",
        timestamp: makeTimestamp(new Date()),
      },
    });

    await functions.handleSupWritten(event);

    expect(mockMessaging.getSent()).toHaveLength(0);
  });

  test("reverts write when within cooldown period", async () => {
    const mockDb = createMockDb({
      alice: { username: "alice" },
      bob: { deviceToken: "bob-token" },
    });
    functions._setDb(mockDb);

    const now = new Date();
    const thirtySecondsAgo = new Date(now.getTime() - 30_000);

    const beforeData = {
      fromUid: "alice",
      toUid: "bob",
      timestamp: makeTimestamp(thirtySecondsAgo),
    };

    const refSet = jest.fn();
    const event = makeSupEvent({
      beforeData,
      afterData: {
        fromUid: "alice",
        toUid: "bob",
        timestamp: makeTimestamp(now),
      },
      refSet,
    });

    await functions.handleSupWritten(event);

    expect(refSet).toHaveBeenCalledWith(beforeData);
    expect(mockMessaging.getSent()).toHaveLength(0);
  });

  test("sends notification when cooldown has elapsed", async () => {
    const mockDb = createMockDb({
      alice: { username: "alice" },
      bob: { deviceToken: "bob-token" },
    });
    functions._setDb(mockDb);

    const now = new Date();
    const twoMinutesAgo = new Date(now.getTime() - 120_000);

    const event = makeSupEvent({
      beforeData: {
        fromUid: "alice",
        toUid: "bob",
        timestamp: makeTimestamp(twoMinutesAgo),
      },
      afterData: {
        fromUid: "alice",
        toUid: "bob",
        timestamp: makeTimestamp(now),
      },
    });

    await functions.handleSupWritten(event);

    const sent = mockMessaging.getSent();
    expect(sent).toHaveLength(1);
    expect(sent[0].notification.body).toBe("alice says sup");
  });

  test("returns early when after data is null (deletion)", async () => {
    const event = {
      data: {
        before: { data: () => ({}) },
        after: { data: () => null },
      },
    };

    await functions.handleSupWritten(event);
    expect(mockMessaging.getSent()).toHaveLength(0);
  });

  test("uses 'someone' when sender has no username", async () => {
    const mockDb = createMockDb({
      alice: {},
      bob: { deviceToken: "bob-token" },
    });
    functions._setDb(mockDb);

    const event = makeSupEvent({
      beforeData: null,
      afterData: {
        fromUid: "alice",
        toUid: "bob",
        timestamp: makeTimestamp(new Date()),
      },
    });

    await functions.handleSupWritten(event);

    const sent = mockMessaging.getSent();
    expect(sent).toHaveLength(1);
    expect(sent[0].notification.body).toBe("someone says sup");
  });
});
