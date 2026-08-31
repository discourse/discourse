import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import Composer from "discourse/models/composer";
import Draft from "discourse/models/draft";
import { i18n } from "discourse-i18n";
import SubtitlesManager from "./subtitles";
import TranscriptDraftSync from "./transcript-draft-sync";
import { transcriptToMarkdown } from "./transcript-markdown";
import TranscriptRecorder from "./transcript-recorder";

// Owns the speech-to-text pipeline and both of its consumers: the caption
// overlay and the transcript recorder (with its composer-draft sync). The
// webrtc service delegates its subtitles/transcript API here and forwards
// stream attach/detach events as rooms and participants come and go.
export default class TranscriptionCoordinator {
  @tracked enabled = false;
  @tracked loading = false;
  @tracked progress = null;
  @tracked captions = [];
  @tracked revision = 0;

  #subtitles;
  #transcript;
  #transcriptDraft;
  #captionCounter = 0;

  #siteSettings;
  #getParticipantSessionId;
  #getCurrentUserId;
  #getRoom;
  #isActiveRoom;
  #getActiveRoomIds;
  #getRemoteUserIds;
  #getRemoteStream;
  #getLocalStream;
  #setParticipantTranscribing;
  #saveDraft;
  #openComposer;
  #showError;

  constructor({
    siteSettings,
    getParticipantSessionId = () => undefined,
    getCurrentUserId,
    getRoom,
    isActiveRoom,
    getActiveRoomIds,
    getRemoteUserIds,
    getRemoteStream,
    getLocalStream,
    setParticipantTranscribing,
    saveDraft,
    openComposer,
    showError,
  }) {
    this.#siteSettings = siteSettings;
    this.#getParticipantSessionId = getParticipantSessionId;
    this.#getCurrentUserId = getCurrentUserId;
    this.#getRoom = getRoom;
    this.#isActiveRoom = isActiveRoom;
    this.#getActiveRoomIds = getActiveRoomIds;
    this.#getRemoteUserIds = getRemoteUserIds;
    this.#getRemoteStream = getRemoteStream;
    this.#getLocalStream = getLocalStream;
    this.#setParticipantTranscribing = setParticipantTranscribing;
    this.#saveDraft = saveDraft;
    this.#openComposer = openComposer;
    this.#showError = showError;

    this.#transcript = new TranscriptRecorder({
      onChange: () => {
        this.revision++;
        this.#transcriptDraft?.markDirty();
      },
    });

    this.#transcriptDraft = new TranscriptDraftSync({
      save: (key, sequence, data) => this.#saveDraft(key, sequence, data),
      buildData: () => this.#draftData(),
    });

    this.#subtitles = new SubtitlesManager({
      onCaption: (roomId, userId, utterance) => {
        this.#upsertCaption(roomId, userId, utterance);
        this.#transcript.record(
          roomId,
          userId,
          this.#participantUsername(roomId, userId),
          utterance
        );
      },
      onLoadingChange: () => {
        this.loading = this.#subtitles.loading;
        if (!this.loading) {
          this.progress = null;
        }
      },
      onProgress: ({ loaded, total }) => {
        if (total > 0) {
          this.progress = Math.min(100, Math.round((loaded / total) * 100));
        }
      },
      onError: (error) => this.#handleError(error),
    });

    this.enabled = this.available && this.#subtitles.isPreferred();
    this.#subtitles.setEnabled(this.enabled, {
      modelBaseUrl: this.#modelBaseUrl,
    });
  }

  destroy() {
    this.#subtitles.destroy();
    this.#transcriptDraft.dispose();
  }

  get available() {
    return (
      !!this.#siteSettings.voice_subtitles_enabled &&
      SubtitlesManager.isSupported()
    );
  }

  get #modelBaseUrl() {
    return this.#siteSettings.voice_stt_model_base_url || null;
  }

  toggle() {
    this.enabled = !this.enabled;
    this.#subtitles.setPreference(this.enabled);
    this.#syncSttEngine();
  }

  get recording() {
    this.revision;
    return this.#transcript.recording;
  }

  get roomId() {
    this.revision;
    return this.#transcript.roomId;
  }

  get entries() {
    this.revision;
    return this.#transcript.entries;
  }

  get entriesRoomId() {
    this.revision;
    return this.#transcript.entriesRoomId;
  }

  get startedAt() {
    this.revision;
    return this.#transcript.startedAt;
  }

  isTranscribingRoom(roomId) {
    return this.recording && Number(this.roomId) === Number(roomId);
  }

  toggleRecording(roomId) {
    if (this.recording) {
      this.#stopRecording();
      return;
    }

    if (!this.available || !this.#isActiveRoom(roomId)) {
      return;
    }

    this.#transcript.start(roomId);
    this.#transcriptDraft.start(roomId, this.#transcript.startedAt);
    this.#syncSttEngine();
    this.#broadcastTranscribingState(roomId, true);
  }

  // Leaving the recorded room ends the recording; the transcript gathered so
  // far is kept for consumption.
  stopIfTranscribing(roomId) {
    if (this.isTranscribingRoom(roomId)) {
      this.#stopRecording();
    }
  }

  #stopRecording() {
    if (!this.#transcript.recording) {
      return;
    }

    const roomId = this.#transcript.roomId;
    // Entries survive the stop so the finished transcript can be consumed.
    this.#transcript.stop();
    // Flushes the last utterances into the draft; the draft itself stays.
    const flushed = this.#transcriptDraft.stop();
    const currentUserId = this.#getCurrentUserId();
    if (currentUserId) {
      this.#subtitles.detach(roomId, currentUserId);
    }
    this.#syncSttEngine();
    this.#broadcastTranscribingState(roomId, false);
    return flushed;
  }

  // The consent signal: a roster flag every participant's client renders as
  // a quiet badge. Best effort — the transcript itself never leaves this
  // browser. Skipped when the room is already gone (leave teardown), since
  // the roster dies with the membership.
  #broadcastTranscribingState(roomId, transcribing) {
    if (!this.#isActiveRoom(roomId)) {
      return;
    }

    this.#setParticipantTranscribing(roomId, transcribing);
    ajax(`/voice/rooms/${roomId}/state`, {
      type: "POST",
      data: {
        transcribing,
        participant_session_id: this.#getParticipantSessionId(roomId),
      },
    }).catch(() => {});
  }

  // The speech-to-text pipeline serves two consumers: the caption overlay
  // (enabled) and the transcript recorder. It runs while either wants it,
  // tapping every remote stream plus — only while recording — the local mic,
  // so the transcript includes the current user.
  #syncSttEngine() {
    const enabled = this.enabled || this.recording;
    this.#subtitles.setEnabled(enabled, {
      modelBaseUrl: this.#modelBaseUrl,
    });

    if (!enabled) {
      this.captions = [];
      return;
    }

    for (const roomId of this.#getActiveRoomIds()) {
      for (const userId of this.#getRemoteUserIds(roomId)) {
        this.#subtitles.attach(
          roomId,
          userId,
          this.#getRemoteStream(roomId, userId)
        );
      }
    }
    this.syncLocalTap();
  }

  #draftData() {
    const entries = this.#transcript.entries;
    if (!entries.length) {
      return null;
    }

    const room = this.#getRoom(this.#transcript.entriesRoomId);
    return {
      reply: transcriptToMarkdown(entries, {
        chatMarkup: !!this.#siteSettings.chat_enabled,
      }),
      title: i18n("voice.transcript.draft_title", {
        room: room?.name ?? "",
      }),
      action: Composer.CREATE_TOPIC,
      archetypeId: "regular",
    };
  }

  // Hands the transcript over to the composer: recording stops, the last
  // utterances are flushed into the draft, and the draft opens for editing.
  // The server copy wins — the user may have edited it in another session.
  async openDraft() {
    const draftKey = this.#transcriptDraft.key;
    if (!draftKey) {
      return;
    }

    await this.#stopRecording();

    let draft = null;
    let draftSequence = this.#transcriptDraft.sequence;
    try {
      const result = await Draft.get(draftKey);
      draft = result.draft;
      draftSequence = result.draft_sequence ?? draftSequence;
    } catch {
      // fall through to the locally built copy
    }
    draft ||= this.#draftData();
    if (!draft) {
      return;
    }

    this.#openComposer({ draft, draftKey, draftSequence });
  }

  // Mirrors the local pipeline into the transcriber while recording. Safe to
  // call repeatedly: attach is a no-op for an unchanged track and rebuilds
  // the tap when a device switch or suppression change replaced it.
  syncLocalTap() {
    const currentUserId = this.#getCurrentUserId();
    if (!this.recording || !currentUserId) {
      return;
    }

    const roomId = this.roomId;
    const localStream = this.#getLocalStream();
    if (localStream) {
      this.#subtitles.attach(roomId, currentUserId, localStream);
    } else {
      this.#subtitles.detach(roomId, currentUserId);
    }
  }

  attachRemote(roomId, userId, stream) {
    this.#subtitles.attach(roomId, userId, stream);
  }

  detach(roomId, userId) {
    this.#subtitles.detach(roomId, userId);
  }

  detachRoom(roomId) {
    this.#subtitles.detachRoom(roomId);
    // Rejoining should start with a clean overlay, not replay whatever was
    // on screen (or still in the transcription queue) when we left.
    if (this.captions.length) {
      this.captions = this.captions.filter(
        (caption) => Number(caption.roomId) !== Number(roomId)
      );
    }
  }

  captionsFor(roomId) {
    return this.captions.filter(
      (caption) => Number(caption.roomId) === Number(roomId)
    );
  }

  // One caption line per utterance: interim passes update the line in place
  // while the speaker is still talking, the final pass replaces it, and a
  // null text withdraws it (VAD misfire, or a final that heard nothing).
  #upsertCaption(roomId, userId, { id: utteranceId, text, final }) {
    const existingIndex = this.captions.findIndex(
      (caption) =>
        caption.utteranceId === utteranceId &&
        Number(caption.userId) === Number(userId) &&
        Number(caption.roomId) === Number(roomId)
    );

    if (!text) {
      if (existingIndex !== -1) {
        this.captions = this.captions.filter(
          (_, index) => index !== existingIndex
        );
      }
      return;
    }

    if (existingIndex !== -1) {
      this.captions = this.captions.map((caption, index) =>
        index === existingIndex
          ? { ...caption, text, interim: !final, at: Date.now() }
          : caption
      );
      return;
    }

    // Captions carry a display-name snapshot so a line outlives its speaker
    // leaving the roster.
    this.captions = [
      ...this.captions.slice(-19),
      {
        id: ++this.#captionCounter,
        utteranceId,
        roomId,
        userId,
        username: this.#participantUsername(roomId, userId),
        text,
        interim: !final,
        at: Date.now(),
      },
    ];
  }

  #participantUsername(roomId, userId) {
    return (this.#getRoom(roomId)?.active_participants || []).find(
      (p) => Number(p?.id) === Number(userId)
    )?.username;
  }

  // Model or runtime failures turn the toggles back off (mirroring the noise
  // suppression contract) so the UI never shows an enabled-but-dead state.
  #handleError(error) {
    // eslint-disable-next-line no-console
    console.warn("[voice] subtitles failed", error);

    if (!this.enabled && !this.recording) {
      return;
    }

    this.enabled = false;
    this.#subtitles.setPreference(false);
    if (this.#transcript.recording) {
      this.#transcript.stop();
    }
    this.#subtitles.setEnabled(false);
    this.captions = [];
    this.#showError("voice.voice_settings.subtitles_failed");
  }
}
