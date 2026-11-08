import { module, test } from "qunit";
import RosterHandler from "discourse/plugins/live/discourse/lib/live/roster-handler";

const ROOM_ID = 1;
const CURRENT_USER_ID = 10;

function buildHandler({ peerIds = [], room, toasts } = {}) {
  const peers = new Map(peerIds.map((id) => [id, {}]));
  const destroyed = [];

  const handler = new RosterHandler({
    peerManager: {
      getRoomPeers: () => peers,
      has: (_roomId, userId) => peers.has(userId),
      destroy: (_roomId, userId) => {
        destroyed.push(userId);
        peers.delete(userId);
      },
      remoteVideoTrack: () => null,
    },
    presencePending: { has: () => false, clear() {} },
    toasts,
    getCurrentUserId: () => CURRENT_USER_ID,
    getChatSound: () => null,
    getRoom: () => room ?? { id: ROOM_ID, room_type: "standard" },
    isActiveRoom: () => false,
    isConnectingRoom: () => false,
    isMeshRoom: () => true,
    getLocalVideoKind: () => null,
  });

  return { handler, destroyed };
}

module("Live | Unit | Lib | roster-handler", function () {
  test("keeps mesh peers the server marks as resuming", async function (assert) {
    const { handler, destroyed } = buildHandler({ peerIds: [20, 30] });

    await handler.handleParticipants(ROOM_ID, {
      participants: [{ id: CURRENT_USER_ID }],
      resuming_ids: [20],
    });

    assert.deepEqual(destroyed, [30], "only the departed peer is destroyed");
  });

  test("destroys peers absent from the roster when nothing is resuming", async function (assert) {
    const { handler, destroyed } = buildHandler({ peerIds: [20] });

    await handler.handleParticipants(ROOM_ID, {
      participants: [{ id: CURRENT_USER_ID }],
    });

    assert.deepEqual(destroyed, [20]);
  });

  module("speak invitations", function (hooks) {
    let messages;
    let toasts;
    const stageRoom = {
      id: ROOM_ID,
      room_type: "stage",
      can_manage: true,
      active_participants: [{ id: 20, username: "bob" }],
    };

    hooks.beforeEach(function () {
      messages = [];
      toasts = { default: ({ data }) => messages.push(data.message) };
    });

    test("tells the invited listener", function (assert) {
      const { handler } = buildHandler({ room: stageRoom, toasts });

      handler.handleSpeakInvitation(ROOM_ID, {
        user_id: CURRENT_USER_ID,
        invited: true,
        reason: "invited",
      });

      assert.strictEqual(messages.length, 1, "shows one toast");
    });

    test("tells a moderator when the invitation is declined", function (assert) {
      const { handler } = buildHandler({ room: stageRoom, toasts });

      handler.handleSpeakInvitation(ROOM_ID, {
        user_id: 20,
        invited: false,
        reason: "declined",
      });

      assert.strictEqual(messages.length, 1, "shows one toast");
      assert.true(messages[0].includes("bob"), "names the participant");
    });

    test("stays quiet for other people's invitations and for non-moderators", function (assert) {
      const { handler } = buildHandler({ room: stageRoom, toasts });
      handler.handleSpeakInvitation(ROOM_ID, {
        user_id: 20,
        invited: true,
        reason: "invited",
      });
      handler.handleSpeakInvitation(ROOM_ID, {
        user_id: 20,
        invited: false,
        reason: "accepted",
      });

      const { handler: listenerHandler } = buildHandler({
        room: { ...stageRoom, can_manage: false },
        toasts,
      });
      listenerHandler.handleSpeakInvitation(ROOM_ID, {
        user_id: 20,
        invited: false,
        reason: "declined",
      });

      assert.deepEqual(messages, []);
    });
  });
});
