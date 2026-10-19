const SAVE_INTERVAL_MS = 10_000;

// new_topic-prefixed so core's drafts list and resume flow treat these as
// normal new-topic drafts; the rest marks them as ours (see the draft-icon
// transformer registration).
export const TRANSCRIPT_DRAFT_KEY_PREFIX = "new_topic_voice_";

// Mirrors an in-progress transcript into a server-side topic draft so the
// recording survives a crashed tab and shows up in the user's drafts like
// any half-written topic. Saves ride a fixed cadence and only when entries
// changed.
//
// The sync only ever runs while recording — opening the draft stops the
// recording first, so the composer never competes with it. A sequence
// conflict therefore means another client wrote the draft; that copy wins
// and this sync goes quiet for good.
export default class TranscriptDraftSync {
  #save;
  #buildData;
  #timer = null;
  #saving = false;
  #dirty = false;
  #sequence = 0;
  #conflicted = false;
  #key = null;

  constructor({ save, buildData }) {
    this.#save = save;
    this.#buildData = buildData;
  }

  get key() {
    return this.#key;
  }

  get sequence() {
    return this.#sequence;
  }

  start(roomId, startedAt) {
    this.dispose();
    this.#key = `${TRANSCRIPT_DRAFT_KEY_PREFIX}${roomId}_${startedAt}`;
    this.#sequence = 0;
    this.#dirty = false;
    this.#conflicted = false;
    this.#timer = setInterval(() => this.flush(), SAVE_INTERVAL_MS);
  }

  markDirty() {
    this.#dirty = true;
  }

  // Stops the cadence and flushes what's pending. The key survives so the
  // finished draft can still be opened.
  async stop() {
    clearInterval(this.#timer);
    this.#timer = null;
    await this.flush();
  }

  dispose() {
    clearInterval(this.#timer);
    this.#timer = null;
    this.#key = null;
  }

  async flush() {
    if (!this.#key || this.#conflicted || this.#saving || !this.#dirty) {
      return;
    }

    const data = this.#buildData();
    if (!data) {
      return;
    }

    this.#saving = true;
    this.#dirty = false;
    try {
      const result = await this.#save(this.#key, this.#sequence, data);
      this.#sequence = result?.draft_sequence ?? this.#sequence;
    } catch (error) {
      if (error?.jqXHR?.status === 409) {
        this.#conflicted = true;
      } else {
        // Transient failure (network, logout race): retry next tick.
        this.#dirty = true;
      }
    } finally {
      this.#saving = false;
    }
  }
}
