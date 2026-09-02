import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import Draft from "discourse/models/draft";
import { i18n } from "discourse-i18n";
import { confirmMeshPrivacy } from "../../components/modal/voice-mesh-privacy-warning";
import { reportMicAcquisitionFailure } from "../../components/modal/voice-mic-permission";
import AudioMonitor from "../../lib/voice/audio-monitor";
import { RING_SECONDS } from "../../lib/voice/call-constants";
import HeartbeatManager from "../../lib/voice/heartbeat-manager";
import IdleTracker, { idleThresholds } from "../../lib/voice/idle-tracker";
import { consumePendingInviteRef } from "../../lib/voice/invite-ref";
import LivekitCoordinator from "../../lib/voice/livekit-coordinator";
import LocalAudioPipeline from "../../lib/voice/local-audio-pipeline";
import LocalVideoManager from "../../lib/voice/local-video-manager";
import {
  applyOutputDevice,
  preferredOutputDeviceId,
  setPreferredOutputDeviceId,
} from "../../lib/voice/media-devices";
import MeshSignalHandler from "../../lib/voice/mesh-signal-handler";
import ParticipantAudio from "../../lib/voice/participant-audio";
import PeerManager from "../../lib/voice/peer-manager";
import PresencePendingPeers from "../../lib/voice/presence-pending-peers";
import PttManager from "../../lib/voice/ptt-manager";
import {
  allowedQualityTiers,
  clampQuality,
  preferredCameraQuality,
  preferredScreenContent,
  preferredScreenQuality,
  preferredVoiceQuality,
  QUALITY_STANDARD,
  setPreferredCameraQuality,
  setPreferredScreenContent,
  setPreferredScreenQuality,
  setPreferredVoiceQuality,
} from "../../lib/voice/quality-preferences";
import RemoteStreamRegistry from "../../lib/voice/remote-stream-registry";
import { activeRingingEntries } from "../../lib/voice/ringing";
import RoomMessageQueue from "../../lib/voice/room-message-queue";
import RosterHandler from "../../lib/voice/roster-handler";
import SignalingManager from "../../lib/voice/signaling";
import {
  playConnectedSound,
  playDeafenSound,
  playDisconnectedSound,
  playMuteSound,
  playUndeafenSound,
  playUnmuteSound,
  schedulePlaybackResume,
  startWaitingSound,
  stopCallSounds,
} from "../../lib/voice/sound-effects";
import {
  participantCanSpeak,
  remoteTrackAllowed,
} from "../../lib/voice/stage-roles";
import TranscriptionCoordinator from "../../lib/voice/transcription-coordinator";
import { applyVoiceQuality } from "../../lib/voice/video-quality";

export default class VoiceWebrtcService extends Service {
  @service currentUser;
  @service messageBus;
  @service modal;
  @service siteSettings;
  @service("voice-rooms") voiceRooms;
  @service toasts;

  @tracked activeRoomId = null;
  @tracked watchingRoomId = null;
  @tracked audioEnabled = true;
  @tracked deafened = false;
  @tracked remoteStreamsRevision = 0;
  @tracked connectionRevision = 0;
  @tracked idleState = "active";
  @tracked pttEnabled = false;
  @tracked pttKey = "Space";
  @tracked pttActive = false;
  @tracked autoStatusEnabled = true;
  @tracked callWidgetHidden = false;
  @tracked outputDeviceId;
  @tracked voiceQuality = preferredVoiceQuality();
  @tracked cameraQuality = preferredCameraQuality();
  @tracked screenQuality = preferredScreenQuality();
  @tracked screenContent = preferredScreenContent();

  #connectingRoomIds = new Set();
  #activeRoomIds = new Set();
  #joinRevision = 0;
  #connectingParticipantSnapshots = new Map();
  #connectingSignalQueue = new Map();
  // Server-attested participant session per room, from the join response
  // (rotated by livekit_token). Signal/heartbeat/state requests must carry it:
  // the server binds signaling authority to this session instead of to roster
  // presence, which propagates asynchronously.
  #roomSessions = new Map();
  // Per-room transport tag ("mesh" | "livekit"), read from the join response.
  // Rooms without a tag (older servers, messages arriving before the join
  // response, tests) default to mesh, so every guard below is a tautology on
  // pure-P2P installs.
  #roomTransports = new Map();
  // ICE configuration from the most recent join response. Server-provided so
  // TURN credentials can be minted per user and per session instead of being
  // exposed as client site settings. Peers are only created for active rooms,
  // and a room only becomes active after its join response arrives, so this
  // is always populated before it is read.
  #iceConfig = null;
  #roomHandlerCallbacks = new Map();
  #deferredTeardownTimers = new Set();
  #pendingPlaybackElements = new WeakSet();

  #signaling;
  #peerManager;
  #meshSignals;
  #audioMonitor;
  #idleTracker;
  #localAudio;
  #localVideo;
  #pttManager;
  #roomMessageQueue;
  #remoteStreamRegistry;
  #participantAudio;
  #heartbeat;
  #presencePending;
  #livekit;
  #roster;
  #transcription;

