import { i18n } from "discourse-i18n";
import {
  playUserJoinedSound,
  playUserLeftSound,
  stopCallSounds,
} from "./sound-effects";
import { participantCanSpeak, participantMayPublishMedia } from "./stage-roles";

// Handles the roster-shaped room messages ("participants", "role_change",
// "hand_raise"): diffing the roster into mesh peer create/destroy (or the
// livekit roster sync), rebuilding the call topology around stage role
// changes, and the join/leave/hand-raise user feedback.
export default class RosterHandler {
  #roleChangeInProgress = new Set();

  #peerManager;
  #signaling;
  #presencePending;
  #livekit;
  #toasts;
  #getCurrentUserId;
  #getChatSound;
  #getRoom;
  #isActiveRoom;
  #isConnectingRoom;
  #isMeshRoom;
  #registerTrack;
  #getRemoteUserIds;
  #removeRemoteStream;
  #removeRemoteMedia;
  #removeAllRemoteStreams;
  #getLocalVideoKind;
  #syncVideoSenders;
  #stopLocalVideo;
  #getLocalStream;
  #acquireMicrophone;
  #setMicEnabled;
  #stopLocalAudio;
  #ensureLocalAudioMonitor;

  constructor({
    peerManager,
    signaling,
    presencePending,
    livekit,
    toasts,
    getCurrentUserId,
    getChatSound,
    getRoom,
    isActiveRoom,
    isConnectingRoom,
    isMeshRoom,
    registerTrack,
    getRemoteUserIds = () => [],
    removeRemoteStream,
    removeRemoteMedia = () => {},
    removeAllRemoteStreams,
    getLocalVideoKind,
    syncVideoSenders,
    stopLocalVideo,
    getLocalStream,
    acquireMicrophone,
    setMicEnabled,
    stopLocalAudio,
    ensureLocalAudioMonitor,
  }) {
    this.#peerManager = peerManager;
    this.#signaling = signaling;
    this.#presencePending = presencePending;
    this.#livekit = livekit;
    this.#toasts = toasts;
    this.#getCurrentUserId = getCurrentUserId;
    this.#getChatSound = getChatSound;
    this.#getRoom = getRoom;
    this.#isActiveRoom = isActiveRoom;
    this.#isConnectingRoom = isConnectingRoom;
    this.#isMeshRoom = isMeshRoom;
    this.#registerTrack = registerTrack;
    this.#getRemoteUserIds = getRemoteUserIds;
    this.#removeRemoteStream = removeRemoteStream;
    this.#removeRemoteMedia = removeRemoteMedia;
    this.#removeAllRemoteStreams = removeAllRemoteStreams;
    this.#getLocalVideoKind = getLocalVideoKind;
    this.#syncVideoSenders = syncVideoSenders;
    this.#stopLocalVideo = stopLocalVideo;
    this.#getLocalStream = getLocalStream;
    this.#acquireMicrophone = acquireMicrophone;
    this.#setMicEnabled = setMicEnabled;
    this.#stopLocalAudio = stopLocalAudio;
    this.#ensureLocalAudioMonitor = ensureLocalAudioMonitor;
  }

  isRoleChangeInProgress(roomId) {
    return this.#roleChangeInProgress.has(roomId);
  }

  async handleParticipants(roomId, payload) {
    const participants = payload.participants || [];
    const participantIds = new Set(
      participants.map((participant) => Number(participant.id))
    );
    const currentUserId = this.#getCurrentUserId();

    // eslint-disable-next-line no-console
    console.log(
      `[voice] handleParticipants room=${roomId}, participants=[${Array.from(participantIds)}], currentUser=${currentUserId}`
    );

    if (this.#roleChangeInProgress.has(roomId)) {
      return;
    }

    const room = this.#getRoom(roomId);
    const isStage = room?.room_type === "stage";
    const iCanSpeak = room ? participantCanSpeak(room, currentUserId) : true;

    let hasPeerLeft = false;
    let hasNewPeer = false;

    // Peer create/destroy and the presence-pending machinery are mesh-only;
    // other transports carry media outside the roster diff.
    if (this.#isMeshRoom(roomId)) {
      const peers = this.#peerManager.getRoomPeers(roomId);
      const existingPeerIds = new Set(peers?.keys() || []);

      peers?.forEach((pc, remoteUserId) => {
        if (!participantIds.has(remoteUserId)) {
          if (this.#presencePending.has(roomId, remoteUserId)) {
            return;
          }
          hasPeerLeft = true;
          this.#peerManager.destroy(roomId, remoteUserId);
        }
      });

      for (const participant of participants) {
        const participantId = Number(participant.id);
        if (!participantId || participantId <= 0) {
          continue;
        }
        if (participantId === currentUserId) {
          continue;
        }

        if (isStage) {
          const theyCanSpeak =
            participant.role === "moderator" || participant.role === "speaker";
          const shouldConnect = iCanSpeak || theyCanSpeak;

          if (!shouldConnect) {
            if (this.#peerManager.has(roomId, participantId)) {
              this.#peerManager.destroy(roomId, participantId);
            }
            continue;
          }
        }

        if (!this.#peerManager.has(roomId, participantId)) {
          if (existingPeerIds.size > 0 || !this.#isConnectingRoom(roomId)) {
            hasNewPeer = true;
          }
          // eslint-disable-next-line no-console
          console.log(
            `[voice] creating peer connection to user ${participantId}`
          );

          await this.#createAndOfferPeer(roomId, participantId);
        } else {
          this.#presencePending.clear(roomId, participantId);
        }
      }
    } else {
      ({ hasNewPeer, hasPeerLeft } = this.#livekit.syncRoster(
        roomId,
        participants
      ));
    }

