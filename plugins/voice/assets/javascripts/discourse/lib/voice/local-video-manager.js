import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import BackgroundBlurManager from "./background-blur";
import {
  cameraConstraints,
  preferredVideoInputDeviceId,
  setPreferredVideoInputDeviceId,
} from "./media-devices";
import PeerManager from "./peer-manager";
import { SCREEN_CONTENT_MOTION } from "./quality-preferences";
import {
  applyScreenAudioQuality,
  applyVideoQuality,
  screenCaptureFramerate,
} from "./video-quality";

// Owns the local video pipeline: camera/screen capture, the optional
// background-blur wrap, device switching, per-peer sender sync and the
// is_video_on/is_screen_sharing state broadcast.
export default class LocalVideoManager {
  @tracked stream = null;
  @tracked kind = null;
  @tracked blurEnabled = BackgroundBlurManager.isPreferred();
  @tracked blurAmount = BackgroundBlurManager.storedAmount();
  @tracked inputDeviceId = preferredVideoInputDeviceId();

  #rawStream = null;
  #backgroundBlur = null;

  // All async mutations of the video pipeline (blur toggle, device switch)
  // run through this queue so they can't interleave, and each op validates
  // the epoch after every await so a camera stop/restart during the await
  // (which can take seconds on first model load) is detected instead of
  // resurrecting streams that were already stopped.
  #queue = Promise.resolve();
  #epoch = 0;

  #peerManager;
  #getParticipantSessionId;
  #getLivekitSession;
  #isMeshRoom;
  #isActiveRoom;
  #isConnectingRoom;
  #getFirstActiveRoomId;
  #getActiveRoomId;
  #getRoom;
  #canPublishVideo;
  #getCameraQuality;
  #getScreenQuality;
  #getScreenContent;
  #isBlurAllowed;
  #setParticipantVideoState;
  #showError;
  #onScreenShareEnded;

  constructor(options) {
    this.#peerManager = options.peerManager;
    this.#getParticipantSessionId =
      options.getParticipantSessionId ?? (() => undefined);
    this.#getLivekitSession = options.getLivekitSession;
    this.#isMeshRoom = options.isMeshRoom;
    this.#isActiveRoom = options.isActiveRoom;
    this.#isConnectingRoom = options.isConnectingRoom;
    this.#getFirstActiveRoomId = options.getFirstActiveRoomId;
    this.#getActiveRoomId = options.getActiveRoomId;
    this.#getRoom = options.getRoom;
    this.#canPublishVideo = options.canPublishVideo;
    this.#getCameraQuality = options.getCameraQuality;
    this.#getScreenQuality = options.getScreenQuality;
    this.#getScreenContent = options.getScreenContent;
    this.#isBlurAllowed = options.isBlurAllowed;
    this.#setParticipantVideoState = options.setParticipantVideoState;
    this.#showError = options.showError;
    this.#onScreenShareEnded = options.onScreenShareEnded;
  }

  get blurSupported() {
    return BackgroundBlurManager.isSupported();
  }

  get track() {
    return this.stream?.getVideoTracks()?.[0] || null;
  }

  get screenAudioTrack() {
    if (this.kind !== "screen") {
      return null;
    }
    return this.stream?.getAudioTracks()?.[0] || null;
  }

  trackFor(roomId, remoteUserId) {
    const track = this.track;
    if (!track) {
      return null;
    }

    if (!this.#isActiveRoom(roomId) && !this.#isConnectingRoom(roomId)) {
      return null;
    }

    const room = this.#getRoom(roomId);
    const participant = (room?.active_participants || []).find(
      (entry) => Number(entry?.id) === Number(remoteUserId)
    );

    return participant?.watching_video ? track : null;
  }

  screenAudioTrackFor(roomId, remoteUserId) {
    if (!this.screenAudioTrack) {
      return null;
    }
    return this.trackFor(roomId, remoteUserId) ? this.screenAudioTrack : null;
  }

  destroy() {
    this.stream?.getTracks().forEach((track) => track.stop());
    this.stream = null;
    this.kind = null;
    this.#teardownEffects();
  }

  async toggleCamera() {
    if (this.kind === "camera") {
      await this.stop();
      return;
    }

    await this.start("camera");
  }

  async toggleScreenShare() {
    if (this.kind === "screen") {
      await this.stop();
      return;
    }

    await this.start("screen");
  }

