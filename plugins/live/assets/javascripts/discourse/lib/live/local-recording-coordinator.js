import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { deliverBlobDownload } from "discourse/lib/download-blob";
import liveLog from "discourse/plugins/live/discourse/lib/live/logger";
import LocalRecorder, { recordingFilename } from "./local-recorder.js";

// Owns the current user's local recording (at most one, of one room) and the
// roster flag that shows everyone else it's running. The webrtc service
// forwards stream changes and room teardown here.
export default class LocalRecordingCoordinator {
  @tracked roomId = null;
  @tracked starting = false;

  #recorder = null;
  // Other participants known to be recording, per room, so only a new
  // recorder triggers a notice.
  #knownRecorders = new Map();

  #getCurrentUserId;
  #getParticipantSessionId;
  #getRoom;
  #isActiveRoom;
  #getAudioTracks;
  #setParticipantRecording;
  #showNotice;
  #showError;

  #confirmUnload = (event) => {
    event.preventDefault();
    event.returnValue = "";
  };

  constructor({
    getCurrentUserId,
    getParticipantSessionId,
    getRoom,
    isActiveRoom,
    getAudioTracks,
    setParticipantRecording,
    showNotice,
    showError,
  }) {
    this.#getCurrentUserId = getCurrentUserId;
    this.#getParticipantSessionId = getParticipantSessionId;
    this.#getRoom = getRoom;
    this.#isActiveRoom = isActiveRoom;
    this.#getAudioTracks = getAudioTracks;
    this.#setParticipantRecording = setParticipantRecording;
    this.#showNotice = showNotice;
    this.#showError = showError;
  }

  get busy() {
    return this.starting || !!this.roomId;
  }

  isRecording(roomId) {
    return !!this.roomId && Number(this.roomId) === Number(roomId);
  }

  async start(roomId, displayStream = null) {
    if (this.busy || !this.#isActiveRoom(roomId)) {
      displayStream?.getTracks().forEach((track) => track.stop());
      return;
    }

    this.starting = true;
    let recorder;
    try {
      recorder = new LocalRecorder({
        displayStream,
        onEnded: () => this.stop(),
      });
      recorder.sync(this.#getAudioTracks(roomId));
      await recorder.start(`${roomId}-${Date.now()}`);
    } catch (error) {
      liveLog.warn("[live] local recording failed to start", error);
      recorder?.discard();
      displayStream?.getTracks().forEach((track) => track.stop());
      this.#showError("live.local_recording.start_failed");
      return;
    } finally {
      this.starting = false;
    }

    // Left the call while the recorder was starting.
    if (!this.#isActiveRoom(roomId)) {
      recorder.discard();
      return;
    }

    this.#recorder = recorder;
    this.roomId = roomId;
    window.addEventListener("beforeunload", this.#confirmUnload);
    this.#broadcast(roomId, true);
  }

  async stop() {
    const recorder = this.#recorder;
    const roomId = this.roomId;
    if (!recorder) {
      return;
    }

    this.#recorder = null;
    this.roomId = null;
    window.removeEventListener("beforeunload", this.#confirmUnload);
    this.#broadcast(roomId, false);

    try {
      const blob = await recorder.stop();
      const prefix = this.#getRoom(roomId)?.slug || "live-call";
      await deliverBlobDownload(blob, {
        fallbackFilename: recordingFilename(prefix, blob.type),
      });
      this.#showNotice("live.local_recording.saved");
    } catch (error) {
      liveLog.warn("[live] local recording failed to save", error);
      this.#showError("live.local_recording.save_failed");
    }
  }

  sync() {
    if (this.#recorder) {
      this.#recorder.sync(this.#getAudioTracks(this.roomId));
    }
  }

  stopIfRecording(roomId) {
    if (this.isRecording(roomId)) {
      this.stop();
    }
  }

  // Records which other participants are recording and returns the
  // usernames of those who weren't before. The first roster seen for a room
  // only sets the baseline.
  trackRecorders(roomId, participants) {
    const currentUserId = this.#getCurrentUserId();
    const recorders = new Map(
      (participants || [])
        .filter(
          (participant) =>
            participant?.is_recording_locally &&
            Number(participant.id) !== currentUserId
        )
        .map((participant) => [Number(participant.id), participant.username])
    );

    const previous = this.#knownRecorders.get(roomId);
    this.#knownRecorders.set(roomId, new Set(recorders.keys()));
    if (!previous) {
      return [];
    }

    return [...recorders]
      .filter(([id]) => !previous.has(id))
      .map(([, username]) => username);
  }

  forgetRoom(roomId) {
    this.#knownRecorders.delete(roomId);
  }

  destroy() {
    window.removeEventListener("beforeunload", this.#confirmUnload);
    this.#recorder?.discard();
    this.#recorder = null;
    this.roomId = null;
    this.#knownRecorders.clear();
  }

  // Best effort, like the transcript's flag: the recording itself never
  // depends on the server. Skipped once the room is gone (leave teardown),
  // since the roster entry dies with the membership.
  #broadcast(roomId, recording) {
    if (!this.#isActiveRoom(roomId)) {
      return;
    }

    this.#setParticipantRecording(roomId, recording);
    ajax(`/live/rooms/${roomId}/state`, {
      type: "POST",
      data: {
        recording_locally: recording,
        participant_session_id: this.#getParticipantSessionId(roomId),
      },
    }).catch(() => {});
  }
}