    if (this.#isActiveRoom(roomId)) {
      if (hasNewPeer) {
        // If this client was ringing (caller waiting alone in a call room),
        // someone arriving means the call was answered.
        stopCallSounds();
        playUserJoinedSound(this.#getChatSound());
      } else if (hasPeerLeft) {
        playUserLeftSound(this.#getChatSound());
      }
    }

    this.#syncRemoteVideoTracks(roomId, participants);
    this.#dropDisallowedStreams(roomId, participants, { isStage });
    this.#dropUnentitledMedia(roomId, participants);

    if (!this.#isMeshRoom(roomId)) {
      // Publisher-count changes move camera subscriptions between simulcast
      // layers.
      this.#livekit.sessionFor(roomId)?.updateSubscriberQuality();
    }

    if (this.#getLocalVideoKind()) {
      await this.#syncVideoSenders(roomId);
    }
  }

  #syncRemoteVideoTracks(roomId, participants) {
    for (const participant of participants || []) {
      const participantId = Number(participant?.id);
      if (!participantId || participantId === this.#getCurrentUserId()) {
        continue;
      }

      if (!participant.is_video_on && !participant.is_screen_sharing) {
        continue;
      }

      const track = this.#peerManager.remoteVideoTrack(roomId, participantId);
      if (track) {
        this.#registerTrack(roomId, participantId, track);
      }
    }
  }

  // Re-evaluates playing media against the fresh roster: a mesh participant
  // demoted to a role that cannot publish must stop being heard immediately,
  // even when the demotion arrives as a roster refresh rather than a
  // role_change message. The receive-side track policy stops new tracks;
  // this drops the ones already registered.
  #dropDisallowedStreams(roomId, participants, { isStage }) {
    if (!isStage || !this.#isMeshRoom(roomId)) {
      return;
    }

    const allowedToPublish = new Set(
      participants
        .filter(
          (participant) =>
            participant.role === "moderator" || participant.role === "speaker"
        )
        .map((participant) => Number(participant.id))
    );