  constructor() {
    super(...arguments);

    this.#pttManager = new PttManager({
      onPress: () => this.#handlePttPress(),
      onReleaseImmediate: () => this.#handlePttRelease(),
      onReleaseDebounced: () => this.#broadcastMuteState(),
      isConnected: () => this.#activeRoomIds.size > 0,
    });

    this.pttEnabled = this.#pttManager.enabled;
    this.pttKey = this.#pttManager.key;

    this.#signaling = new SignalingManager({
      isActiveRoom: (id) => this.#activeRoomIds.has(id),
      hasPeer: (roomId, uid) => this.#peerManager.has(roomId, uid),
      getParticipantSessionId: (roomId) => this.#roomSessions.get(roomId),
    });

    this.#peerManager = new PeerManager({
      getIceServers: () => this.iceServers,
      getIceTransportPolicy: () => this.iceTransportPolicy,
      getLocalStream: () => this.localStream,
      getLocalVideoTrack: (roomId, uid) =>
        this.#localVideo.trackFor(roomId, uid),
      getLocalScreenAudioTrack: (roomId, uid) =>
        this.#localVideo.screenAudioTrackFor(roomId, uid),
      sendSignal: (roomId, uid, payload) =>
        this.#signaling.send(roomId, uid, payload),
      flushQueuedSignals: (roomId, uid) =>
        this.#signaling.flushQueued(roomId, uid),
      canPublishMedia: (roomId) => this.#canPublishMediaIn(roomId),
      onTrack: (roomId, uid, track, streams) =>
        this.#registerRemoteTrack(roomId, uid, track, streams),
      clearSignalQueue: (roomId, uid) =>
        this.#signaling.clearForPeer(roomId, uid),
      onPeerDestroyed: (roomId, uid) => this.#removeRemoteStream(roomId, uid),
      onPeerConnected: (roomId, uid, pc) => {
        const tier = this.effectiveVoiceQuality(roomId);
        if (tier !== QUALITY_STANDARD) {
          const sender = PeerManager.micSenderFor(pc);
          if (sender?.track) {
            applyVoiceQuality([sender], tier);
          }
        }
      },
      shouldRestartPeer: (roomId, uid) =>
        this.#meshSignals.shouldMaintainPeerConnection(roomId, uid),
    });

    this.#audioMonitor = new AudioMonitor({
      onSpeakingChange: (roomId, userId, speaking) =>
        this.voiceRooms?.setParticipantSpeaking(roomId, userId, speaking),
      onVoiceActivity: () => this.#idleTracker?.onVoiceActivity(),
    });

    this.#idleTracker = new IdleTracker({
      onIdleStateChange: (state, wasAfk) =>
        this.#handleIdleStateChange(state, wasAfk),
      onAutoMute: () => this.#handleAutoMute(),
      onDisconnect: () => this.#handleIdleDisconnect(),
      getThresholds: () => idleThresholds(this.siteSettings),
    });

    this.#localAudio = new LocalAudioPipeline({
      onStreamChanged: () => this.#syncLocalStreamState(),
      onSuppressionFailed: () => {
        this.toasts.error({
          duration: 5000,
          data: {
            message: i18n("voice.voice_settings.noise_suppression_failed"),
          },
        });
      },
      replaceTrackOnPeers: () => this.#replaceTrackOnAllPeers(),
    });

    this.outputDeviceId = preferredOutputDeviceId();

    this.#roomMessageQueue = new RoomMessageQueue();

    this.#remoteStreamRegistry = new RemoteStreamRegistry({
      onChange: () => this.remoteStreamsRevision++,
      onMicTrack: (roomId, userId, stream) => {
        this.#audioMonitor.ensure(roomId, userId, stream, false);
        this.#transcription.attachRemote(roomId, userId, stream);
      },
    });

    this.#transcription = new TranscriptionCoordinator({
      siteSettings: this.siteSettings,
      getParticipantSessionId: (roomId) => this.#roomSessions.get(roomId),
      getCurrentUserId: () => this.currentUser?.id,
      getRoom: (roomId) => this.voiceRooms?.roomById(roomId),
      isActiveRoom: (roomId) => this.#activeRoomIds.has(roomId),
      getActiveRoomIds: () => this.#activeRoomIds,
      getRemoteUserIds: (roomId) =>
        this.#remoteStreamRegistry.userIdsFor(roomId),
      getRemoteStream: (roomId, userId) =>
        this.#remoteStreamRegistry.streamFor(roomId, userId),
      getLocalStream: () => this.localStream,
      setParticipantTranscribing: (roomId, transcribing) =>
        this.voiceRooms?.setParticipantVideoState(
          roomId,
          this.currentUser?.id,
          { is_transcribing: transcribing }
        ),
      saveDraft: (key, sequence, data) =>
        Draft.save(key, sequence, data, this.messageBus.clientId),
      openComposer: (opts) =>
        getOwner(this).lookup("service:composer").open(opts),
      showError: (messageKey) =>
        this.toasts.error({
          duration: 5000,
          data: { message: i18n(messageKey) },
        }),
    });

    this.#participantAudio = new ParticipantAudio({
      isDeafened: () => this.deafened,
    });

    this.#heartbeat = new HeartbeatManager({
      isActiveRoom: (roomId) => this.#activeRoomIds.has(roomId),
      buildPayload: (roomId) => this.#heartbeatPayload(roomId),
      onExpelled: (roomId) => this.leave({ id: roomId }),
    });

    this.#presencePending = new PresencePendingPeers({
      onExpired: (roomId, userId) => {
        if (!this.#meshSignals.shouldMaintainPeerConnection(roomId, userId)) {
          this.#peerManager.destroy(roomId, userId);
        }
      },
    });

    this.#localVideo = new LocalVideoManager({
      peerManager: this.#peerManager,
      getParticipantSessionId: (roomId) => this.#roomSessions.get(roomId),
      getLivekitSession: (roomId) => this.#livekit.sessionFor(roomId),
      isMeshRoom: (roomId) => this.#isMeshRoom(roomId),
      isActiveRoom: (roomId) => this.#activeRoomIds.has(roomId),
      isConnectingRoom: (roomId) => this.#connectingRoomIds.has(roomId),
      getFirstActiveRoomId: () => this.#firstActiveRoomId(),
      getActiveRoomId: () => this.activeRoomId,
      getRoom: (roomId) => this.voiceRooms?.roomById(roomId),
      canPublishVideo: (roomId) => this.canPublishVideo(roomId),
      getCameraQuality: (roomId) => this.effectiveCameraQuality(roomId),
      getScreenQuality: (roomId) => this.effectiveScreenQuality(roomId),
      getScreenContent: () => this.screenContent,
      isBlurAllowed: () => this.videoBlurAvailable,
      setParticipantVideoState: (roomId, state) =>
        this.voiceRooms?.setParticipantVideoState(
          roomId,
          this.currentUser?.id,
          state
        ),
      showError: (messageKey) =>
        this.toasts.error({
          duration: 5000,
          data: { message: i18n(messageKey) },
        }),
    });

    this.#meshSignals = new MeshSignalHandler({
      peerManager: this.#peerManager,
      signaling: this.#signaling,
      presencePending: this.#presencePending,
      getCurrentUserId: () => this.currentUser?.id,
      isActiveRoom: (roomId) => this.#activeRoomIds.has(roomId),
      getRoom: (roomId) => this.voiceRooms?.roomById(roomId),
      isRoleChangeInProgress: (roomId) =>
        this.#roster.isRoleChangeInProgress(roomId),
      addProvisionalParticipant: (roomId, participant) =>
        this.voiceRooms?.addParticipant(roomId, participant),
      onOfferHandled: async (roomId) => {
        if (this.localVideoKind) {
          await this.#localVideo.syncSenders(roomId);
        }
      },
    });

    this.#livekit = new LivekitCoordinator({
      getCurrentUserId: () => this.currentUser?.id,
      getParticipantSessionId: (roomId) => this.#roomSessions.get(roomId),
      onParticipantSessionRenewed: (roomId, sessionId) => {
        if (sessionId) {
          this.#roomSessions.set(roomId, sessionId);
        }
      },
      getLocalStream: () => this.localStream,
      getLocalVideoTrack: () => this.localVideoTrack,
      getLocalScreenAudioTrack: () => this.localScreenAudioTrack,
      getLocalVideoKind: () => this.localVideoKind,
      getVideoPublisherCount: (roomId) => this.videoPublisherCount(roomId),
      getQualityTiers: (roomId) => ({
        voice: this.effectiveVoiceQuality(roomId),
        camera: this.effectiveCameraQuality(roomId),
        screen: this.effectiveScreenQuality(roomId),
      }),
      onTrack: (roomId, userId, track, streams) =>
        this.#remoteStreamRegistry.register(roomId, userId, track, streams),
      removeRemoteStream: (roomId, userId) =>
        this.#removeRemoteStream(roomId, userId),
      getRemoteUserIds: (roomId) =>
        this.#remoteStreamRegistry.userIdsFor(roomId),
      bumpConnectionRevision: () => this.#bumpConnectionRevision(),
      isActiveRoom: (roomId) => this.#activeRoomIds.has(roomId),
      isConnectingRoom: (roomId) => this.#connectingRoomIds.has(roomId),
      isJoinCurrent: (revision) => this.#joinRevision === revision,
      leave: (roomId, options) => this.leave({ id: roomId }, options),
      unwindFailedJoin: (roomId) => {
        this.#handleJoinFailure(roomId);
        // The failure landed after the active-mark, which #handleJoinFailure
        // (built for pre-mark failures) doesn't unwind.
        this.#clearActiveRoomId(roomId);
      },
      showError: (messageKey) =>
        this.toasts.error({
          duration: 8000,
          data: { message: i18n(messageKey) },
        }),
      showNotice: (messageKey) =>
        this.toasts.default({
          duration: 8000,
          data: { message: i18n(messageKey) },
        }),
    });

    this.#roster = new RosterHandler({
      peerManager: this.#peerManager,
      signaling: this.#signaling,
      presencePending: this.#presencePending,
      livekit: this.#livekit,
      toasts: this.toasts,
      getCurrentUserId: () => this.currentUser?.id,
      getChatSound: () => this.currentUser?.chat_sound,
      getRoom: (roomId) => this.voiceRooms?.roomById(roomId),
      isActiveRoom: (roomId) => this.#activeRoomIds.has(roomId),
      isConnectingRoom: (roomId) => this.#connectingRoomIds.has(roomId),
      isMeshRoom: (roomId) => this.#isMeshRoom(roomId),
      registerTrack: (roomId, userId, track) =>
        this.#registerRemoteTrack(roomId, userId, track),
      getRemoteUserIds: (roomId) =>
        this.#remoteStreamRegistry.userIdsFor(roomId),
      removeRemoteStream: (roomId, userId) =>
        this.#removeRemoteStream(roomId, userId),
      removeAllRemoteStreams: (roomId) => this.#removeAllRemoteStreams(roomId),
      getLocalVideoKind: () => this.localVideoKind,
      syncVideoSenders: (roomId) => this.#localVideo.syncSenders(roomId),
      stopLocalVideo: () => this.#localVideo.stop(),
      getLocalStream: () => this.localStream,
      acquireMicrophone: () => this.#acquireMicrophoneWithFeedback(),
      setMicEnabled: (enabled) => this.#setMicEnabled(enabled),
      stopLocalAudio: () => this.#localAudio.stop(),
      ensureLocalAudioMonitor: (roomId) =>
        this.#audioMonitor.ensure(
          roomId,
          this.currentUser?.id,
          this.localStream,
          true
        ),
    });

    try {
      const stored = localStorage.getItem("voice_auto_status_enabled");
      this.autoStatusEnabled = stored !== "false";
    } catch {
      this.autoStatusEnabled = true;
    }

    try {
      this.callWidgetHidden =
        localStorage.getItem("voice_call_widget_hidden") === "true";
    } catch {
      this.callWidgetHidden = false;
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.#joinRevision++;
    this.#pttManager.destroy();
    this.#idleTracker.stop();
    this.#audioMonitor.destroyAll();
    this.#peerManager.destroyAll();
    this.#livekit.destroy();
    this.#signaling.destroy();

    this.#localVideo.destroy();
    this.#localAudio.stop();
    this.#transcription.destroy();

    this.#roomHandlerCallbacks.forEach((callback, roomId) => {
      this.voiceRooms?.unregisterRoomHandler(roomId, callback);
    });
    this.#roomHandlerCallbacks.clear();
    this.#heartbeat.stopAll();
    this.#deferredTeardownTimers.forEach((timer) => clearTimeout(timer));
    this.#deferredTeardownTimers.clear();
    this.#connectingRoomIds.clear();
    this.#connectingParticipantSnapshots.clear();
    this.#connectingSignalQueue.clear();
    this.#roomTransports.clear();
    this.#roomSessions.clear();
    this.#presencePending.clearAll();
    this.#roomMessageQueue.clearAll();
  }

  get iceServers() {
    return this.#iceConfig?.servers ?? [];
  }

  get iceTransportPolicy() {
    return this.#iceConfig?.transport_policy ?? "all";
  }

  // --- Local audio pipeline delegates ---

  get localStream() {
    return this.#localAudio.stream;
  }

  get noiseSuppressionEnabled() {
    return this.#localAudio.noiseSuppressionEnabled;
  }

  get noiseSuppressionState() {
    return this.#localAudio.noiseSuppressionState;
  }

  get noiseSuppressionMode() {
    return this.#localAudio.noiseSuppressionMode;
  }

  get echoCancellation() {
    return this.#localAudio.echoCancellation;
  }

  get autoGainControl() {
    return this.#localAudio.autoGainControl;
  }

  get gateThreshold() {
    return this.#localAudio.gateThreshold;
  }

  get inputDeviceId() {
    return this.#localAudio.inputDeviceId;
  }

  // --- Subtitles & transcript delegates ---

  get subtitlesAvailable() {
    return this.#transcription.available;
  }

  get subtitlesEnabled() {
    return this.#transcription.enabled;
  }

  get subtitlesLoading() {
    return this.#transcription.loading;
  }

  get subtitlesProgress() {
    return this.#transcription.progress;
  }

  get captions() {
    return this.#transcription.captions;
  }

  get transcriptRecording() {
    return this.#transcription.recording;
  }

  get transcriptRoomId() {
    return this.#transcription.roomId;
  }

  get transcriptEntries() {
    return this.#transcription.entries;
  }

  get transcriptEntriesRoomId() {
    return this.#transcription.entriesRoomId;
  }

  get transcriptStartedAt() {
    return this.#transcription.startedAt;
  }

  get remoteStreams() {
    this.remoteStreamsRevision;
    return this.#remoteStreamRegistry.allStreams();
  }

  get remoteScreenAudioStreams() {
    this.remoteStreamsRevision;
    return this.#remoteStreamRegistry.allScreenAudioStreams();
  }

  get hasActiveRoom() {
    return !!this.activeRoomId;
  }

  get activeRoom() {
    return this.activeRoomId
      ? this.voiceRooms?.roomById(this.activeRoomId)
      : null;
  }

  // --- Video & screen sharing ---

  get screenShareSupported() {
    return !!navigator.mediaDevices?.getDisplayMedia;
  }

  get localVideoStream() {
    return this.#localVideo.stream;
  }

  get localVideoKind() {
    return this.#localVideo.kind;
  }

  get videoBlurEnabled() {
    return this.#localVideo.blurEnabled;
  }

  get videoBlurAmount() {
    return this.#localVideo.blurAmount;
  }

  get videoInputDeviceId() {
    return this.#localVideo.inputDeviceId;
  }

  // Whether the site allows background blur; distinct from browser support
  // so the UI can tell "turned off by admin" apart from "can't run here".
  get videoBlurAvailable() {
    return !!this.siteSettings.voice_video_background_blur_enabled;
  }

  get videoBlurSupported() {
    return this.#localVideo.blurSupported;
  }

  get localVideoTrack() {
    return this.#localVideo.track;
  }

  get localScreenAudioTrack() {
    return this.#localVideo.screenAudioTrack;
  }

  setNoiseSuppressionMode(mode) {
    return this.#localAudio.setNoiseSuppressionMode(mode);
  }

  setEchoCancellation(enabled) {
    return this.#localAudio.setEchoCancellation(enabled);
  }

  setAutoGainControl(enabled) {
    return this.#localAudio.setAutoGainControl(enabled);
  }

  setInputDevice(deviceId) {
    return this.#localAudio.setInputDevice(deviceId);
  }

  setGateThreshold(value) {
    return this.#localAudio.setGateThreshold(value);
  }

  toggleSubtitles() {
    this.#transcription.toggle();
  }

  isTranscribingRoom(roomId) {
    return this.#transcription.isTranscribingRoom(roomId);
  }

  toggleTranscriptRecording(roomId) {
    this.#transcription.toggleRecording(roomId);
  }

  openTranscriptDraft() {
    return this.#transcription.openDraft();
  }

  captionsFor(roomId) {
    return this.#transcription.captionsFor(roomId);
  }

  remoteStreamsFor(roomId) {
    this.remoteStreamsRevision;
    return this.#remoteStreamRegistry.streamsFor(roomId);
  }

  // The server-attested session participant actions (hand raising, state
  // changes) must carry to be accepted.
  participantSessionIdFor(roomId) {
    return this.#roomSessions.get(roomId);
  }

  remoteStreamFor(roomId, userId) {
    this.remoteStreamsRevision;
    return this.#remoteStreamRegistry.streamFor(roomId, userId);
  }

  connectionStateFor(roomId) {
    this.connectionRevision;
    if (this.#connectingRoomIds.has(roomId)) {
      return "connecting";
    }
    if (this.#activeRoomIds.has(roomId)) {
      return "connected";
    }
    return "idle";
  }

  isActiveRoom(roomId) {
    return Number(this.activeRoomId) === Number(roomId);
  }

  isLivekitRoom(roomId) {
    return this.#roomTransports.get(roomId) === "livekit";
  }

  async join(room) {
    if (!room?.id) {
      return;
    }

    // Several call controls can request a join. Once this room already owns
    // a media session, a second request would connect another LiveKit client
    // with the same user identity and evict the first one.
    if (
      this.#activeRoomIds.has(room.id) ||
      this.#connectingRoomIds.has(room.id)
    ) {
      return;
    }

    // Confirmed before any join state is touched, so cancelling leaves
    // nothing to unwind.
    const meshPrivacyConfirmed = await confirmMeshPrivacy(room, {
      currentUser: this.currentUser,
      modal: this.modal,
      siteSettings: this.siteSettings,
    });
    if (!meshPrivacyConfirmed) {
      return;
    }

    // Whatever call loop was sounding (ringtone on an answered call, waiting
    // tone when hopping rooms) is over once a join starts.
    stopCallSounds();

    // Bump the join revision so any in-flight join for a different room
    // will detect it has been superseded and abort.
    const revision = ++this.#joinRevision;

    this.#connectingRoomIds.add(room.id);
    this.#bumpConnectionRevision();

    // Leave rooms that are already active.
    for (const activeRoomId of this.#activeRoomIds) {
      if (activeRoomId !== room.id) {
        this.leave({ id: activeRoomId }, { keepLocalStream: true });
      }
    }

    // Abort any other in-progress joins (still in connecting state).
    for (const connectingId of this.#connectingRoomIds) {
      if (connectingId !== room.id) {
        this.#connectingRoomIds.delete(connectingId);
        this.#teardownRoom(connectingId);
      }
    }

    // eslint-disable-next-line no-console
    console.log(`[voice] joining room ${room.id}`);

    this.#registerRoomHandler(room.id);

    let response;

    try {
      const joinData = {};
      if (
        !this.autoStatusEnabled ||
        !this.siteSettings.voice_auto_status_enabled
      ) {
        joinData.skip_status = true;
      }
      const invitedBy = consumePendingInviteRef(room);
      if (invitedBy) {
        joinData.invited_by = invitedBy;
      }
      // Carrying the live session makes a duplicated join idempotent on the
      // server: it refreshes the existing grant instead of rotating it.
      const existingSessionId = this.#roomSessions.get(room.id);
      if (existingSessionId) {
        joinData.participant_session_id = existingSessionId;
      }
      response = await ajax(`/voice/rooms/${room.id}/join`, {
        type: "POST",
        data: joinData,
      });
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn("[voice] failed to join room", error);
      this.#handleJoinFailure(room.id);
      return;
    }

    if (this.#joinRevision !== revision) {
      ajax(`/voice/rooms/${room.id}/leave`, {
        type: "DELETE",
        data: { participant_session_id: response?.participant_session_id },
      });
      return;
    }

    // eslint-disable-next-line no-console
    console.log(
      `[voice] join response, active_participants:`,
      response?.room?.active_participants
    );

    this.#roomTransports.set(room.id, response?.transport ?? "mesh");
    if (response?.participant_session_id) {
      this.#roomSessions.set(room.id, response.participant_session_id);
    }
    this.#iceConfig = response?.ice ?? this.#iceConfig;

    const joinedRoom = response?.room;
    if (joinedRoom) {
      // The join response is serialized as the (now participating) user, so
      // it carries the per-user chat fields the directory payloads gate off —
      // fold it in so the room page sees them.
      this.voiceRooms?.upsertRoom?.(joinedRoom);
    }
    const isStageListener =
      joinedRoom?.room_type === "stage" && !this.#canSpeakInRoom(joinedRoom);

    if (!isStageListener && !this.localStream) {
      const acquired = await this.#acquireMicrophoneWithFeedback();
      if (!acquired) {
        ajax(`/voice/rooms/${room.id}/leave`, {
          type: "DELETE",
          data: { participant_session_id: this.#roomSessions.get(room.id) },
        });
        this.#handleJoinFailure(room.id);
        return;
      }
    }

    if (this.#joinRevision !== revision) {
      ajax(`/voice/rooms/${room.id}/leave`, {
        type: "DELETE",
        data: { participant_session_id: this.#roomSessions.get(room.id) },
      });
      return;
    }

    if (this.localStream) {
      this.#setMicEnabled(!this.pttEnabled);
    }

    // Only mark the room as active after the microphone is ready.
    // This prevents incoming MessageBus signals from creating peer
    // connections before localStream is available (race condition that
    // caused voice to fail on first join).
    this.#activeRoomIds.add(room.id);
    this.#setActiveRoomId(room.id);

    if (!this.#isMeshRoom(room.id)) {
      const connected = await this.#livekit.connect(
        room,
        response?.livekit,
        revision
      );
      if (!connected) {
        return;
      }
    }

    this.#addLocalParticipant(room.id);

    if (this.localStream) {
      this.#audioMonitor.ensure(
        room.id,
        this.currentUser?.id,
        this.localStream,
        true
      );
    }

    this.#heartbeat.start(room.id);
    this.#idleTracker.start();

    const latestParticipants =
      this.#connectingParticipantSnapshots.get(room.id) ??
      response?.room?.active_participants;
    this.#connectingParticipantSnapshots.delete(room.id);

    if (latestParticipants) {
      await this.#roster.handleParticipants(room.id, {
        participants: latestParticipants,
      });
    }

    const queuedSignals = this.#connectingSignalQueue.get(room.id) || [];
    this.#connectingSignalQueue.delete(room.id);

    if (this.#isMeshRoom(room.id)) {
      for (const payload of queuedSignals) {
        await this.#meshSignals.handle(room.id, payload);
      }
    }

    this.#connectingRoomIds.delete(room.id);
    this.#bumpConnectionRevision();

    if (this.pttEnabled && this.localStream) {
      this.#pttManager.startListening();
    }

    if (this.watchingRoomId === room.id) {
      this.setWatching(room.id, true);
    }

    playConnectedSound(this.currentUser?.chat_sound);

    // Joining an ephemeral call room alone while someone is still being rung
    // means the other side hasn't picked up yet: loop the waiting tone until
    // a peer arrives or the last ring runs out. Merely being alone isn't
    // enough — rejoining a call everyone has left must stay silent.
    const others = (latestParticipants || []).filter(
      (participant) => Number(participant?.id) !== this.currentUser?.id
    );
    const now = Date.now();
    const ringing = activeRingingEntries(joinedRoom, now);
    if (joinedRoom?.ephemeral && others.length === 0 && ringing.length > 0) {
      const lastRingEndsAt =
        Math.max(...ringing.map((entry) => entry.notified_at * 1000)) +
        RING_SECONDS * 1000;
      startWaitingSound(lastRingEndsAt - now, this.currentUser?.chat_sound);
    }
  }

  leave(room, options = {}) {
    if (!room?.id) {
      return;
    }

    const keepLocalStream = options.keepLocalStream === true;
    // Local-only teardown: everything below runs except DELETE /leave. Used
    // when the server must not close the presence/session that now belongs
    // to someone else (e.g. a newer tab after DUPLICATE_IDENTITY).
    const skipServer = options.skipServer === true;
    const wasConnecting = this.#connectingRoomIds.has(room.id);
    const wasConnected = this.#activeRoomIds.has(room.id);

    if (this.localVideoKind && (wasConnected || wasConnecting)) {
      this.#localVideo.stop({ broadcast: false }).catch(() => {});
    }

    if (wasConnecting) {
      this.#joinRevision++;
    }

    // Hanging up while still ringing (caller waiting alone) ends the ring.
    stopCallSounds();
    this.#connectingParticipantSnapshots.delete(room.id);
    this.#connectingSignalQueue.delete(room.id);
    this.#pttManager.resetActive();
    this.pttActive = false;
    if (!skipServer) {
      // The session id lets the server drop a leave from a stale tab whose
      // session a newer join has already superseded.
      ajax(`/voice/rooms/${room.id}/leave`, {
        type: "DELETE",
        data: { participant_session_id: this.#roomSessions.get(room.id) },
      });
    }
    this.#connectingRoomIds.delete(room.id);
    this.#activeRoomIds.delete(room.id);
    this.#clearActiveRoomId(room.id);
    this.#bumpConnectionRevision();

    if (wasConnected && !keepLocalStream) {
      playDisconnectedSound(this.currentUser?.chat_sound);
    }
    this.#removeLocalParticipant(room.id);
    this.#heartbeat.stop(room.id);

    if (this.#activeRoomIds.size === 0) {
      this.#idleTracker.stop();
      this.#pttManager.stopListening();
    }

    const teardown = () => {
      this.#audioMonitor.teardown(room.id, this.currentUser?.id);
      this.#teardownRoom(room.id);

      if (!keepLocalStream && this.#activeRoomIds.size === 0) {
        this.#localAudio.stop();
      }
    };

    if (wasConnected && !keepLocalStream) {
      const timer = setTimeout(() => {
        this.#deferredTeardownTimers.delete(timer);
        teardown();
      }, 500);
      this.#deferredTeardownTimers.add(timer);
    } else {
      teardown();
    }
  }

  @action
  attachStream(stream, element) {
    if (!element || !stream) {
      return;
    }

    if (element.srcObject === stream) {
      return;
    }

    element.srcObject = stream;
    element.autoplay = true;
    element.playsInline = true;

    const isLocal = stream === this.localStream;
    if (isLocal) {
      element.muted = true;
      element.volume = 0;
    } else {
      const participant = this.#remoteStreamRegistry.participantFor(stream);
      if (participant) {
        const { roomId, userId, screenAudio } = participant;
        this.#participantAudio.trackElement(
          roomId,
          userId,
          element,
          screenAudio ? "screen" : "voice"
        );
        this.#participantAudio.apply(roomId, userId);
      }
      applyOutputDevice(element, this.outputDeviceId);
    }

    if (typeof element.play === "function") {
      try {
        const playPromise = element.play();
        playPromise?.catch?.((error) => {
          if (error?.name === "NotAllowedError") {
            schedulePlaybackResume(element, this.#pendingPlaybackElements);
          } else {
            // eslint-disable-next-line no-console
            console.warn("[voice] audio element failed to play", error);
          }
        });
      } catch (error) {
        if (error?.name === "NotAllowedError") {
          schedulePlaybackResume(element, this.#pendingPlaybackElements);
        } else {
          // eslint-disable-next-line no-console
          console.warn("[voice] audio element failed to play", error);
        }
      }
    }
  }

  setParticipantVolume(roomId, userId, volume) {
    this.#participantAudio.setVolume(roomId, userId, volume);
  }

  getParticipantVolume(roomId, userId) {
    return this.#participantAudio.volumeFor(roomId, userId);
  }

  toggleParticipantMute(roomId, userId) {
    const newMutedState = this.#participantAudio.toggleMuted(roomId, userId);
    this.voiceRooms?.setParticipantMuted(roomId, userId, newMutedState);
    return newMutedState;
  }

  isParticipantMuted(roomId, userId) {
    return this.#participantAudio.isMuted(roomId, userId);
  }

  toggleMute() {
    if (this.pttEnabled) {
      return;
    }

    this.#setMicEnabled(!this.audioEnabled);

    if (this.audioEnabled) {
      playUnmuteSound(this.currentUser?.chat_sound);
      this.#idleTracker.wasAutoMuted = false;
      this.#idleTracker.resetActivity();
    } else {
      playMuteSound(this.currentUser?.chat_sound);
    }

    if (this.audioEnabled && this.deafened) {
      this.deafened = false;
    }

    this.#broadcastMuteState();
  }

  toggleDeafen() {
    this.deafened = !this.deafened;

    if (this.deafened) {
      playDeafenSound(this.currentUser?.chat_sound);
    } else {
      playUndeafenSound(this.currentUser?.chat_sound);
    }

    if (this.deafened) {
      this.#setMicEnabled(false);
    } else {
      this.#setMicEnabled(!this.pttEnabled);
    }

    this.#participantAudio.applyAll();

    this.#broadcastMuteState();
  }

  // --- Quality tiers ---

  // Effective tier: the user's stored preference clamped by the room's
  // optional cap and the site setting cap. Passing no roomId (settings modal
  // opened outside a call) clamps against the site cap only.
  effectiveVoiceQuality(roomId = this.activeRoomId) {
    return clampQuality(
      this.voiceQuality,
      this.#roomQualityCap(roomId),
      this.siteSettings.voice_max_voice_quality
    );
  }

  effectiveCameraQuality(roomId = this.activeRoomId) {
    return clampQuality(
      this.cameraQuality,
      this.#roomQualityCap(roomId),
      this.siteSettings.voice_max_camera_quality
    );
  }

  effectiveScreenQuality(roomId = this.activeRoomId) {
    return clampQuality(
      this.screenQuality,
      this.#roomQualityCap(roomId),
      this.siteSettings.voice_max_screen_share_quality
    );
  }

  allowedVoiceQualityTiers(roomId = this.activeRoomId) {
    return allowedQualityTiers(
      this.#roomQualityCap(roomId),
      this.siteSettings.voice_max_voice_quality
    );
  }

  allowedCameraQualityTiers(roomId = this.activeRoomId) {
    return allowedQualityTiers(
      this.#roomQualityCap(roomId),
      this.siteSettings.voice_max_camera_quality
    );
  }

  allowedScreenQualityTiers(roomId = this.activeRoomId) {
    return allowedQualityTiers(
      this.#roomQualityCap(roomId),
      this.siteSettings.voice_max_screen_share_quality
    );
  }

  @action
  setVoiceQuality(tier) {
    this.voiceQuality = tier;
    setPreferredVoiceQuality(tier);
    this.#applyVoiceQualityToPeers();
  }

  @action
  setCameraQuality(tier) {
    this.cameraQuality = tier;
    setPreferredCameraQuality(tier);
    this.#localVideo.refreshQuality();
  }

  @action
  setScreenQuality(tier) {
    this.screenQuality = tier;
    setPreferredScreenQuality(tier);
    this.#localVideo.refreshQuality();
  }

  @action
  setScreenContent(content) {
    this.screenContent = content;
    setPreferredScreenContent(content);
    this.#localVideo.refreshQuality({ contentHintChanged: true });
  }

  // --- Device selection & input sensitivity ---

  setOutputDevice(deviceId) {
    this.outputDeviceId = deviceId;
    setPreferredOutputDeviceId(deviceId);
    this.#participantAudio.setOutputDevice(deviceId);
  }

  videoAllowedIn(room) {
    return !!(
      this.siteSettings.voice_video_enabled &&
      room?.video_enabled &&
      (room?.room_type !== "stage" || this.#canSpeakInRoom(room))
    );
  }

  videoPublisherCount(roomId) {
    const room = this.voiceRooms?.roomById(roomId);
    return (room?.active_participants || []).filter(
      (participant) =>
        participant?.is_video_on || participant?.is_screen_sharing
    ).length;
  }

  canPublishVideo(roomId) {
    const room = this.voiceRooms?.roomById(roomId);
    if (!room || !this.videoAllowedIn(room)) {
      return false;
    }
    if (!this.#activeRoomIds.has(roomId)) {
      return false;
    }
    if (this.localVideoKind) {
      return true;
    }
    return (
      this.videoPublisherCount(roomId) <
      this.siteSettings.voice_video_max_publishers
    );
  }

  toggleCamera() {
    return this.#localVideo.toggleCamera();
  }

  toggleScreenShare() {
    return this.#localVideo.toggleScreenShare();
  }

  toggleVideoBlur() {
    return this.#localVideo.toggleBlur();
  }

  setVideoBlurAmount(value) {
    this.#localVideo.setBlurAmount(value);
  }

  setVideoInputDevice(deviceId) {
    return this.#localVideo.setInputDevice(deviceId);
  }

  setWatching(roomId, watching, options = {}) {
    if (watching) {
      this.watchingRoomId = roomId;
    } else if (this.watchingRoomId === roomId) {
      this.watchingRoomId = null;
    }

    if (!this.#activeRoomIds.has(roomId)) {
      return;
    }

    // The room page used to hold the only controls that stop a camera or
    // screen share, so leaving it stopped publishing. A persistent call widget
    // is also a visible control surface; when it is present, route changes can
    // keep video alive without leaving capture running invisibly.
    const keepVideo = options.keepVideo === true;
    const stoppingVideo = !watching && !keepVideo && !!this.localVideoKind;
    if (stoppingVideo) {
      this.#localVideo.stop({ broadcast: false }).catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to stop video on page leave", error);
      });
    }

    const localState = { watching_video: watching };
    const data = { watching };
    if (stoppingVideo) {
      localState.is_video_on = false;
      localState.is_screen_sharing = false;
      data.video = false;
      data.screen = false;
    }

    this.voiceRooms?.setParticipantVideoState(
      roomId,
      this.currentUser?.id,
      localState
    );

    data.participant_session_id = this.#roomSessions.get(roomId);
    ajax(`/voice/rooms/${roomId}/state`, {
      type: "POST",
      data,
    }).catch(() => {});

    // The roster flag above drives tiles on both transports; on the SFU the
    // watching state additionally gates the actual video subscriptions.
    if (!this.#isMeshRoom(roomId)) {
      this.#livekit.sessionFor(roomId)?.setVideoSubscriptionsEnabled(watching);
    }
  }

  @action
  attachVideoStream(stream, element) {
    if (!element || !stream) {
      return;
    }

    if (element.srcObject !== stream) {
      element.srcObject = stream;
    }

    // Remote audio plays through the voice canvas sinks; video elements stay
    // muted so the same stream never produces doubled audio.
    element.muted = true;
    element.autoplay = true;
    element.playsInline = true;

    try {
      element.play?.()?.catch?.(() => {});
    } catch {
      // ignore playback errors; the element retries on user interaction
    }
  }

  enablePtt() {
    this.#pttManager.enable();
    this.pttEnabled = true;
    this.pttActive = false;

    this.#setMicEnabled(false);
    this.#broadcastMuteState();

    if (this.#activeRoomIds.size > 0) {
      this.#pttManager.startListening();
    }
  }

  disablePtt() {
    this.#pttManager.disable();
    this.pttEnabled = false;
    this.pttActive = false;

    this.#setMicEnabled(true);
    this.#broadcastMuteState();
  }

  setPttKey(keyCode) {
    if (!this.#pttManager.setKey(keyCode)) {
      return false;
    }
    this.pttKey = keyCode;
    return true;
  }

  toggleAutoStatus() {
    this.autoStatusEnabled = !this.autoStatusEnabled;
    try {
      localStorage.setItem(
        "voice_auto_status_enabled",
        this.autoStatusEnabled ? "true" : "false"
      );
    } catch {
      // ignore storage errors
    }

    if (!this.autoStatusEnabled && this.#activeRoomIds.size > 0) {
      ajax("/user-status.json", { type: "DELETE" }).catch(() => {});
    }
  }

  toggleCallWidgetHidden() {
    this.setCallWidgetHidden(!this.callWidgetHidden);
  }

  setCallWidgetHidden(hidden) {
    this.callWidgetHidden = hidden;
    try {
      localStorage.setItem(
        "voice_call_widget_hidden",
        hidden ? "true" : "false"
      );
    } catch {
      // ignore storage errors
    }
  }

  #setActiveRoomId(roomId) {
    this.activeRoomId = roomId ?? null;
  }

  #clearActiveRoomId(roomId) {
    if (Number(this.activeRoomId) !== Number(roomId)) {
      return;
    }

    this.activeRoomId = this.#activeRoomIds.values().next().value ?? null;
  }

  #canSpeakInRoom(room) {
    return participantCanSpeak(room, this.currentUser?.id);
  }

  #isMeshRoom(roomId) {
    return (this.#roomTransports.get(roomId) ?? "mesh") === "mesh";
  }

  async #acquireMicrophoneWithFeedback() {
    const acquired = await this.#localAudio.acquireMicrophone();
    if (!acquired) {
      reportMicAcquisitionFailure(this.#localAudio.lastAcquisitionError, {
        modal: this.modal,
        toasts: this.toasts,
      });
    }
    return acquired;
  }

  #setMicEnabled(enabled) {
    this.audioEnabled = enabled;
    for (const track of this.localStream?.getAudioTracks() || []) {
      track.enabled = enabled;
    }
  }

  #roomQualityCap(roomId) {
    return this.voiceRooms?.roomById(roomId)?.max_quality_profile;
  }

  async #applyVoiceQualityToPeers() {
    for (const [roomId] of this.#peerManager.allPeerConnections()) {
      await applyVoiceQuality(
        this.#peerManager.micSendersFor(roomId),
        this.effectiveVoiceQuality(roomId)
      );
    }
  }

  #firstActiveRoomId() {
    for (const roomId of this.#activeRoomIds) {
      return roomId;
    }
    return null;
  }

  // Room state updates in voiceRooms; this only surfaces the change to
  // people in the call. The moderator who pressed the button gets no toast —
  // their button state already changed under their pointer.
  #handleRecordingChanged(payload) {
    const startedBySelf =
      payload.recording?.started_by?.id === this.currentUser?.id;

    if (payload.recording) {
      if (!startedBySelf) {
        this.toasts.default({
          duration: 8000,
          data: {
            icon: "record-vinyl",
            message: i18n("voice.room.recording_started_toast"),
          },
        });
      }
    } else {
      this.toasts.default({
        duration: 5000,
        data: { message: i18n("voice.room.recording_stopped_toast") },
      });
    }
  }

  #handleRoomUpdated(roomId) {
    if (!this.localVideoKind) {
      return;
    }

    const room = this.voiceRooms?.roomById(roomId);
    if (room && !this.videoAllowedIn(room)) {
      this.#localVideo.stop().catch(() => {});
      this.toasts.default({
        duration: 5000,
        data: { message: i18n("voice.video.room_disabled") },
      });
    }
  }

  // --- Private orchestration ---

  #broadcastMuteState() {
    for (const roomId of this.#activeRoomIds) {
      this.voiceRooms?.setParticipantMuted(
        roomId,
        this.currentUser?.id,
        !this.audioEnabled
      );
      this.voiceRooms?.setParticipantDeafened(
        roomId,
        this.currentUser?.id,
        this.deafened
      );

      ajax(`/voice/rooms/${roomId}/toggle_mute`, {
        type: "POST",
        data: {
          muted: !this.audioEnabled,
          deafened: this.deafened,
          participant_session_id: this.#roomSessions.get(roomId),
        },
      });
    }
  }

  #registerRoomHandler(roomId) {
    if (this.#roomHandlerCallbacks.has(roomId)) {
      return;
    }

    const callback = (payload) => this.#handleRoomMessage(roomId, payload);
    this.voiceRooms.registerRoomHandler(roomId, callback);
    this.#roomHandlerCallbacks.set(roomId, callback);
  }

  #teardownRoom(roomId) {
    this.#connectingParticipantSnapshots.delete(roomId);
    this.#connectingSignalQueue.delete(roomId);
    this.#roomTransports.delete(roomId);
    this.#roomSessions.delete(roomId);
    this.#presencePending.clearAll(roomId);
    this.#livekit.disconnectRoom(roomId);

    const callback = this.#roomHandlerCallbacks.get(roomId);
    if (callback) {
      this.voiceRooms?.unregisterRoomHandler(roomId, callback);
      this.#roomHandlerCallbacks.delete(roomId);
    }

    this.#peerManager.destroyRoom(roomId);
    this.#removeAllRemoteStreams(roomId);
    this.#audioMonitor.teardownRoom(roomId);
    this.#signaling.clearForRoom(roomId);
    this.#signaling.clearHttpQueue(roomId);
    this.#roomMessageQueue.clear(roomId);
    this.#transcription.stopIfTranscribing(roomId);
  }

  #handleRoomMessage(roomId, payload) {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    // Serialize all message processing per room to prevent async
    // handlers from interleaving (e.g. concurrent participant broadcasts,
    // signals arriving mid-peer-setup, role changes overlapping signals).
    this.#roomMessageQueue
      .enqueue(roomId, () => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }
        return this.#processRoomMessage(roomId, payload);
      })
      .catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to process room message", error);
      });
  }

  async #processRoomMessage(roomId, payload) {
    // eslint-disable-next-line no-console
    console.log(
      `[voice] 📨 MessageBus message: room=${roomId}, type=${payload.type}, active=${this.#activeRoomIds.has(roomId)}`
    );

    if (!this.#activeRoomIds.has(roomId)) {
      if (
        payload.type === "participants" &&
        this.#connectingRoomIds.has(roomId)
      ) {
        this.#connectingParticipantSnapshots.set(
          roomId,
          payload.participants || []
        );
      } else if (
        payload.type === "signal" &&
        this.#connectingRoomIds.has(roomId)
      ) {
        const queue = this.#connectingSignalQueue.get(roomId) || [];
        queue.push(payload);
        this.#connectingSignalQueue.set(roomId, queue);
      } else if (
        payload.type === "kicked" &&
        this.#connectingRoomIds.has(roomId)
      ) {
        this.#handleKicked(roomId);
      }
      return;
    }

    if (payload.type === "signal") {
      // Mesh-only: non-mesh transports never exchange WebRTC signals.
      if (this.#isMeshRoom(roomId)) {
        await this.#meshSignals.handle(roomId, payload);
      }
    } else if (payload.type === "participants") {
      await this.#roster.handleParticipants(roomId, payload);
    } else if (payload.type === "role_change") {
      await this.#roster.handleRoleChange(roomId, payload);
    } else if (payload.type === "hand_raise") {
      this.#roster.handleHandRaise(roomId, payload);
    } else if (payload.type === "kicked") {
      this.#handleKicked(roomId);
    } else if (payload.type === "room_updated") {
      this.#handleRoomUpdated(roomId);
    } else if (payload.type === "recording") {
      this.#handleRecordingChanged(payload);
    }
  }

  #handleKicked(roomId) {
    // eslint-disable-next-line no-console
    console.log(`[voice] kicked from room ${roomId}`);
    this.leave({ id: roomId });
  }

  #currentUserParticipant() {
    if (!this.currentUser) {
      return null;
    }

    return {
      id: this.currentUser.id,
      username: this.currentUser.username,
      name: this.currentUser.name,
      avatar_template: this.currentUser.avatar_template,
    };
  }

  #addLocalParticipant(roomId) {
    const participant = this.#currentUserParticipant();
    if (!participant) {
      return;
    }

    participant.is_muted = !this.audioEnabled;
    participant.is_deafened = this.deafened;
    participant.is_video_on = this.localVideoKind === "camera";
    participant.is_screen_sharing = this.localVideoKind === "screen";
    participant.watching_video = this.watchingRoomId === roomId;

    const room = this.voiceRooms?.roomById(roomId);
    if (room?.membership?.role_name) {
      participant.role = room.membership.role_name;
    }

    this.voiceRooms?.addParticipant(roomId, participant);
  }

  #removeLocalParticipant(roomId) {
    if (!this.currentUser) {
      return;
    }

    this.voiceRooms?.removeParticipant(roomId, this.currentUser.id);
  }

  // Mesh receive-side media boundary: only register (and therefore play) a
  // remote track the sender's server-attested role and the room's media
  // policy allow. On LiveKit the SFU enforces publish permissions instead.
  #registerRemoteTrack(roomId, userId, track, streams) {
    const room = this.voiceRooms?.roomById(roomId);
    if (!remoteTrackAllowed(room, userId, track, streams)) {
      // eslint-disable-next-line no-console
      console.warn(
        `[voice] dropping ${track?.kind} track from user ${userId}: not allowed to publish in room ${roomId}`
      );
      try {
        track?.stop();
      } catch {
        // a remote track may already be ended
      }
      return;
    }

    this.#remoteStreamRegistry.register(roomId, userId, track, streams);
  }

  // Whether the local user may attach media to peers in this room. Honest
  // stage listeners keep their pre-negotiated transceivers receive-only;
  // the receiving side's #registerRemoteTrack is the actual boundary.
  #canPublishMediaIn(roomId) {
    const room = this.voiceRooms?.roomById(roomId);
    return !room || this.#canSpeakInRoom(room);
  }

  #removeAllRemoteStreams(roomId) {
    this.#transcription.detachRoom(roomId);
    this.#remoteStreamRegistry
      .clearRoom(roomId)
      .forEach((userId) => this.#audioMonitor.teardown(roomId, userId));
  }

  #removeRemoteStream(roomId, remoteUserId) {
    if (!this.#remoteStreamRegistry.remove(roomId, remoteUserId)) {
      return;
    }

    this.#transcription.detach(roomId, remoteUserId);
    this.#audioMonitor.teardown(roomId, remoteUserId);
    this.#participantAudio.untrackElement(roomId, remoteUserId);
  }

  #bumpConnectionRevision() {
    this.connectionRevision++;
  }

  #heartbeatPayload(roomId) {
    const data = {
      participant_session_id: this.#roomSessions.get(roomId),
    };
    if (this.idleState !== this.#idleTracker.lastBroadcastedIdleState) {
      data.idle_state = this.idleState;
      this.#idleTracker.lastBroadcastedIdleState = this.idleState;
    }
    return data;
  }

  #handleJoinFailure(roomId) {
    this.#connectingRoomIds.delete(roomId);
    this.#bumpConnectionRevision();
    this.#activeRoomIds.delete(roomId);
    this.#heartbeat.stop(roomId);
    this.#removeLocalParticipant(roomId);
    this.#teardownRoom(roomId);

    if (this.#activeRoomIds.size === 0) {
      this.#localAudio.stop();
    }
  }

  #syncLocalStreamState() {
    this.#applyLocalTrackState(this.localStream);

    if (!this.currentUser?.id) {
      return;
    }

    for (const roomId of this.#activeRoomIds) {
      if (this.localStream) {
        this.#audioMonitor.ensure(
          roomId,
          this.currentUser.id,
          this.localStream,
          true
        );
      } else {
        this.#audioMonitor.teardown(roomId, this.currentUser.id);
      }
    }

    this.#transcription.syncLocalTap();
  }

  #applyLocalTrackState(stream) {
    for (const track of stream?.getAudioTracks?.() || []) {
      track.enabled = this.audioEnabled;
    }
  }

  async #replaceTrackOnAllPeers() {
    const newTrack = this.localStream?.getAudioTracks()?.[0];
    if (!newTrack) {
      return;
    }

    await this.#livekit.replaceAudioTrack(newTrack);
    await this.#peerManager.replaceMicTrack(newTrack);
  }

  // --- Idle tracker callbacks ---

  #handleIdleStateChange(newState, wasAfk) {
    if (newState === "active" && this.idleState !== "active") {
      this.idleState = "active";
      this.#idleTracker.lastBroadcastedIdleState = null;

      for (const roomId of this.#activeRoomIds) {
        this.voiceRooms?.setParticipantIdleState(
          roomId,
          this.currentUser?.id,
          "active"
        );
      }

      if (wasAfk && this.#idleTracker.wasAutoMuted) {
        this.toasts.success({
          duration: 5000,
          data: {
            message: i18n("voice.idle.auto_muted"),
            actions: [
              {
                label: i18n("voice.idle.click_to_unmute"),
                class: "btn-primary",
                action: () => this.toggleMute(),
              },
            ],
          },
        });
      }
    } else if (newState === "idle" && this.idleState !== "idle") {
      this.idleState = "idle";
      this.#idleTracker.lastBroadcastedIdleState = null;

      for (const roomId of this.#activeRoomIds) {
        this.voiceRooms?.setParticipantIdleState(
          roomId,
          this.currentUser?.id,
          "idle"
        );
      }
    }
  }

  #handleAutoMute() {
    if (this.idleState !== "afk") {
      this.idleState = "afk";
      this.#idleTracker.lastBroadcastedIdleState = null;

      if (this.audioEnabled) {
        this.#setMicEnabled(false);
        this.#broadcastMuteState();
      }

      for (const roomId of this.#activeRoomIds) {
        this.voiceRooms?.setParticipantIdleState(
          roomId,
          this.currentUser?.id,
          "afk"
        );
      }
    }
  }

  #handleIdleDisconnect() {
    const roomNames = [];
    for (const roomId of this.#activeRoomIds) {
      const room = this.voiceRooms?.roomById(roomId);
      if (room) {
        roomNames.push(room.name);
      }
    }

    for (const roomId of [...this.#activeRoomIds]) {
      this.leave({ id: roomId });
    }

    const name = roomNames[0] || "the room";
    this.toasts.default({
      duration: 8000,
      data: { message: i18n("voice.idle.disconnected", { room: name }) },
    });
  }

  // --- Push-to-Talk ---

  #handlePttPress() {
    this.pttActive = true;
    this.#setMicEnabled(true);
    this.#broadcastMuteState();
  }

  #handlePttRelease() {
    this.pttActive = false;
    this.#setMicEnabled(false);
  }
}
