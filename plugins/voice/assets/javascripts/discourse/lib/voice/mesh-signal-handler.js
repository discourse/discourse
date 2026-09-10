import voiceLog from "discourse/plugins/voice/discourse/lib/voice/logger";
import PeerManager from "./peer-manager";
import { iceUfrag } from "./sdp-utils";
import { participantCanSpeak } from "./stage-roles";

// Handles incoming mesh WebRTC signals (offer/answer/candidate): glare
// resolution, ICE-restart detection, pending-candidate queueing, and the
// policies deciding whether a peer connection should exist at all.
export default class MeshSignalHandler {
  #peerManager;
  #signaling;
  #presencePending;
  #getCurrentUserId;
  #isActiveRoom;
  #getRoom;
  #isRoleChangeInProgress;
  #addProvisionalParticipant;
  #onOfferHandled;

  constructor({
    peerManager,
    signaling,
    presencePending,
    getCurrentUserId,
    isActiveRoom,
    getRoom,
    isRoleChangeInProgress,
    addProvisionalParticipant = () => {},
    onOfferHandled,
  }) {
    this.#peerManager = peerManager;
    this.#signaling = signaling;
    this.#presencePending = presencePending;
    this.#getCurrentUserId = getCurrentUserId;
    this.#isActiveRoom = isActiveRoom;
    this.#getRoom = getRoom;
    this.#isRoleChangeInProgress = isRoleChangeInProgress;
    this.#addProvisionalParticipant = addProvisionalParticipant;
    this.#onOfferHandled = onOfferHandled;
  }

  shouldMaintainPeerConnection(roomId, remoteUserId) {
    if (!this.#isActiveRoom(roomId)) {
      return false;
    }

    const room = this.#getRoom(roomId);
    if (!room) {
      return false;
    }

    const participant = (room.active_participants || []).find(
      (entry) => Number(entry?.id) === Number(remoteUserId)
    );

    if (!participant) {
      return false;
    }

    if (room.room_type !== "stage") {
      return true;
    }

    const iCanSpeak = participantCanSpeak(room, this.#getCurrentUserId());
    const theyCanSpeak =
      participant.role === "moderator" || participant.role === "speaker";

    return iCanSpeak || theyCanSpeak;
  }

  // The relay batches one envelope per recipient (payload.events, in send
  // order); a single-event payload.data is still accepted for compatibility.
  async handle(roomId, payload) {
    const events = Array.isArray(payload.events)
      ? payload.events
      : payload.data
        ? [payload.data]
        : [];

    for (const data of events) {
      await this.#handleEvent(roomId, payload, data);
    }
  }

  // A relayed signal is server-attested proof the sender holds a live
  // participant session in this room: the server only relays for senders who
  // joined and only to recipients still present. The local roster
  // (active_participants) lags behind that relay when two peers join
  // near-simultaneously, so shouldMaintainPeerConnection can still be false at
  // the instant the offer arrives. Gating offers on the local roster silently
  // drops that legitimate first offer and strands the media connection (the
  // sender finishes gathering before we ever engage, so its candidates are
  // never re-sent). Honor early offers in non-stage rooms, where peering does
  // not depend on the sender's presence-derived speaker role. Stage rooms keep
  // strict gating for exactly that reason.
  #canEngageEarlyOffer(roomId) {
    if (!this.#isActiveRoom(roomId)) {
      return false;
    }
    const room = this.#getRoom(roomId);
    return !!room && room.room_type !== "stage";
  }

