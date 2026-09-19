// Accumulates a meeting transcript from the subtitles pipeline: one entry per
// final utterance, with the speaker and the utterance's start wall-clock.
//
// Recording is scoped to a single room. Interim captions never land here —
// only finals do — and a null-text final withdraws the entry (a VAD misfire,
// or the model hearing nothing intelligible). Entries survive stop() so the
// finished transcript can be consumed; they are discarded when a new
// recording starts.
export default class TranscriptRecorder {
  #entries = [];
  #onChange;
  #roomId = null;
  // Which room the kept entries belong to; unlike #roomId it survives stop()
  // so a consumer can still attribute the finished transcript.
  #entriesRoomId = null;
  #startedAt = null;

  constructor({ onChange }) {
    this.#onChange = onChange;
  }

  get recording() {
    return this.#roomId !== null;
  }

  get roomId() {
    return this.#roomId;
  }

  get entriesRoomId() {
    return this.#entriesRoomId;
  }

  get startedAt() {
    return this.#startedAt;
  }

  get entries() {
    return this.#entries;
  }

  start(roomId) {
    this.#roomId = roomId;
    this.#entriesRoomId = roomId;
    this.#startedAt = Date.now();
    this.#entries = [];
    this.#onChange();
  }

  stop() {
    this.#roomId = null;
    this.#onChange();
  }

  record(
    roomId,
    userId,
    username,
    { id: utteranceId, text, final, startedAt }
  ) {
    if (!final || !this.recording || Number(roomId) !== Number(this.#roomId)) {
      return;
    }

    const index = this.#entries.findIndex(
      (entry) => entry.utteranceId === utteranceId
    );

    if (!text) {
      if (index !== -1) {
        this.#entries = this.#entries.filter((_, i) => i !== index);
        this.#onChange();
      }
      return;
    }

    if (index !== -1) {
      this.#entries = this.#entries.map((entry, i) =>
        i === index ? { ...entry, text } : entry
      );
      this.#onChange();
      return;
    }

    const entry = {
      utteranceId,
      userId,
      username,
      text,
      startedAt: startedAt ?? Date.now(),
    };

    // Insert in utterance-start order: worker jobs serialize across speakers,
    // so with overlapping speech results can arrive out of speaking order.
    const insertAt = this.#entries.findLastIndex(
      (existing) => existing.startedAt <= entry.startedAt
    );
    this.#entries = [
      ...this.#entries.slice(0, insertAt + 1),
      entry,
      ...this.#entries.slice(insertAt + 1),
    ];
    this.#onChange();
  }
}
