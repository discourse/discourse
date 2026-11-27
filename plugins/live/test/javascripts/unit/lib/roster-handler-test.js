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
    assert.false(
      acquiredMic,
      "does not capture the microphone when the room switches to open"
    );
    assert.false(micEnabled, "keeps the listener muted");
    assert.strictEqual(toasts[1].kind, "success");

    assert.true(
      await handler.acquireDeferredMicrophone(ROOM_ID),
      "reports the microphone as available"
    );
    assert.true(acquiredMic, "captures the microphone on an explicit unmute");
    assert.true(micEnabled, "enables the microphone on an explicit unmute");
    assert.strictEqual(toasts.length, 2, "shows no further toast");
  });

  test("handleSpeakInvitation leaves the invite to the room page banner", function (assert) {
    const toasts = [];
    let showingRoomPage = true;

    const handler = new RosterHandler({
      peerManager: { getRoomPeers: () => new Map(), has: () => false },
      presencePending: { has: () => false, clear() {} },
      toasts: { default: (opts) => toasts.push(opts) },
      getCurrentUserId: () => CURRENT_USER_ID,
      getChatSound: () => null,
      getRoom: () => ({ id: ROOM_ID, room_type: "stage" }),
      isActiveRoom: () => false,
      isConnectingRoom: () => false,
      isShowingRoomPage: () => showingRoomPage,
      isMeshRoom: () => true,
      getLocalVideoKind: () => null,
    });
    const invitation = {
      user_id: CURRENT_USER_ID,
      invited: true,
      inviter_username: "mod",
    };

    handler.handleSpeakInvitation(ROOM_ID, invitation);
    assert.strictEqual(toasts.length, 0, "no toast on the room page");

    showingRoomPage = false;
    handler.handleSpeakInvitation(ROOM_ID, invitation);
    assert.strictEqual(toasts.length, 1, "toasts when only the widget is open");
  });

  test("acquireDeferredMicrophone leaves existing mesh peers untouched when capture fails", async function (assert) {
    let destroyedRoom = false;
    let removedStreams = false;

    const handler = new RosterHandler({
      peerManager: {
        getRoomPeers: () => new Map([[20, {}]]),
        has: () => true,
        destroyRoom() {
          destroyedRoom = true;
        },
      },
      signaling: { clearForRoom() {}, clearHttpQueue() {} },
      presencePending: { has: () => false, clear() {} },
      getCurrentUserId: () => CURRENT_USER_ID,
      getChatSound: () => null,
      getRoom: () => ({
        id: ROOM_ID,
        room_type: "open",
        active_participants: [
          { id: CURRENT_USER_ID, role: "participant" },
          { id: 20, role: "participant" },
        ],
      }),
      isActiveRoom: () => true,
      isConnectingRoom: () => false,
      isMeshRoom: () => true,
      removeAllRemoteStreams() {
        removedStreams = true;
      },
      getLocalVideoKind: () => null,
      getLocalStream: () => null,
      acquireMicrophone: async () => false,
      setMicEnabled() {},
      stopLocalAudio() {},
      ensureLocalAudioMonitor() {},
    });

    assert.false(
      await handler.acquireDeferredMicrophone(ROOM_ID),
      "reports failure when microphone capture is denied or unavailable"
    );
    assert.false(destroyedRoom, "does not tear down working peer connections");
    assert.false(removedStreams, "does not drop active remote audio streams");
  });

  test("acquireDeferredMicrophone immediately initiates offers even to lower-id peers on success", async function (assert) {
    let localStream = null;
    const offered = [];
    const created = [];
    const scheduledRetries = [];

    const handler = new RosterHandler({
      peerManager: {
        getRoomPeers: () => new Map(),
        has: () => false,
        destroyRoom() {},
        create: async (_roomId, userId) => {
          created.push(userId);
        },
        initiateOffer: async (_roomId, userId) => {
          offered.push(userId);
        },
        scheduleOfferRetry: (_roomId, userId) => {
          scheduledRetries.push(userId);
        },
      },
      signaling: { clearForRoom() {}, clearHttpQueue() {} },
      presencePending: { has: () => false, clear() {} },
      getCurrentUserId: () => 50,
      getChatSound: () => null,
      getRoom: () => ({
        id: ROOM_ID,
        room_type: "open",
        active_participants: [
          { id: 50, role: "participant" },
          { id: 2, role: "participant" },
        ],
      }),
      isActiveRoom: () => true,
      isConnectingRoom: () => false,
      isMeshRoom: () => true,
      removeAllRemoteStreams() {},
      getLocalVideoKind: () => null,
      getLocalStream: () => localStream,
      acquireMicrophone: async () => {
        localStream = { id: "mic" };
        return true;
      },
      setMicEnabled() {},
      stopLocalAudio() {},
      ensureLocalAudioMonitor() {},
    });

    assert.true(await handler.acquireDeferredMicrophone(ROOM_ID));
    await Promise.resolve();
    assert.deepEqual(created, [2], "rebuilds the peer connection");
    assert.deepEqual(
      offered,
      [2],
      "immediately sends a fresh offer to the lower-id peer"
    );
    assert.deepEqual(
      scheduledRetries,
      [],
      "does not wait on an offer retry timer"
    );
  });

  test("acquireDeferredMicrophone stops captured audio if the user left while prompting", async function (assert) {
    let active = true;
    let stopped = false;
    let micEnabled = true;
    let destroyedRoom = false;

    const handler = new RosterHandler({
      peerManager: {
        getRoomPeers: () => new Map(),
        has: () => false,
        destroyRoom() {
          destroyedRoom = true;
        },
      },
      signaling: { clearForRoom() {}, clearHttpQueue() {} },
      presencePending: { has: () => false, clear() {} },
      getCurrentUserId: () => CURRENT_USER_ID,
      getChatSound: () => null,
      getRoom: () => ({ id: ROOM_ID, room_type: "open" }),
      isActiveRoom: () => active,
      isConnectingRoom: () => false,
      isMeshRoom: () => true,
      removeAllRemoteStreams() {},
      getLocalVideoKind: () => null,
      getLocalStream: () => null,
      acquireMicrophone: async () => {
        active = false;
        return true;
      },
      setMicEnabled: (enabled) => {
        micEnabled = enabled;
      },
      stopLocalAudio: () => {
        stopped = true;
      },
      ensureLocalAudioMonitor() {},
    });

    assert.false(await handler.acquireDeferredMicrophone(ROOM_ID));
    assert.true(stopped, "releases the freshly captured microphone");
    assert.false(micEnabled, "keeps microphone state disabled");
    assert.false(destroyedRoom, "does not reconnect peers for a left room");
  });

  test("handleRoleChange keeps mesh peers connected muted when mic acquisition fails on promotion", async function (assert) {
    let micEnabled = true;
    const recreated = [];
    const toasts = [];
    const room = {
      id: ROOM_ID,
      room_type: "stage",
      active_participants: [
        { id: CURRENT_USER_ID, role: "speaker" },
        { id: 20, role: "moderator" },
      ],
    };

    const handler = new RosterHandler({
      peerManager: {
        getRoomPeers: () => new Map(),
        has: () => false,
        destroyRoom() {},
        create: async (_roomId, userId) => {
          recreated.push(userId);
        },
        initiateOffer: async () => {},
        scheduleOfferRetry() {},
      },
      signaling: { clearForRoom() {}, clearHttpQueue() {} },
      presencePending: { has: () => false, clear() {} },
      toasts: {
        default: (opts) => toasts.push(opts),
        success: (opts) => toasts.push(opts),
      },
      getCurrentUserId: () => CURRENT_USER_ID,
      getChatSound: () => null,
      getRoom: () => room,
      isActiveRoom: () => true,
      isConnectingRoom: () => false,
      isMeshRoom: () => true,
      removeAllRemoteStreams() {},
      getLocalVideoKind: () => null,
      getLocalStream: () => null,
      acquireMicrophone: async () => false,
      setMicEnabled: (enabled) => {
        micEnabled = enabled;
      },
      stopLocalAudio() {},
      ensureLocalAudioMonitor() {},
    });

    await handler.handleRoleChange(ROOM_ID, {
      user_id: CURRENT_USER_ID,
      role: "speaker",
    });

    assert.false(
      handler.isRoleChangeInProgress(ROOM_ID),
      "clears the role-change lock"
    );
    assert.false(micEnabled, "keeps the promoted speaker muted");
    assert.deepEqual(
      recreated,
      [20],
      "reconnects peers so the promoted speaker stays in the call"
    );
  });
});
