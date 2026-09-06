import { ajax } from "discourse/lib/ajax";
import LivekitRoomSession from "./livekit-session";

// Owns the livekit sessions for SFU-transport rooms: connecting on join,
// reconnect/teardown on disconnects, and the roster bookkeeping that mesh
// rooms get for free from peer churn.
export default class LivekitCoordinator {
  #sessions = new Map();
  // Last-seen roster ids per livekit room. Mesh derives join/leave sounds and
  // participant cleanup from peer churn; livekit rooms derive both from this
  // roster diff instead.
  #rosterIds = new Map();

  #getCurrentUserId;
  #getParticipantSessionId;
  #onParticipantSessionRenewed;
  #getLocalStream;
  #getLocalVideoTrack;
  #getLocalScreenAudioTrack;
  #getLocalVideoKind;
  #getVideoPublisherCount;
  #getQualityTiers;
  #onTrack;
  #removeRemoteStream;
  #getRemoteUserIds;
  #bumpConnectionRevision;
  #isActiveRoom;
  #isConnectingRoom;
  #isJoinCurrent;
  #leave;
  #unwindFailedJoin;
  #showError;
  #showNotice;

  constructor({
    getCurrentUserId,
    getParticipantSessionId = () => undefined,
    onParticipantSessionRenewed = () => {},
    getLocalStream,
    getLocalVideoTrack,
    getLocalScreenAudioTrack,
    getLocalVideoKind,
    getVideoPublisherCount,
    getQualityTiers,
    onTrack,
    removeRemoteStream,
    getRemoteUserIds,
    bumpConnectionRevision,
    isActiveRoom,
    isConnectingRoom,
    isJoinCurrent,
    leave,
    unwindFailedJoin,
    showError,
    showNotice,
  }) {
    this.#getCurrentUserId = getCurrentUserId;
    this.#getParticipantSessionId = getParticipantSessionId;
    this.#onParticipantSessionRenewed = onParticipantSessionRenewed;
    this.#getLocalStream = getLocalStream;
    this.#getLocalVideoTrack = getLocalVideoTrack;
    this.#getLocalScreenAudioTrack = getLocalScreenAudioTrack;
    this.#getLocalVideoKind = getLocalVideoKind;
    this.#getVideoPublisherCount = getVideoPublisherCount;
    this.#getQualityTiers = getQualityTiers;
    this.#onTrack = onTrack;
    this.#removeRemoteStream = removeRemoteStream;
    this.#getRemoteUserIds = getRemoteUserIds;
    this.#bumpConnectionRevision = bumpConnectionRevision;
    this.#isActiveRoom = isActiveRoom;
    this.#isConnectingRoom = isConnectingRoom;
    this.#isJoinCurrent = isJoinCurrent;
    this.#leave = leave;
    this.#unwindFailedJoin = unwindFailedJoin;
    this.#showError = showError;
    this.#showNotice = showNotice;
  }

  sessionFor(roomId) {
    return this.#sessions.get(roomId);
  }

  disconnectRoom(roomId) {
    this.#rosterIds.delete(roomId);

    const session = this.#sessions.get(roomId);
    if (session) {
      this.#sessions.delete(roomId);
      session.disconnect();
    }
  }

  destroy() {
    this.#sessions.forEach((session) => session.disconnect());
    this.#sessions.clear();
    this.#rosterIds.clear();
  }

  // The server already minted this room's token, so from here a failure is
  // client-side (firewall blocking the SFU, unsupported browser). Follow the
  // mic-failure precedent: tell the server we left, then unwind the local
  // join. Never fall back to mesh client-side — other clients may reach the
  // SFU fine, and a lone mesh joiner would split future joins.
  async connect(room, livekit, revision) {
    let failureMessage = null;

    if (!LivekitRoomSession.isBrowserSupported()) {
      failureMessage = "voice.livekit.browser_unsupported";
    } else if (!livekit?.url || !livekit?.token) {
      failureMessage = "voice.livekit.connect_failed";
    } else {
      const session = this.#buildSession(room.id);
      this.#sessions.set(room.id, session);

      try {
        await session.connect(livekit.url, livekit.token);
      } catch (error) {
        // eslint-disable-next-line no-console
        console.warn(
          `[voice-livekit] failed to connect to the media server for room ${room.id}`,
          error
        );
        failureMessage = error?.unsupportedBrowser
          ? "voice.livekit.browser_unsupported"
          : "voice.livekit.connect_failed";

        if (this.#sessions.get(room.id) === session) {
          this.#sessions.delete(room.id);
        }
        session.disconnect();
      }
    }

    if (failureMessage) {
      ajax(`/voice/rooms/${room.id}/leave`, {
        type: "DELETE",
        data: {
          participant_session_id: this.#getParticipantSessionId(room.id),
        },
      });
      this.#unwindFailedJoin(room.id);
      this.#showError(failureMessage);
      return false;
    }

    if (!this.#isJoinCurrent(revision)) {
      // Superseded while connecting; the superseding join already tore this
      // room down (disconnecting the session), so only the server needs
      // telling.
      ajax(`/voice/rooms/${room.id}/leave`, {
        type: "DELETE",
        data: {
          participant_session_id: this.#getParticipantSessionId(room.id),
        },
      });
      return false;
    }

    return true;
  }