    for (const userId of this.#getRemoteUserIds(roomId)) {
      if (!allowedToPublish.has(userId)) {
        this.#removeRemoteStream(roomId, userId);
      }
    }
  }

  // The receive-side policy stops new tracks; this drops the camera or screen
  // media of a mesh sender whose entitlement was revoked while it played.
  #dropUnentitledMedia(roomId, participants) {
    if (!this.#isMeshRoom(roomId)) {
      return;
    }

    for (const participant of participants || []) {
      const participantId = Number(participant?.id);
      if (!participantId || participantId === this.#getCurrentUserId()) {
        continue;
      }

      if (!participantMayPublishMedia(participant)) {
        this.#removeRemoteMedia(roomId, participantId);
      }
    }
  }

  async handleRoleChange(roomId, payload) {
    const targetUserId = Number(payload.user_id);
    const newRole = payload.role;

    if (targetUserId === this.#getCurrentUserId()) {
      await this.#handleOwnRoleChange(roomId, newRole);
    } else {
      this.#handlePeerRoleChange(roomId, targetUserId);
    }
  }

  async #handleOwnRoleChange(roomId, newRole) {
    const canSpeak = newRole === "speaker" || newRole === "moderator";

    // Block handleParticipants while we reconfigure the local stream,
    // so the subsequent "participants" broadcast doesn't create peers
    // before the mic is ready.
    this.#roleChangeInProgress.add(roomId);

    // Destroy all existing peers immediately. Mesh-only: on other transports
    // the media session survives a role change untouched, so wiping the
    // remote registry would silence everyone until they republished.
    if (this.#isMeshRoom(roomId)) {
      this.#peerManager.destroyRoom(roomId);
      this.#removeAllRemoteStreams(roomId);
      this.#signaling.clearForRoom(roomId);
      this.#signaling.clearHttpQueue(roomId);
    }

    if (canSpeak) {
      if (!this.#getLocalStream()) {
        // The acquisition callback owns the user-facing failure feedback
        // (permission help modal or toast).
        const acquired = await this.#acquireMicrophone();
        if (!acquired) {
          this.#roleChangeInProgress.delete(roomId);
          return;
        }

        this.#setMicEnabled(true);
      }

      this.#ensureLocalAudioMonitor(roomId);

      this.#toasts.success({
        duration: 5000,
        data: { message: i18n("voice.stage.promoted_to_speaker") },
      });
    } else {
      if (this.#getLocalVideoKind()) {
        await this.#stopLocalVideo();
      }
      this.#stopLocalAudio();
      this.#setMicEnabled(false);
      this.#toasts.default({
        duration: 5000,
        data: { message: i18n("voice.stage.demoted_to_listener") },
      });
    }

    this.#roleChangeInProgress.delete(roomId);

    // Rebuild peers now that the local stream is ready (or stopped).
    // Mesh-only: peer rebuilds are meaningless on other transports.
    if (this.#isMeshRoom(roomId)) {
      this.#reconnectAllPeers(roomId);
    } else {
      // The SFU connection survives the role change; just publish or release
      // the microphone to match the new role.
      try {
        await this.#livekit.sessionFor(roomId)?.refreshPublications();
      } catch (error) {
        // eslint-disable-next-line no-console
        console.warn(
          `[voice-livekit] failed to refresh publications after a role change in room ${roomId}`,
          error
        );
      }
    }
  }

  handleHandRaise(roomId, payload) {
    const targetUserId = Number(payload.user_id);
    const isSelf = targetUserId === this.#getCurrentUserId();

    if (isSelf && !payload.raised && payload.reason === "dismissed") {
      this.#toasts.default({
        duration: 5000,
        data: { message: i18n("voice.stage.request_dismissed") },
      });
      return;
    }

    const room = this.#getRoom(roomId);
    if (!isSelf && payload.raised && room?.can_manage) {
      const participant = (room.active_participants || []).find(
        (p) => Number(p?.id) === targetUserId
      );
      if (participant) {
        this.#toasts.default({
          duration: 5000,
          data: {
            message: i18n("voice.stage.hand_raised_toast", {
              username: participant.username,
            }),
          },
        });
      }
    }
  }

  #handlePeerRoleChange(roomId, userId) {
    // Destroy the stale peer; the subsequent "participants" broadcast
    // from the server will rebuild connections with the correct topology.
    if (this.#peerManager.has(roomId, userId)) {
      this.#peerManager.destroy(roomId, userId);
      this.#removeRemoteStream(roomId, userId);
    }
  }

  async #createAndOfferPeer(roomId, remoteUserId) {
    await this.#peerManager.create(roomId, remoteUserId);
    if (this.#getCurrentUserId() <= remoteUserId) {
      await this.#peerManager.initiateOffer(roomId, remoteUserId);
    } else {
      this.#peerManager.scheduleOfferRetry(roomId, remoteUserId);
    }
  }

  #reconnectAllPeers(roomId) {
    this.#peerManager.destroyRoom(roomId);
    this.#removeAllRemoteStreams(roomId);
    this.#signaling.clearForRoom(roomId);
    this.#signaling.clearHttpQueue(roomId);

    const room = this.#getRoom(roomId);
    if (!room) {
      return;
    }

    const participants = room.active_participants || [];
    const iCanSpeak = participantCanSpeak(room, this.#getCurrentUserId());

    for (const participant of participants) {
      const participantId = Number(participant?.id);
      if (participantId === this.#getCurrentUserId()) {
        continue;
      }

      const theyCanSpeak = participantCanSpeak(room, participantId);
      const shouldConnect = iCanSpeak || theyCanSpeak;

      if (shouldConnect) {
        this.#createAndOfferPeer(roomId, participantId);
      }
    }
  }
}
