import { getOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import Service, { service } from "@ember/service";
import discourseDebounce from "discourse/lib/debounce";
import ChatTrackingState from "discourse/plugins/chat/discourse/models/chat-tracking-state";

/**
 * This service is used to provide a global interface to tracking individual
 * channels and threads. In many places in the app, we need to know the global
 * unread count for channels, threads, etc.
 *
 * The individual tracking state of each channel and thread is stored in
 * a ChatTrackingState class instance and changed via the getters/setters
 * provided there.
 *
 * This service is also used to preload bulk tracking state for channels
 * and threads, which is used when the user first loads the app, and in
 * certain cases where we need to set the state for many items at once.
 */
export default class ChatTrackingStateManager extends Service {
  @service chatChannelsManager;
  @service appEvents;

  // NOTE: In future, we may want to preload some thread tracking state
  // as well, but for now we do that on demand when the user opens a channel,
  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this._onTriggerNotificationDebounceHandler);
  }

  // to avoid having to load all the threads across all channels into memory at once.
  setupWithPreloadedState({ channel_tracking = {} }) {
    this.chatChannelsManager.channels.forEach((channel) => {
      if (channel_tracking[channel.id.toString()]) {
        this.#setState(channel, channel_tracking[channel.id.toString()]);
      }
    });
  }

  setupChannelThreadState(channel, threadTracking) {
    channel.threadsManager.threads.forEach((thread) => {
      const tracking = threadTracking[thread.id.toString()];
      if (tracking) {
        this.#setState(thread, tracking);
      }
    });
  }

  allChannelMentionCount({ exclude } = {}) {
    return this.#allChannels.reduce((count, channel) => {
      if (channel.id === exclude?.id) {
        return count;
      }
      return count + channel.tracking.mentionCount;
    }, 0);
  }

  allChannelUrgentCount({ exclude } = {}) {
    let count = 0;
    for (const channel of this.#allChannels) {
      if (channel.id === exclude?.id) {
        continue;
      }
      count += channel.tracking.mentionCount;
      count += channel.tracking.watchedThreadsUnreadCount;
      if (channel.isDirectMessageChannel) {
        count += channel.tracking.unreadCount;
      }
    }
    return count;
  }

  hasUnreadThreads({ exclude } = {}) {
    return this.#allChannels.some(
      (channel) => channel.id !== exclude?.id && channel.unreadThreadsCount > 0
    );
  }

  publicChannelUnreadCount({ exclude } = {}) {
    return this.#publicChannels.reduce((count, channel) => {
      if (channel.id === exclude?.id) {
        return count;
      }
      return count + channel.tracking.unreadCount;
    }, 0);
  }

  get watchedThreadsUnreadCount() {
    return this.#allChannels.reduce((unreadCount, channel) => {
      return unreadCount + channel.tracking.watchedThreadsUnreadCount;
    }, 0);
  }

  /**
   * Some reactivity in the app such as the document title
   * updates are only done via appEvents -- rather than
   * sprinkle this appEvent call everywhere we just define
   * it here so it can be changed as required.
   */
  triggerNotificationsChanged() {
    this._onTriggerNotificationDebounceHandler = discourseDebounce(
      this,
      this.#triggerNotificationsChanged,
      100
    );
  }

  #triggerNotificationsChanged() {
    this.appEvents.trigger("notifications:changed");
  }

  #setState(model, state) {
    if (!model.tracking) {
      model.tracking = new ChatTrackingState(getOwner(this));
    }
    model.tracking.unreadCount = state.unread_count;
    model.tracking.mentionCount = state.mention_count;
    model.tracking.watchedThreadsUnreadCount =
      state.watched_threads_unread_count;
  }

  get #publicChannels() {
    return this.chatChannelsManager.publicMessageChannels;
  }

  get #allChannels() {
    return this.chatChannelsManager.allChannels;
  }
}