  #buildSession(roomId) {
    return new LivekitRoomSession({
      roomId,
      currentUserId: this.#getCurrentUserId(),
      getLocalStream: this.#getLocalStream,
      getLocalVideoTrack: this.#getLocalVideoTrack,
      getLocalScreenAudioTrack: this.#getLocalScreenAudioTrack,
      getLocalVideoKind: this.#getLocalVideoKind,
      getVideoPublisherCount: () => this.#getVideoPublisherCount(roomId),
      onTrack: (id, userId, track, streams) =>
        this.#onTrack(id, userId, track, streams),
      onParticipantGone: (id, userId) => this.#removeRemoteStream(id, userId),
      onDisconnected: (kind, reason) =>
        this.#handleDisconnected(roomId, kind, reason),
      onConnectionChange: () => this.#bumpConnectionRevision(),
      mintToken: async () => {
        const response = await ajax(`/voice/rooms/${roomId}/livekit_token`, {
          type: "POST",
        });
        // The token endpoint re-establishes presence, so it rotates the
        // participant session heartbeat/state must keep sending.
        this.#onParticipantSessionRenewed(
          roomId,
          response?.participant_session_id
        );
        return response;
      },
      getQualityTiers: () => this.#getQualityTiers(roomId),
    });
  }

  async #handleDisconnected(roomId, kind, reason) {
    const session = this.#sessions.get(roomId);
    if (!session || !this.#isActiveRoom(roomId)) {
      return;
    }

    // eslint-disable-next-line no-console
    console.warn(
      `[voice-livekit] disconnected from the media server for room ${roomId} (${reason})`
    );

    if (kind === "duplicate_identity") {
      // A newer tab for the same user took over the media session. Its join
      // overwrote our session id server-side, so a normal leave would close
      // the new tab's session row and drop the user from the roster —
      // tear down locally only.
      this.#leave(roomId, { skipServer: true });
      this.#showNotice("voice.livekit.duplicate_tab");
      return;
    }

    this.#bumpConnectionRevision();
    const outcome = await session.reconnectWithToken();

    if (outcome === "reconnected") {
      this.#bumpConnectionRevision();
    } else if (outcome === "gone") {
      // The room instance ended while we were disconnected; leave cleanly
      // and offer a rejoin.
      this.#leave(roomId);
      this.#showNotice("voice.livekit.room_ended");
    } else if (outcome === "failed") {
      this.#leave(roomId);
      this.#showError("voice.livekit.reconnect_failed");
    }
    // "aborted": the session was torn down (leave, new join) mid-ladder.
  }

  // Mesh gets participant cleanup for free by destroying peers on the roster
  // diff. The SFU doesn't consult our roster, so a participant expelled from
  // it (heartbeat TTL expiry, kick with a failed server-side eviction) would
  // stay audible forever — voice-canvas plays every stream in
  // `remoteStreams`. Drop registry entries and subscriptions for identities
  // absent from the roster, and derive the join/leave sounds mesh derives
  // from peer churn.
  syncRoster(roomId, participants) {
    const currentUserId = this.#getCurrentUserId();
    const known = this.#rosterIds.get(roomId) || new Set();
    const next = new Set();
    let hasNewPeer = false;
    let hasPeerLeft = false;

    for (const participant of participants) {
      const participantId = Number(participant?.id);
      if (
        !participantId ||
        participantId <= 0 ||
        participantId === currentUserId
      ) {
        continue;
      }

      next.add(participantId);

      // Mirror the mesh rule: the initial roster processed while the join is
      // still connecting represents people already there, not arrivals.
      if (
        !known.has(participantId) &&
        (known.size > 0 || !this.#isConnectingRoom(roomId))
      ) {
        hasNewPeer = true;
      }
    }

    for (const knownId of known) {
      if (!next.has(knownId)) {
        hasPeerLeft = true;
      }
    }

    this.#rosterIds.set(roomId, next);

    const session = this.#sessions.get(roomId);
    for (const entryUserId of this.#getRemoteUserIds(roomId)) {
      if (
        entryUserId &&
        entryUserId !== currentUserId &&
        !next.has(entryUserId)
      ) {
        session?.dropParticipant(entryUserId);
        this.#removeRemoteStream(roomId, entryUserId);
      }
    }

    return { hasNewPeer, hasPeerLeft };
  }

  async replaceAudioTrack(newTrack) {
    for (const [roomId, session] of this.#sessions) {
      try {
        await session.replaceAudioTrack(newTrack);
      } catch (error) {
        // eslint-disable-next-line no-console
        console.warn(
          `[voice-livekit] failed to replace the published audio track for room ${roomId}`,
          error
        );
      }
    }
  }
}
