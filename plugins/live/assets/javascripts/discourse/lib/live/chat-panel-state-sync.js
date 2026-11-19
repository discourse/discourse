import { tracked } from "@glimmer/tracking";
import { trackedObject } from "@ember/reactive/collections";
import { next } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

// A newer session can come back while we're still loading the old thread,
// so we track session requests and thread loads separately.
export default class LiveChatPanelStateSync {
  @tracked threadLoadError = false;

  pane = trackedObject({ sending: false });

  #channelManager;
  #disposed = false;
  #messageBus;
  #onChannel;
  #onThread;
  #queuedState;
  #requestVersion = 0;
  #roomPath;
  #stateVersion = 0;
  #threadId;
  #uploadCount = 0;

  #refresh = async () => {
    try {
      await this.#loadSession();
    } catch {
      // The next session signal or reopening the panel retries the refresh.
    }
  };

  constructor({ roomId, channelManager, messageBus, onChannel, onThread }) {
    this.#roomPath = `/live/rooms/${roomId}`;
    this.#channelManager = channelManager;
    this.#messageBus = messageBus;
    this.#onChannel = onChannel;
    this.#onThread = onThread;
  }

  start() {
    this.#messageBus.subscribe(`${this.#roomPath}/chat`, this.#refresh);
    return this.#ensureSession();
  }

  dispose() {
    this.#disposed = true;
    this.#queuedState = null;
    this.#messageBus.unsubscribe(`${this.#roomPath}/chat`, this.#refresh);
  }

  updateUploadCount(count) {
    this.#uploadCount = count;
    if (!count && this.#queuedState) {
      next(this, this.retryLoadingThread);
    }
  }

  async sendFirstMessage(message, onAccepted) {
    if (
      this.#disposed ||
      this.pane.sending ||
      this.threadLoadError ||
      this.#uploadCount
    ) {
      return;
    }

    this.pane.sending = true;
    this.#requestVersion++;
    try {
      const data = await ajax(`${this.#roomPath}/chat_message`, {
        type: "POST",
        data: {
          message: message.message,
          upload_ids: message.uploads.map((upload) => upload.id),
        },
      });
      this.#requestVersion++;
      this.#stateVersion++;
      if (!this.#disposed) {
        this.#queuedState = data;
      }
      onAccepted();
    } finally {
      this.pane.sending = false;
      await this.retryLoadingThread();
    }
  }

  async retryLoadingThread() {
    if (
      this.#disposed ||
      !this.#queuedState ||
      this.pane.sending ||
      this.#uploadCount
    ) {
      return;
    }
    try {
      await this.#applyState(this.#queuedState);
    } catch (error) {
      this.threadLoadError = true;
      popupAjaxError(error);
    }
  }

  #ensureSession() {
    return this.#applyLatestSessionRequest(() =>
      ajax(`${this.#roomPath}/chat_session`, { type: "POST" })
    );
  }

  #loadSession() {
    return this.#applyLatestSessionRequest(() =>
      ajax(`${this.#roomPath}/chat_session`)
    );
  }

  async #applyLatestSessionRequest(request) {
    const version = ++this.#requestVersion;
    let data;
    try {
      data = await request();
    } catch (error) {
      if (!this.#disposed && version === this.#requestVersion) {
        throw error;
      }
    }
    if (!this.#disposed && version === this.#requestVersion) {
      await this.#applyState(data);
    }
  }

  async #applyState(data) {
    if (!data?.channel_id) {
      return;
    }

    this.#queuedState = data;
    const version = ++this.#stateVersion;
    try {
      const channel = await this.#channelManager.find(data.channel_id);
      if (!channel.isFollowing && this.#isCurrent(version)) {
        await this.#channelManager.follow(channel);
      }
      if (!this.#isCurrent(version)) {
        return;
      }

      this.#onChannel(channel);
      if (!data.thread_id || this.#threadId === data.thread_id) {
        this.#queuedState = null;
        return;
      }
      if (this.pane.sending || this.#uploadCount) {
        return;
      }

      const thread = await channel.threadsManager.find(
        channel.id,
        data.thread_id
      );
      if (!this.#isCurrent(version) || this.pane.sending || this.#uploadCount) {
        return;
      }

      this.#onThread(channel, thread);
      this.#threadId = thread.id;
      this.threadLoadError = false;
      this.#queuedState = null;
    } catch (error) {
      if (this.#isCurrent(version)) {
        throw error;
      }
    }
  }

  #isCurrent(version) {
    return !this.#disposed && version === this.#stateVersion;
  }
}
