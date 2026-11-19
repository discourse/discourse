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

  test("handleSpeakInvitation surfaces actionable toast for invited listener and withdrawn/declined notices", function (assert) {
    const toasts = [];
    const accepted = [];
    const declined = [];
    const room = {
      id: ROOM_ID,
      room_type: "stage",
      can_manage: true,
      active_participants: [{ id: 20, username: "bob", role: "participant" }],
    };

    const handler = new RosterHandler({
      peerManager: { getRoomPeers: () => new Map(), has: () => false },
      presencePending: { has: () => false, clear() {} },
      toasts: {
        default: (opts) => toasts.push({ kind: "default", ...opts }),
        success: (opts) => toasts.push({ kind: "success", ...opts }),
      },
      getCurrentUserId: () => CURRENT_USER_ID,
      getChatSound: () => null,
      getRoom: () => room,
      isActiveRoom: () => false,
      isConnectingRoom: () => false,
      isMeshRoom: () => true,
      getLocalVideoKind: () => null,
      acceptSpeakInvitation: (id) => accepted.push(id),
      declineSpeakInvitation: (id) => declined.push(id),
    });

    handler.handleSpeakInvitation(ROOM_ID, {
      user_id: CURRENT_USER_ID,
      invited: true,
      inviter_username: "mod",
    });

    assert.strictEqual(toasts.length, 1, "shows invitation toast");
    assert.strictEqual(
      toasts[0].data.actions.length,
      2,
      "offers Join the stage and Decline actions"
    );
    toasts[0].data.actions[0].action();
    toasts[0].data.actions[1].action();
    assert.deepEqual(accepted, [ROOM_ID]);
    assert.deepEqual(declined, [ROOM_ID]);

    handler.handleSpeakInvitation(ROOM_ID, {
      user_id: CURRENT_USER_ID,
      invited: false,
      reason: "withdrawn",
    });
    assert.strictEqual(toasts.length, 2, "notifies listener on withdrawal");

    handler.handleSpeakInvitation(ROOM_ID, {
      user_id: 20,
      invited: false,
      reason: "declined",
    });
    assert.strictEqual(
      toasts.length,
      3,
      "notifies moderator when listener declines"
    );
  });

  test("handleRoomTypeChange reconfigures local media for stage <-> open transitions", async function (assert) {
    const toasts = [];
    let micEnabled = true;
    let audioStopped = false;
    let acquiredMic = false;
    const room = {
      id: ROOM_ID,
      room_type: "stage",
      active_participants: [
        { id: CURRENT_USER_ID, username: "alice", role: "participant" },
      ],
    };

    const handler = new RosterHandler({
      peerManager: {
        getRoomPeers: () => new Map(),
        has: () => false,
        destroyRoom() {},
      },
      signaling: { clearForRoom() {}, clearHttpQueue() {} },
      presencePending: { has: () => false, clear() {} },
      toasts: {
        default: (opts) => toasts.push({ kind: "default", ...opts }),
        success: (opts) => toasts.push({ kind: "success", ...opts }),
      },
      getCurrentUserId: () => CURRENT_USER_ID,
      getChatSound: () => null,
      getRoom: () => room,
      isActiveRoom: () => true,
      isConnectingRoom: () => false,
      isMeshRoom: () => true,
      removeAllRemoteStreams() {},
      getLocalVideoKind: () => null,
      stopLocalVideo: async () => {},
      getLocalStream: () => (acquiredMic ? {} : null),
      acquireMicrophone: async () => {
        acquiredMic = true;
        return true;
      },
      setMicEnabled: (enabled) => {
        micEnabled = enabled;
      },
      stopLocalAudio: () => {
        audioStopped = true;
      },
      ensureLocalAudioMonitor() {},
    });

    await handler.handleRoomTypeChange(ROOM_ID, "stage");
    assert.true(
      audioStopped,
      "stops local audio when becoming a stage listener"
    );
    assert.false(micEnabled, "disables mic when becoming a stage listener");
    assert.strictEqual(toasts[0].kind, "default");

    room.room_type = "open";
    await handler.handleRoomTypeChange(ROOM_ID, "open");
    assert.true(acquiredMic, "acquires microphone when room switches to open");
    assert.true(micEnabled, "enables microphone when room switches to open");
    assert.strictEqual(toasts[1].kind, "success");
  });
});
