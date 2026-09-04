// The screen-share audio m-line is pre-negotiated like the video one, but
// both audio transceivers on a connection report kind "audio", so the screen
// one is remembered per connection instead of being inferred from m-line
// order at every lookup.
const screenAudioTransceivers = new WeakMap();

const DEFAULT_TIMING = {
  offerRetryBaseDelayMs: 400,
  maxOfferRetryDelayMs: 5000,
  restartImmediateDelayMs: 200,
  restartDisconnectedDelayMs: 1500,
  maxRestartDelayMs: 5000,
  // A healthy connect completes in ~1s (sub-second once ICE checks start).
  // With a relay-only transport there are no host/srflx fallback candidates,
  // so an initial negotiation race or a slow/failed relay allocation can
  // leave the peer stuck in "new" with nothing to fall back to — this timeout
  // is the only thing that rescues it via a restart. Keep it short so a stall
  // recovers in seconds rather than tens of seconds; the generous headroom
  // over a real connect avoids tearing down a peer that is merely still
  // connecting.
  connectionTimeoutMs: 8000,
};

let timing = DEFAULT_TIMING;

// Tests race these wall-clock delays against their own progress, which flakes
// under CI load; overriding them keeps each test's timers either far out of
// its window or fast enough to await deterministically. Pass null to restore
// the defaults.
export function setPeerTimingForTesting(overrides) {
  timing = overrides ? { ...DEFAULT_TIMING, ...overrides } : DEFAULT_TIMING;
}

export default class PeerManager {
  static #maxRestartAttempts = 5;
  static #maxOfferRetries = 8;

  static peerKey(roomId, userId) {
    return `${roomId}:${userId}`;
  }

  // Prefer the transceiver associated with a negotiated m-line (mid set):
  // on the answerer side the connection can briefly hold two video
  // transceivers — the negotiated one and the unassociated pre-allocated one.
  static videoTransceiverFor(pc) {
    const videoTransceivers = pc
      .getTransceivers()
      .filter((transceiver) => transceiver.receiver?.track?.kind === "video");

    return (
      videoTransceivers.find((transceiver) => transceiver.mid !== null) ??
      videoTransceivers[0]
    );
  }

  static screenAudioTransceiverFor(pc) {
    return screenAudioTransceivers.get(pc) || null;
  }

  // The screen-share audio sender also carries kind "audio"; mic-wide
  // operations (voice quality, device switches) must only touch this one.
  static micSenderFor(pc) {
    const screenAudioSender = PeerManager.screenAudioTransceiverFor(pc)?.sender;
    return (
      pc
        .getSenders()
        .find(
          (sender) =>
            sender.track?.kind === "audio" && sender !== screenAudioSender
        ) ?? null
    );
  }