  // Whether we should set up / keep a peer for a signal of the given type.
  // Falls back to the implicit-presence rule above for offers.
  #shouldEngagePeer(roomId, remoteUserId, signalType) {
    if (this.shouldMaintainPeerConnection(roomId, remoteUserId)) {
      return true;
    }
    return (
      (signalType === "offer" || signalType === "candidate") &&
      this.#canEngageEarlyOffer(roomId)
    );
  }

  async #handleEvent(roomId, payload, data) {
    const remoteUserId = Number(payload.sender_id);

    if (!Number.isFinite(remoteUserId) || remoteUserId <= 0) {
      return;
    }

    if (remoteUserId === this.#getCurrentUserId()) {
      return;
    }

    if (this.#isRoleChangeInProgress(roomId)) {
      return;
    }

    this.#peerManager.clearPeerRestart(roomId, remoteUserId);

    const hadPeer = this.#peerManager.has(roomId, remoteUserId);
    if (!hadPeer && data?.type === "candidate") {
      if (this.#canEngageEarlyOffer(roomId)) {
        this.#peerManager.queuePendingCandidate(
          roomId,
          remoteUserId,
          data.candidate
        );
      }
      return;
    }

    if (!hadPeer && !this.#shouldEngagePeer(roomId, remoteUserId, data?.type)) {
      return;
    }

    voiceLog.info(`[voice] 📥 received signal from peer in room ${roomId}`);
    let pc = await this.#peerManager.create(roomId, remoteUserId);
    if (!pc) {
      return;
    }

    if (!this.#shouldEngagePeer(roomId, remoteUserId, data?.type)) {
      this.#peerManager.destroy(roomId, remoteUserId);
      return;
    }

    if (data.type === "offer") {
      this.#peerManager.clearOfferRetry(roomId, remoteUserId);
      if (!this.shouldMaintainPeerConnection(roomId, remoteUserId)) {
        this.#presencePending.mark(roomId, remoteUserId);
        // Media may flow before the roster broadcast lands; render the
        // server-serialized sender immediately so nobody receives audio while
        // invisible. The next roster broadcast reconciles it.
        if (payload.sender) {
          this.#addProvisionalParticipant(roomId, payload.sender);
        }
      }

      // If the remote restarted its ICE session — it left and rejoined, so its
      // offer carries fresh ICE credentials — renegotiating on the old, dead
      // transport won't recover. Tear the stale peer down and rebuild it so ICE
      // starts clean. Detected by a changed ice-ufrag vs our current remote
      // description; a merely resent offer keeps the same ufrag and is left
      // alone. Skip while mid-glare (have-local-offer), which the block below
      // already resolves.
      if (pc.signalingState !== "have-local-offer") {
        const priorUfrag = iceUfrag(pc.remoteDescription?.sdp);
        const incomingUfrag = iceUfrag(data.sdp);
        if (priorUfrag && incomingUfrag && priorUfrag !== incomingUfrag) {
          voiceLog.info(
            "[voice] remote ICE restart from peer; recreating peer"
          );
          this.#peerManager.destroy(roomId, remoteUserId);
          pc = await this.#peerManager.create(roomId, remoteUserId);
          if (!pc) {
            return;
          }
        }
      }

      if (pc.signalingState === "have-local-offer") {
        if (this.#getCurrentUserId() < remoteUserId) {
          voiceLog.info(
            "[voice] glare detected, rolling back local offer for peer"
          );
          await pc.setLocalDescription({ type: "rollback" });
        } else {
          voiceLog.info(
            "[voice] glare detected, ignoring remote offer from peer"
          );
          return;
        }
      }

      try {
        await pc.setRemoteDescription(new RTCSessionDescription(data));
        const room = this.#getRoom(roomId);
        const canPublish =
          !room || participantCanSpeak(room, this.#getCurrentUserId());
        PeerManager.alignVideoTransceiverForAnswer(pc, { canPublish });
        PeerManager.alignScreenAudioTransceiverForAnswer(pc, { canPublish });
        await this.#peerManager.flushPendingCandidates(
          roomId,
          remoteUserId,
          pc
        );
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        this.#signaling.send(roomId, remoteUserId, answer).catch(() => {
          voiceLog.warn("[voice] failed to send answer");
        });

        await this.#onOfferHandled(roomId);
      } catch {
        voiceLog.warn("[voice] failed to handle offer from peer");
      }
    } else if (data.type === "answer") {
      this.#peerManager.clearOfferRetry(roomId, remoteUserId);

      if (pc.signalingState !== "have-local-offer") {
        voiceLog.warn(
          `[voice] ignoring answer in state ${pc.signalingState} from peer`
        );
        return;
      }

      try {
        await pc.setRemoteDescription(new RTCSessionDescription(data));
        await this.#peerManager.flushPendingCandidates(
          roomId,
          remoteUserId,
          pc
        );
      } catch {
        voiceLog.warn("[voice] failed to handle answer from peer");
      }
    } else if (data.type === "candidate") {
      this.#peerManager.clearOfferRetry(roomId, remoteUserId);

      if (!pc.remoteDescription) {
        this.#peerManager.queuePendingCandidate(
          roomId,
          remoteUserId,
          data.candidate
        );
        return;
      }

      try {
        await pc.addIceCandidate(new RTCIceCandidate(data.candidate));
      } catch {
        voiceLog.warn("[voice] failed to add ICE candidate from peer");
      }
    }
  }
}
