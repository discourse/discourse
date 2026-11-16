import { module, test } from "qunit";
import RosterHandler from "discourse/plugins/live/discourse/lib/live/roster-handler";

const ROOM_ID = 1;
const CURRENT_USER_ID = 10;

function buildHandler({ peerIds }) {
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
    getCurrentUserId: () => CURRENT_USER_ID,
    getChatSound: () => null,
    getRoom: () => ({ id: ROOM_ID, room_type: "standard" }),
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
});