  #enqueueOp(operation) {
    const run = this.#queue.then(operation, operation);
    this.#queue = run.catch(() => {});
    return run;
  }

  toggleBlur() {
    return this.#enqueueOp(() => this.#toggleBlurOp());
  }

  async #toggleBlurOp() {
    const enabled = !this.blurEnabled;
    this.blurEnabled = enabled;
    BackgroundBlurManager.setPreference(enabled);
    await this.#reconcileBlurOp();
  }

  // Brings the pipeline in line with the current preference: wraps or
  // unwraps the published camera stream. A no-op when the camera is off
  // (the preference simply applies at the next camera start) or when the
  // pipeline already matches.
  async #reconcileBlurOp() {
    if (this.kind !== "camera") {
      return;
    }

    const wantBlur =
      this.blurEnabled && this.#isBlurAllowed() && this.blurSupported;

    if (wantBlur === !!this.#backgroundBlur) {
      return;
    }

    if (wantBlur) {
      const raw = this.stream;
      const epoch = this.#epoch;
      const result = await this.#createBackgroundBlur(raw);

      // The camera may have been stopped or replaced, or blur toggled back
      // off, while the model loaded.
      if (epoch !== this.#epoch || this.stream !== raw) {
        result?.manager.teardown();
        return;
      }

      if (!result) {
        this.#revertBlurPreference();
        return;
      }

      if (!this.blurEnabled) {
        result.manager.teardown();
        return;
      }

      this.#backgroundBlur = result.manager;
      this.#rawStream = raw;
      this.stream = result.processed;
    } else {
      this.stream = this.#rawStream;
      this.#teardownEffects();
    }

    const roomId = this.#getFirstActiveRoomId();
    if (roomId) {
      await this.syncSenders(roomId);
    }
  }

  #revertBlurPreference({ silent = false } = {}) {
    this.blurEnabled = false;
    BackgroundBlurManager.setPreference(false);
    if (!silent) {
      this.#showError("voice.video_settings.blur_failed");
    }
  }

  setBlurAmount(value) {
    const clamped = Math.max(0, Math.min(100, Math.round(value)));
    this.blurAmount = clamped;
    BackgroundBlurManager.storeAmount(clamped);
    this.#backgroundBlur?.setAmount(clamped);
  }

  setInputDevice(deviceId) {
    return this.#enqueueOp(() => this.#setInputDeviceOp(deviceId));
  }

  async #setInputDeviceOp(deviceId) {
    const previousDeviceId = this.inputDeviceId;
    this.inputDeviceId = deviceId;

    if (this.kind !== "camera") {
      setPreferredVideoInputDeviceId(deviceId);
      return true;
    }

    const epoch = this.#epoch;
    const constraints = {
      video: cameraConstraints(deviceId, this.#getCameraQuality(), {
        exact: true,
      }),
    };

    let newStream;
    try {
      newStream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (error) {
      if (!this.#cameraBusyError(error)) {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to switch camera", error);
        this.inputDeviceId = previousDeviceId;
        this.#showSwitchError(error);
        return false;
      }

      if (epoch !== this.#epoch || this.kind !== "camera") {
        setPreferredVideoInputDeviceId(deviceId);
        return true;
      }

      // Phones expose a single camera pipeline: the next device can't open
      // while the current one is still capturing, so release ours and retry.
      this.#stopCurrentCapture();

      try {
        newStream = await navigator.mediaDevices.getUserMedia(constraints);
      } catch (retryError) {
        return this.#rollbackSwitch(previousDeviceId, epoch, retryError);
      }
    }

    setPreferredVideoInputDeviceId(deviceId);
    return this.#swapCameraStream(newStream, epoch);
  }

  // Failure modes for busy hardware, as opposed to a denied permission or a
  // missing device.
  #cameraBusyError(error) {
    return error?.name === "NotReadableError" || error?.name === "AbortError";
  }

  #stopCurrentCapture() {
    const capture = this.#rawStream ?? this.stream;
    capture?.getVideoTracks().forEach((track) => track.stop());
  }

  #showSwitchError(error) {
    this.#showError(
      error?.name === "NotAllowedError"
        ? "voice.video.camera_switch_denied"
        : "voice.video.camera_switch_failed"
    );
  }

  // The old capture was already released for the retry, so a failed switch
  // can't silently keep the previous stream: reacquire it, and if even that
  // fails treat the camera as gone.
  async #rollbackSwitch(previousDeviceId, epoch, error) {
    // eslint-disable-next-line no-console
    console.warn("[voice] failed to switch camera", error);
    this.inputDeviceId = previousDeviceId;

    if (epoch === this.#epoch && this.kind === "camera") {
      let previousStream;
      try {
        previousStream = await navigator.mediaDevices.getUserMedia({
          video: cameraConstraints(previousDeviceId, this.#getCameraQuality()),
        });
      } catch {
        await this.stop();
      }

      if (previousStream) {
        await this.#swapCameraStream(previousStream, epoch);
      }
    }

    this.#showSwitchError(error);
    return false;
  }

  async #swapCameraStream(newStream, epoch) {
    const track = newStream.getVideoTracks()[0];

    // The camera may have been stopped while the new capture started; the
    // preference is kept but nothing is swapped.
    if (epoch !== this.#epoch || this.kind !== "camera") {
      newStream.getTracks().forEach((streamTrack) => streamTrack.stop());
      return true;
    }

    if (!track) {
      newStream.getTracks().forEach((streamTrack) => streamTrack.stop());
      return false;
    }

    track.contentHint = "motion";

    const oldStream = this.stream;
    const oldRaw = this.#rawStream;

    let outgoingStream = newStream;
    let blurResult = null;

    if (this.#backgroundBlur) {
      blurResult = await this.#createBackgroundBlur(newStream);

      if (
        epoch !== this.#epoch ||
        this.kind !== "camera" ||
        this.stream !== oldStream
      ) {
        blurResult?.manager.teardown();
        newStream.getTracks().forEach((streamTrack) => streamTrack.stop());
        return true;
      }

      if (blurResult) {
        outgoingStream = blurResult.processed;
      } else {
        this.#revertBlurPreference();
      }
    }

    this.#backgroundBlur?.teardown();
    this.#backgroundBlur = blurResult?.manager ?? null;
    this.#rawStream = blurResult ? newStream : null;
    this.stream = outgoingStream;

    const swappedEpoch = ++this.#epoch;
    track.addEventListener(
      "ended",
      () => this.#handleTrackEnded(swappedEpoch, "camera"),
      { once: true }
    );

    oldStream?.getTracks().forEach((streamTrack) => streamTrack.stop());
    if (oldRaw && oldRaw !== oldStream) {
      oldRaw.getTracks().forEach((streamTrack) => streamTrack.stop());
    }

    const roomId = this.#getFirstActiveRoomId();
    if (roomId) {
      await this.syncSenders(roomId);
    }

    return true;
  }

  // Builds the blur pipeline without touching manager state, so callers can
  // validate that the world hasn't changed across the await before wiring
  // the result in. Returns null when the effect can't start (asset fetch
  // failed, GPU unavailable, …).
  async #createBackgroundBlur(rawStream) {
    const manager = new BackgroundBlurManager();
    try {
      const processed = await manager.setup(rawStream, this.blurAmount);
      processed.getVideoTracks().forEach((track) => {
        track.contentHint = "motion";
      });
      return { manager, processed };
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn("[voice] failed to start background blur", error);
      manager.teardown();
      return null;
    }
  }

  #teardownEffects() {
    this.#backgroundBlur?.teardown();
    this.#backgroundBlur = null;

    if (this.#rawStream) {
      if (this.#rawStream !== this.stream) {
        this.#rawStream.getTracks().forEach((track) => track.stop());
      }
      this.#rawStream = null;
    }
  }

  async start(kind, { shouldContinue, silent = false } = {}) {
    const roomId = this.#getFirstActiveRoomId();
    if (!roomId) {
      return;
    }

    if (!this.#canPublishVideo(roomId)) {
      if (!silent) {
        this.#showError("voice.video.publisher_limit");
      }
      return;
    }

    // Capture must be the first await: Firefox only allows getDisplayMedia
    // while the click's transient activation is alive, and awaiting anything
    // else first (e.g. stopping the current camera) consumes it. The old
    // stream is torn down after the picker succeeds, which also keeps the
    // camera running when the user cancels the picker.
    let stream;
    try {
      if (kind === "screen") {
        // Tab/system audio rides along for watch-along use. Voice processing
        // is disabled because it is tuned for speech and mangles content
        // audio; browsers without display-audio support just return no audio
        // track. The user can still untick audio in the picker.
        stream = await navigator.mediaDevices.getDisplayMedia({
          video: {
            frameRate: {
              max: screenCaptureFramerate(this.#getScreenQuality(roomId)),
            },
          },
          audio: {
            echoCancellation: false,
            noiseSuppression: false,
            autoGainControl: false,
          },
          systemAudio: "include",
        });
      } else {
        stream = await navigator.mediaDevices.getUserMedia({
          video: cameraConstraints(
            this.inputDeviceId,
            this.#getCameraQuality(roomId)
          ),
        });
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.warn(`[voice] failed to obtain ${kind} stream`, error);
      if (
        !silent &&
        error?.name !== "NotAllowedError" &&
        error?.name !== "AbortError"
      ) {
        this.#showError("voice.video.capture_failed");
      }
      return;
    }

    // The user may have left the room while the capture picker was open.
    if (!this.#isActiveRoom(roomId) || (shouldContinue && !shouldContinue())) {
      stream.getTracks().forEach((streamTrack) => streamTrack.stop());
      return;
    }

    if (this.kind) {
      await this.stop({ broadcast: false });
    }

    const track = stream.getVideoTracks()[0];
    if (!track) {
      stream.getTracks().forEach((streamTrack) => streamTrack.stop());
      return;
    }

    // Steers the encoder's sharpness/smoothness trade-off; the matching
    // degradationPreference is applied per-sender in applyVideoQuality.
    if (kind === "screen" && "contentHint" in track) {
      track.contentHint =
        this.#getScreenContent() === SCREEN_CONTENT_MOTION
          ? "motion"
          : "detail";
    }

    const epoch = ++this.#epoch;

    track.contentHint = kind === "screen" ? "detail" : "motion";
    track.addEventListener("ended", () => this.#handleTrackEnded(epoch, kind), {
      once: true,
    });

    const audioTrack =
      kind === "screen" ? stream.getAudioTracks()[0] : undefined;
    if (audioTrack) {
      audioTrack.contentHint = "music";
    }

    let outgoingStream = stream;
    if (
      kind === "camera" &&
      this.blurEnabled &&
      this.#isBlurAllowed() &&
      this.blurSupported
    ) {
      const result = await this.#createBackgroundBlur(stream);

      if (
        epoch !== this.#epoch ||
        !this.#isActiveRoom(roomId) ||
        (shouldContinue && !shouldContinue())
      ) {
        result?.manager.teardown();
        stream.getTracks().forEach((streamTrack) => streamTrack.stop());
        return;
      }

      if (result) {
        this.#backgroundBlur = result.manager;
        this.#rawStream = stream;
        outgoingStream = result.processed;
      } else {
        this.#revertBlurPreference({ silent });
      }
    }

    this.stream = outgoingStream;
    this.kind = kind;

    try {
      await this.#broadcastState(roomId);
    } catch (error) {
      await this.stop({ broadcast: false });
      if (!silent) {
        popupAjaxError(error);
      }
      return;
    }

    if (!this.#ownsPipeline(epoch, outgoingStream, kind)) {
      return;
    }
    if (shouldContinue && !shouldContinue()) {
      await this.stop();
      return;
    }

    await this.syncSenders(roomId);

    if (!this.#ownsPipeline(epoch, outgoingStream, kind)) {
      return;
    }
    if (shouldContinue && !shouldContinue()) {
      await this.stop();
      return;
    }

    // Applies any blur preference change that raced this startup (e.g. the
    // toggle was flipped while the model loaded for the initial wrap).
    this.#enqueueOp(() => this.#reconcileBlurOp());
  }

  async stop({ broadcast = true } = {}) {
    // Invalidates any queued pipeline op that is mid-await on this session.
    this.#epoch++;

    const roomId = this.#getFirstActiveRoomId();
    const stream = this.stream;

    this.stream = null;
    this.kind = null;

    stream?.getTracks().forEach((track) => track.stop());
    this.#teardownEffects();

    if (roomId) {
      await this.syncSenders(roomId);
      if (broadcast) {
        await this.#broadcastState(roomId).catch(() => {});
      }
    }
  }

  #ownsPipeline(epoch, stream, kind) {
    return (
      epoch === this.#epoch && this.stream === stream && this.kind === kind
    );
  }

  #handleTrackEnded(epoch, endedKind) {
    if (epoch !== this.#epoch || endedKind !== this.kind) {
      return;
    }
    this.stop()
      .then(() => {
        if (endedKind === "screen") {
          this.#onScreenShareEnded?.();
        }
      })
      .catch((error) => {
        // eslint-disable-next-line no-console
        console.warn("[voice] failed to stop local video", error);
      });
  }

  #applyContentHint() {
    if (this.kind !== "screen") {
      return;
    }
    const track = this.stream?.getVideoTracks?.()?.[0];
    if (track && "contentHint" in track) {
      track.contentHint =
        this.#getScreenContent() === SCREEN_CONTENT_MOTION
          ? "motion"
          : "detail";
    }
  }

  // Live re-apply after a preference change: encoder ceilings are cheap
  // (setParameters, no renegotiation) and camera capture follows via
  // applyConstraints. Screen capture framerate and LiveKit publish options
  // are fixed at capture/publish time and pick up the change on the next
  // share or join.
  async refreshQuality({ contentHintChanged = false } = {}) {
    if (contentHintChanged) {
      this.#applyContentHint();
    }

    const roomId = this.#getActiveRoomId();
    if (!roomId || !this.kind) {
      return;
    }

    if (this.kind === "camera") {
      const track =
        this.#rawStream?.getVideoTracks?.()?.[0] ??
        this.stream?.getVideoTracks?.()?.[0];
      if (track) {
        try {
          await track.applyConstraints(
            cameraConstraints(
              this.inputDeviceId,
              this.#getCameraQuality(roomId)
            )
          );
        } catch (error) {
          // eslint-disable-next-line no-console
          console.warn("[voice] failed to re-apply camera constraints", error);
        }
      }
    }

    await this.#applyQuality(roomId);
  }

  // Each peer has a dedicated sender, so video is only attached toward peers
  // currently watching the room page — every skipped peer saves an entire
  // encoder session, not just bandwidth.
  async syncSenders(roomId) {
    if (!this.#isMeshRoom(roomId)) {
      // The SFU is published to once regardless of watchers; per-watcher
      // receive gating happens on the subscriber side instead
      // (setVideoSubscriptionsEnabled).
      await this.#getLivekitSession(roomId)?.syncLocalVideo(
        this.track,
        this.screenAudioTrack,
        this.kind
      );
      return;
    }

    const peers = this.#peerManager.getRoomPeers(roomId);
    if (!peers) {
      return;
    }

    for (const [remoteUserId, pc] of peers) {
      const desired = this.trackFor(roomId, remoteUserId);

      const transceiver = PeerManager.videoTransceiverFor(pc);
      if (transceiver && transceiver.sender.track !== desired) {
        try {
          await transceiver.sender.replaceTrack(desired);
        } catch (error) {
          // eslint-disable-next-line no-console
          console.warn(
            `[voice] failed to sync video sender for user ${remoteUserId}`,
            error
          );
        }
      }

      // Screen audio follows the same watching gate as the video track, so
      // non-watchers don't get a soundtrack without a picture.
      const desiredAudio = desired ? this.screenAudioTrack : null;
      const audioTransceiver = PeerManager.screenAudioTransceiverFor(pc);
      if (audioTransceiver && audioTransceiver.sender.track !== desiredAudio) {
        try {
          await audioTransceiver.sender.replaceTrack(desiredAudio);
          if (desiredAudio) {
            await applyScreenAudioQuality(audioTransceiver.sender);
          }
        } catch (error) {
          // eslint-disable-next-line no-console
          console.warn(
            `[voice] failed to sync screen audio sender for user ${remoteUserId}`,
            error
          );
        }
      }
    }

    await this.#applyQuality(roomId);
  }

  async #applyQuality(roomId) {
    const peers = this.#peerManager.getRoomPeers(roomId);
    if (!peers || !this.kind) {
      return;
    }

    const sendingSenders = [];
    for (const [, pc] of peers) {
      const sender = PeerManager.videoTransceiverFor(pc)?.sender;
      if (sender?.track) {
        sendingSenders.push(sender);
      }
    }

    await applyVideoQuality(sendingSenders, this.kind, {
      tier:
        this.kind === "screen"
          ? this.#getScreenQuality(roomId)
          : this.#getCameraQuality(roomId),
      screenContent: this.#getScreenContent(),
    });
  }

  #broadcastState(roomId) {
    const video = this.kind === "camera";
    const screen = this.kind === "screen";

    this.#setParticipantVideoState(roomId, {
      is_video_on: video,
      is_screen_sharing: screen,
    });

    return ajax(`/voice/rooms/${roomId}/state`, {
      type: "POST",
      data: {
        video,
        screen,
        participant_session_id: this.#getParticipantSessionId(roomId),
      },
    });
  }
}
