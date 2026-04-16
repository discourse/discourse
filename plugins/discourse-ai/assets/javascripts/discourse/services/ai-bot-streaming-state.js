import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

// The message bus replays the last two events on subscribe. The idle
// timer only arms once we've received a real streaming chunk (with a
// postId); between chunks we expect a new update within ~40ms, so a
// generous ceiling of 15s can't race a live stream.
const IDLE_TIMEOUT_MS = 15000;

export default class AiBotStreamingState extends Service {
  @tracked streamingByTopic = new Map();
  #idleTimers = new Map();

  willDestroy() {
    super.willDestroy(...arguments);
    for (const timer of this.#idleTimers.values()) {
      clearTimeout(timer);
    }
    this.#idleTimers.clear();
  }

  isStreamingForTopic(topicId) {
    if (!topicId) {
      return false;
    }
    return this.streamingByTopic.has(topicId);
  }

  streamingPostIdForTopic(topicId) {
    return this.streamingByTopic.get(topicId)?.postId ?? null;
  }

  markStarted(topicId, postId) {
    if (!topicId) {
      return;
    }
    const next = new Map(this.streamingByTopic);
    next.set(topicId, { postId, startedAt: Date.now() });
    this.streamingByTopic = next;

    // Only arm the idle timer once we have a concrete postId — i.e. a
    // real streaming chunk has arrived from the message bus. The
    // optimistic mark from the submit service (postId = null) must not
    // arm the timer, otherwise slow model start-up would flip the UI
    // back to the send button before the stream begins.
    if (postId) {
      this.#resetIdleTimer(topicId);
    }
  }

  markFinished(topicId) {
    this.#clearIdleTimer(topicId);

    if (!topicId || !this.streamingByTopic.has(topicId)) {
      return;
    }
    const next = new Map(this.streamingByTopic);
    next.delete(topicId);
    this.streamingByTopic = next;
  }

  async stopStreaming(topicId) {
    const postId = this.streamingPostIdForTopic(topicId);
    if (!postId) {
      this.markFinished(topicId);
      return;
    }
    try {
      await ajax(`/discourse-ai/ai-bot/post/${postId}/stop-streaming`, {
        type: "POST",
      });
      document
        .querySelector(`[data-post-id="${postId}"]`)
        ?.classList.remove("streaming");
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.markFinished(topicId);
    }
  }

  #resetIdleTimer(topicId) {
    this.#clearIdleTimer(topicId);
    const timer = setTimeout(() => {
      this.markFinished(topicId);
    }, IDLE_TIMEOUT_MS);
    this.#idleTimers.set(topicId, timer);
  }

  #clearIdleTimer(topicId) {
    const timer = this.#idleTimers.get(topicId);
    if (timer) {
      clearTimeout(timer);
      this.#idleTimers.delete(topicId);
    }
  }
}