  // Per JSEP, applying a remote offer only reuses transceivers created via
  // addTrack — never the pre-allocated addTransceiver one — so the answerer
  // gets a fresh recvonly transceiver for the offered video m-line and could
  // never send video back. Called between setRemoteDescription(offer) and
  // createAnswer: flips the associated transceiver to sendrecv (the answer
  // then carries it, no renegotiation) and migrates any track off the now
  // orphaned pre-allocated transceiver.
  // Answerers whose server-side role cannot publish keep the m-line
  // receive-only: defense in depth on top of the receive-side track policy.
  static alignVideoTransceiverForAnswer(pc, { canPublish = true } = {}) {
    const videoTransceivers = pc
      .getTransceivers()
      .filter((transceiver) => transceiver.receiver?.track?.kind === "video");

    const associated = videoTransceivers.find(
      (transceiver) => transceiver.mid !== null
    );
    if (!associated) {
      return;
    }

    const direction = canPublish ? "sendrecv" : "recvonly";
    if (associated.direction !== direction) {
      associated.direction = direction;
    }

    const orphan = videoTransceivers.find(
      (transceiver) => transceiver !== associated && transceiver.mid === null
    );
    const orphanTrack = orphan?.sender?.track;
    if (orphanTrack && !associated.sender.track) {
      associated.sender.replaceTrack(orphanTrack).catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to migrate video track", error);
      });
      orphan.sender.replaceTrack(null).catch(() => {});
    }
  }

  // Same JSEP problem as the video m-line, for the screen-audio one: the
  // answerer's pre-allocated transceiver is never reused, so the negotiated
  // transceiver must be flipped to sendrecv and adopted as the screen-audio
  // slot. The mic m-line always precedes the screen-audio m-line (the mic
  // track is added before the pre-allocated transceivers, and fresh answerer
  // transceivers are created in m-line order), so among the audio
  // transceivers associated with an m-line the screen one is the last.
  static alignScreenAudioTransceiverForAnswer(pc, { canPublish = true } = {}) {
    const associated = pc
      .getTransceivers()
      .filter(
        (transceiver) =>
          transceiver.receiver?.track?.kind === "audio" &&
          transceiver.mid !== null
      );

    // A single audio m-line means the remote is an older client that doesn't
    // negotiate screen audio; leave the pre-allocated transceiver idle.
    if (associated.length < 2) {
      return;
    }

    const screenTransceiver = associated[associated.length - 1];
    const direction = canPublish ? "sendrecv" : "recvonly";
    if (screenTransceiver.direction !== direction) {
      screenTransceiver.direction = direction;
    }

    const orphan = screenAudioTransceivers.get(pc);
    if (orphan && orphan !== screenTransceiver) {
      const orphanTrack = orphan.sender?.track;
      if (orphanTrack && !screenTransceiver.sender.track) {
        screenTransceiver.sender.replaceTrack(orphanTrack).catch((error) => {
          // eslint-disable-next-line no-console
          console.warn("[voice] failed to migrate screen audio track", error);
        });
        orphan.sender.replaceTrack(null).catch(() => {});
      }
    }

    screenAudioTransceivers.set(pc, screenTransceiver);
  }

  #peerConnections = new Map();
  #destroyed = false;
  #offerRetryTimers = new Map();
  #offerRetryAttempts = new Map();
  #peerReconnectTimers = new Map();
  #restartAttempts = new Map();
  #connectionTimeouts = new Map();
  #pendingCandidates = new Map();

  #getIceServers;
  #getIceTransportPolicy;
  #canPublishMedia;
  #getLocalStream;
  #getLocalVideoTrack;
  #getLocalScreenAudioTrack;
  #sendSignal;
  #flushQueuedSignals;
  #onTrack;
  #clearSignalQueue;
  #onPeerDestroyed;
  #onPeerConnected;
  #shouldRestartPeer;

  constructor({
    getIceServers,
    getIceTransportPolicy = () => "all",
    canPublishMedia = () => true,
    getLocalStream,
    getLocalVideoTrack = () => null,
    getLocalScreenAudioTrack = () => null,
    sendSignal,
    flushQueuedSignals,
    onTrack,
    clearSignalQueue,
    onPeerDestroyed,
    onPeerConnected = () => {},
    shouldRestartPeer = () => true,
  }) {
    this.#getIceServers = getIceServers;
    this.#getIceTransportPolicy = getIceTransportPolicy;
    this.#canPublishMedia = canPublishMedia;
    this.#getLocalStream = getLocalStream;
    this.#getLocalVideoTrack = getLocalVideoTrack;
    this.#getLocalScreenAudioTrack = getLocalScreenAudioTrack;
    this.#sendSignal = sendSignal;
    this.#flushQueuedSignals = flushQueuedSignals;
    this.#onTrack = onTrack;
    this.#clearSignalQueue = clearSignalQueue;
    this.#onPeerDestroyed = onPeerDestroyed;
    this.#onPeerConnected = onPeerConnected;
    this.#shouldRestartPeer = shouldRestartPeer;
  }

  has(roomId, userId) {
    const peers = this.#peerConnections.get(roomId);
    return peers?.has(userId) ?? false;
  }

  get(roomId, userId) {
    return this.#peerConnections.get(roomId)?.get(userId);
  }

  getRoomPeers(roomId) {
    return this.#peerConnections.get(roomId);
  }

  remoteVideoTrack(roomId, userId) {
    const pc = this.get(roomId, userId);
    if (!pc) {
      return null;
    }

    return PeerManager.videoTransceiverFor(pc)?.receiver?.track || null;
  }

  allPeerConnections() {
    return this.#peerConnections;
  }

  micSendersFor(roomId) {
    const senders = [];
    for (const [, pc] of this.#peerConnections.get(roomId) || []) {
      const sender = PeerManager.micSenderFor(pc);
      if (sender?.track) {
        senders.push(sender);
      }
    }
    return senders;
  }

  async replaceMicTrack(newTrack) {
    for (const [, peers] of this.#peerConnections) {
      for (const [, pc] of peers) {
        const sender = PeerManager.micSenderFor(pc);
        if (sender) {
          try {
            await sender.replaceTrack(newTrack);
          } catch (error) {
            // eslint-disable-next-line no-console
            console.warn("[voice] failed to replace track on peer", error);
          }
        }
      }
    }
  }

  async create(roomId, remoteUserId) {
    if (this.#destroyed) {
      return null;
    }

    let roomPeers = this.#peerConnections.get(roomId);
    if (!roomPeers) {
      roomPeers = new Map();
      this.#peerConnections.set(roomId, roomPeers);
    }

    if (roomPeers.has(remoteUserId)) {
      return roomPeers.get(remoteUserId);
    }

    const pc = new RTCPeerConnection({
      iceServers: this.#getIceServers(),
      iceTransportPolicy: this.#getIceTransportPolicy(),
    });
    roomPeers.set(remoteUserId, pc);

    const localStream = this.#getLocalStream();
    if (localStream) {
      for (const track of localStream.getTracks()) {
        pc.addTrack(track, localStream);
      }
    }

    // The video m-line is negotiated up-front so that turning a camera or
    // screen share on later is a plain replaceTrack with no renegotiation —
    // the signaling layer only supports one-shot negotiation at peer setup.
    // An idle sender transmits nothing. When the local role cannot publish
    // (stage listener) the m-line is receive-only; a promotion rebuilds all
    // peers, so the direction never needs to change on a live connection.
    const canPublish = this.#canPublishMedia(roomId);
    const videoTransceiver = pc.addTransceiver("video", {
      direction: canPublish ? "sendrecv" : "recvonly",
    });
    const videoTrack = this.#getLocalVideoTrack(roomId, remoteUserId);
    if (videoTrack) {
      videoTransceiver.sender.replaceTrack(videoTrack).catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to attach video track", error);
      });
    }

    // A second audio m-line, pre-negotiated for the same reason as video,
    // carries tab/system audio during a screen share. It stays separate from
    // the mic m-line so voice mute/PTT and receiver-side speaking detection
    // never touch content audio.
    const screenAudioTransceiver = pc.addTransceiver("audio", {
      direction: canPublish ? "sendrecv" : "recvonly",
    });
    screenAudioTransceivers.set(pc, screenAudioTransceiver);
    const screenAudioTrack = this.#getLocalScreenAudioTrack(
      roomId,
      remoteUserId
    );
    if (screenAudioTrack) {
      screenAudioTransceiver.sender
        .replaceTrack(screenAudioTrack)
        .catch((error) => {
          // eslint-disable-next-line no-console
          console.warn("[voice] failed to attach screen audio track", error);
        });
    }

    pc.ontrack = (event) => {
      this.#onTrack(roomId, remoteUserId, event.track, event.streams);
    };

    pc.onicecandidate = (event) => {
      if (event.candidate) {
        const candidatePayload =
          typeof event.candidate.toJSON === "function"
            ? event.candidate.toJSON()
            : {
                candidate: event.candidate.candidate,
                sdpMid: event.candidate.sdpMid,
                sdpMLineIndex: event.candidate.sdpMLineIndex,
                usernameFragment: event.candidate.usernameFragment,
              };

        this.#sendSignal(roomId, remoteUserId, {
          type: "candidate",
          candidate: candidatePayload,
        }).catch((error) => {
          // eslint-disable-next-line no-console
          console.warn("[voice] failed to send candidate", error);
        });
      } else {
        this.#flushQueuedSignals(roomId, remoteUserId).catch((error) => {
          // eslint-disable-next-line no-console
          console.warn("[voice] failed to flush signal queue", error);
        });
      }
    };

    pc.onicegatheringstatechange = () => {
      if (pc.iceGatheringState === "complete") {
        this.#flushQueuedSignals(roomId, remoteUserId).catch((error) => {
          // eslint-disable-next-line no-console
          console.warn("[voice] failed to flush signal queue", error);
        });
      }
    };

    pc.onicecandidateerror = (event) => {
      // eslint-disable-next-line no-console
      console.warn(
        `[voice] ICE candidate error for user ${remoteUserId}`,
        event
      );
    };

    pc.onconnectionstatechange = () => {
      // eslint-disable-next-line no-console
      console.log(
        `[voice] connectionState ${pc.connectionState} for user ${remoteUserId}`
      );
      if (pc.connectionState === "connected") {
        this.#clearOfferRetry(roomId, remoteUserId);
        this.#clearPeerRestart(roomId, remoteUserId);
        this.#clearConnectionTimeout(roomId, remoteUserId);
        this.#onPeerConnected(roomId, remoteUserId, pc);
        return;
      }

      if (pc.connectionState === "failed") {
        this.#clearOfferRetry(roomId, remoteUserId);
        this.#clearConnectionTimeout(roomId, remoteUserId);
        this.#schedulePeerRestart(roomId, remoteUserId, { immediate: true });
        return;
      }

      if (pc.connectionState === "disconnected") {
        this.#schedulePeerRestart(roomId, remoteUserId);
        return;
      }

      if (pc.connectionState === "closed") {
        this.destroy(roomId, remoteUserId, { closeConnection: false });
      }
    };

    pc.oniceconnectionstatechange = () => {
      // eslint-disable-next-line no-console
      console.log(
        `[voice] iceConnectionState ${pc.iceConnectionState} for user ${remoteUserId}`
      );
      if (pc.iceConnectionState === "failed") {
        this.#schedulePeerRestart(roomId, remoteUserId, { immediate: true });
      } else if (pc.iceConnectionState === "disconnected") {
        this.#schedulePeerRestart(roomId, remoteUserId);
      }
    };

    this.#startConnectionTimeout(roomId, remoteUserId, pc);

    return pc;
  }

  destroy(
    roomId,
    remoteUserId,
    { resetRestartAttempts = true, closeConnection = true } = {}
  ) {
    const peers = this.#peerConnections.get(roomId);
    const pc = peers?.get(remoteUserId);

    if (pc) {
      pc.ontrack = null;
      pc.onicecandidate = null;
      pc.onconnectionstatechange = null;
      pc.oniceconnectionstatechange = null;
      pc.onicegatheringstatechange = null;
      pc.onicecandidateerror = null;

      if (closeConnection) {
        try {
          pc.close();
        } catch {
          // ignore close errors
        }
      }

      peers.delete(remoteUserId);
    }

    this.#clearOfferRetry(roomId, remoteUserId);
    if (resetRestartAttempts) {
      this.#clearPeerRestart(roomId, remoteUserId);
    } else {
      this.#clearPeerRestartTimer(roomId, remoteUserId);
    }
    this.#clearConnectionTimeout(roomId, remoteUserId);
    this.#clearPendingCandidates(roomId, remoteUserId);
    this.#clearSignalQueue(roomId, remoteUserId);
    this.#onPeerDestroyed(roomId, remoteUserId);
  }

  destroyRoom(roomId) {
    const peers = this.#peerConnections.get(roomId);
    if (peers) {
      Array.from(peers.keys()).forEach((remoteUserId) => {
        this.destroy(roomId, remoteUserId);
      });
      this.#peerConnections.delete(roomId);
    }
  }

  async initiateOffer(roomId, remoteUserId) {
    const peers = this.#peerConnections.get(roomId);
    const pc = peers?.get(remoteUserId);

    if (!pc) {
      return;
    }

    if (pc.signalingState !== "stable") {
      // An inbound offer/answer is already mid-flight on this peer; the
      // inbound handler will drive negotiation. The connection timeout in
      // #startConnectionTimeout is the safety net if it stalls.
      // eslint-disable-next-line no-console
      console.log(
        `[voice] skipping offer for user ${remoteUserId}: signalingState=${pc.signalingState}`
      );
      return;
    }

    try {
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      this.#sendSignal(roomId, remoteUserId, offer).catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to send offer", error);
      });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn("[voice] failed to create offer", error);
    }
  }

  scheduleOfferRetry(roomId, remoteUserId, delay = null) {
    const key = PeerManager.peerKey(roomId, remoteUserId);

    if (this.#destroyed || this.#offerRetryTimers.has(key)) {
      return;
    }

    delay ??= timing.offerRetryBaseDelayMs;

    const attempts = this.#offerRetryAttempts.get(key) || 0;

    if (attempts >= PeerManager.#maxOfferRetries) {
      // eslint-disable-next-line no-console
      console.warn(
        `[voice] max offer retries (${PeerManager.#maxOfferRetries}) reached for user ${remoteUserId}`
      );
      return;
    }

    const actualDelay = Math.min(
      delay * Math.pow(2, attempts),
      timing.maxOfferRetryDelayMs
    );

    // eslint-disable-next-line no-console
    console.log(
      `[voice] scheduling offer retry for user ${remoteUserId} (attempt ${attempts + 1}/${PeerManager.#maxOfferRetries}, delay ${actualDelay}ms)`
    );

    const timer = setTimeout(async () => {
      this.#offerRetryTimers.delete(key);
      this.#offerRetryAttempts.set(key, attempts + 1);
      await this.initiateOffer(roomId, remoteUserId);
    }, actualDelay);

    this.#offerRetryTimers.set(key, timer);
  }

  clearOfferRetry(roomId, remoteUserId) {
    this.#clearOfferRetry(roomId, remoteUserId);
  }

  clearPeerRestart(roomId, remoteUserId) {
    this.#clearPeerRestart(roomId, remoteUserId);
  }

  queuePendingCandidate(roomId, remoteUserId, candidate) {
    const key = PeerManager.peerKey(roomId, remoteUserId);
    const queue = this.#pendingCandidates.get(key) || [];
    queue.push(candidate);
    this.#pendingCandidates.set(key, queue);
    // eslint-disable-next-line no-console
    console.log(
      `[voice] queued ICE candidate for user ${remoteUserId} (${queue.length} pending)`
    );
  }

  async flushPendingCandidates(roomId, remoteUserId, pc) {
    const key = PeerManager.peerKey(roomId, remoteUserId);
    const candidates = this.#pendingCandidates.get(key);

    if (!candidates?.length) {
      return;
    }

    this.#pendingCandidates.delete(key);
    // eslint-disable-next-line no-console
    console.log(
      `[voice] flushing ${candidates.length} queued ICE candidates for user ${remoteUserId}`
    );

    for (const candidate of candidates) {
      try {
        await pc.addIceCandidate(new RTCIceCandidate(candidate));
      } catch (error) {
        // eslint-disable-next-line no-console
        console.warn(
          `[voice] failed to add queued ICE candidate for user ${remoteUserId}`,
          error
        );
      }
    }
  }

  async restart(roomId, remoteUserId) {
    if (this.#destroyed) {
      return;
    }

    if (!this.#shouldRestartPeer(roomId, remoteUserId)) {
      this.#clearPeerRestart(roomId, remoteUserId);
      return;
    }

    this.destroy(roomId, remoteUserId, { resetRestartAttempts: false });

    await this.create(roomId, remoteUserId);

    if (!this.#shouldRestartPeer(roomId, remoteUserId)) {
      this.destroy(roomId, remoteUserId);
      return;
    }

    await this.initiateOffer(roomId, remoteUserId);
  }

  // Terminal: the manager schedules no further timers and creates no further
  // connections afterwards, so in-flight async (a restart mid-await, a late
  // retry) lands on a no-op instead of resurrecting state.
  destroyAll() {
    this.#destroyed = true;

    for (const [roomId, peers] of this.#peerConnections) {
      for (const remoteUserId of Array.from(peers.keys())) {
        this.destroy(roomId, remoteUserId);
      }
    }
    this.#peerConnections.clear();

    this.#peerReconnectTimers.forEach((timer) => clearTimeout(timer));
    this.#peerReconnectTimers.clear();
    this.#offerRetryTimers.forEach((timer) => clearTimeout(timer));
    this.#offerRetryTimers.clear();
    this.#offerRetryAttempts.clear();
    this.#restartAttempts.clear();
    this.#connectionTimeouts.forEach((timer) => clearTimeout(timer));
    this.#connectionTimeouts.clear();
    this.#pendingCandidates.clear();
  }

  // --- private ---

  #startConnectionTimeout(roomId, remoteUserId, pc) {
    const key = PeerManager.peerKey(roomId, remoteUserId);

    if (this.#destroyed || this.#connectionTimeouts.has(key)) {
      return;
    }

    const timer = setTimeout(() => {
      this.#connectionTimeouts.delete(key);

      // Only rescue a peer that never started ICE (still "new" — e.g. a
      // relay-only transport whose relay allocation produced no candidate).
      // A peer in "connecting"/"checking" is mid-negotiation and may simply
      // need more time (relay-to-relay checks can take >10s); restarting it
      // here throws away progress and re-floods signaling, which can trip
      // rate limits and turn a slow connect into an endless restart storm.
      // ICE's own failure detection (oniceconnectionstatechange -> "failed")
      // and the disconnected/failed handlers restart those if checks truly
      // fail, so they are covered without an app-level teardown.
      if (pc.connectionState === "new") {
        // eslint-disable-next-line no-console
        console.warn(
          `[voice] connection stuck in "new" (${timing.connectionTimeoutMs}ms) for user ${remoteUserId}; restarting`
        );
        this.#schedulePeerRestart(roomId, remoteUserId, { immediate: true });
      }
    }, timing.connectionTimeoutMs);

    this.#connectionTimeouts.set(key, timer);
  }

  #clearConnectionTimeout(roomId, remoteUserId) {
    const key = PeerManager.peerKey(roomId, remoteUserId);
    const timer = this.#connectionTimeouts.get(key);

    if (timer) {
      clearTimeout(timer);
      this.#connectionTimeouts.delete(key);
    }
  }

  #clearOfferRetry(roomId, remoteUserId) {
    const key = PeerManager.peerKey(roomId, remoteUserId);
    const timer = this.#offerRetryTimers.get(key);

    if (timer) {
      clearTimeout(timer);
      this.#offerRetryTimers.delete(key);
    }

    this.#offerRetryAttempts.delete(key);
  }

  #schedulePeerRestart(roomId, remoteUserId, options = {}) {
    const key = PeerManager.peerKey(roomId, remoteUserId);

    if (this.#destroyed || this.#peerReconnectTimers.has(key)) {
      return;
    }

    const attempts = this.#restartAttempts.get(key) || 0;

    if (attempts >= PeerManager.#maxRestartAttempts) {
      // eslint-disable-next-line no-console
      console.warn(
        `[voice] max restart attempts (${PeerManager.#maxRestartAttempts}) reached for user ${remoteUserId}`
      );
      return;
    }

    const baseDelay = options.immediate
      ? timing.restartImmediateDelayMs
      : timing.restartDisconnectedDelayMs;
    const delay = Math.min(
      baseDelay * Math.pow(2, attempts),
      timing.maxRestartDelayMs
    );

    // eslint-disable-next-line no-console
    console.log(
      `[voice] scheduling peer restart for user ${remoteUserId} (attempt ${attempts + 1}/${PeerManager.#maxRestartAttempts}, delay ${delay}ms)`
    );

    const timer = setTimeout(() => {
      this.#peerReconnectTimers.delete(key);
      this.#restartAttempts.set(key, attempts + 1);
      this.restart(roomId, remoteUserId).catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to restart peer connection", error);
      });
    }, delay);

    this.#peerReconnectTimers.set(key, timer);
  }

  #clearPeerRestart(roomId, remoteUserId) {
    this.#clearPeerRestartTimer(roomId, remoteUserId);
    this.#restartAttempts.delete(PeerManager.peerKey(roomId, remoteUserId));
  }

  #clearPeerRestartTimer(roomId, remoteUserId) {
    const key = PeerManager.peerKey(roomId, remoteUserId);
    const timer = this.#peerReconnectTimers.get(key);

    if (timer) {
      clearTimeout(timer);
      this.#peerReconnectTimers.delete(key);
    }
  }

  #clearPendingCandidates(roomId, remoteUserId) {
    const key = PeerManager.peerKey(roomId, remoteUserId);
    this.#pendingCandidates.delete(key);
  }
}
