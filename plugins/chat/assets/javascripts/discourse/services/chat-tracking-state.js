import Service, { inject as service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { tracked } from "@glimmer/tracking";

/**
 * This service is used to track the state of channels and threads.
 * It is used to determine if a channel or thread is unread, and if so,
 * how many unread messages and mentions there are, based on the unread_count
 * and mention_count.
 */

class TrackingState {
  @tracked unreadCount = 0;
  @tracked mentionCount = 0;

  constructor(params) {
    this.unreadCount = params.unreadCount || 0;
    this.mentionCount = params.mentionCount || 0;
  }
}

export default class ChatTrackingState extends Service {
  @service chatChannelsManager;
  @service appEvents;

  @tracked _channels = new TrackedObject();
  @tracked _threads = new TrackedObject();

  // channel_tracking: {
  //   1: { unreadCount: 1, mentionCount: 2 },
  //   2: { unreadCount: 1, mentionCount: 2 }
  // }
  // thread_tracking: {
  //   1: { unreadCount: 1, mentionCount: 2 },
  //   2: { unreadCount: 1, mentionCount: 2 }
  // }

  setupWithPreloadedState({ channel_tracking, thread_tracking }) {
    for (const [channelId, state] of Object.entries(channel_tracking)) {
      this.setChannelState(channelId, state);
    }
    for (const [threadId, state] of Object.entries(thread_tracking)) {
      this.setThreadState(threadId, state);
    }
  }

  get publicChannelUnreadCount() {
    return this.#publicChannelIds().reduce((unreadCount, channelId) => {
      return unreadCount + this.getChannelState(channelId).unreadCount;
    }, 0);
  }

  get allChannelUrgentCount() {
    let publicChannelMentionCount = this.#publicChannelIds().reduce(
      (unreadCount, channelId) => {
        return unreadCount + this.getChannelState(channelId).mentionCount;
      },
      0
    );

    let dmChannelUnreadCount = this.#directMessageChannelIds().reduce(
      (unreadCount, channelId) => {
        return unreadCount + this.getChannelState(channelId).unreadCount;
      },
      0
    );

    return publicChannelMentionCount + dmChannelUnreadCount;
  }

  incrementChannelUnread(channelId) {
    this.setChannelState(channelId, {
      unreadCount: this.getChannelState(channelId).unreadCount + 1,
    });
  }

  incrementChannelMention(channelId) {
    this.setChannelState(channelId, {
      mentionCount: this.getChannelState(channelId).mentionCount + 1,
    });
    this.triggerNotificationsChanged();
  }

  setChannelState(channelId, state) {
    this.#setState(channelId, "_channels", state);
  }

  /**
   * We want to return a default zeroed-out tracking state
   * for channels which we are not yet tracking, e.g. in
   * some scenarios we may be getting the state for a newly
   * joined channel and we don't want to have to null check
   * everywhere in the app.
   */
  getChannelState(channelId) {
    return (
      this._channels[channelId] ||
      new TrackingState({ unreadCount: 0, mentionCount: 0 })
    );
  }

  setThreadState(threadId, state) {
    this.#setState(threadId, "_threads", state);
  }

  /**
   * See getChannelState docs.
   */
  getThreadState(threadId) {
    return (
      this._threads[threadId] ||
      new TrackingState({ unreadCount: 0, mentionCount: 0 })
    );
  }

  /**
   * Some reactivity in the app such as the document title
   * updates are only done via appEvents -- rather than
   * sprinkle this appEvent call everywhere we just define
   * it here so it can be changed as required.
   */
  triggerNotificationsChanged() {
    this.appEvents.trigger("notifications:changed");
  }

  #setState(id, key, state) {
    state = this.#conformState(state);
    if (!this[key][id]) {
      this[key][id] = new TrackingState(state);
      return;
    }
    if (state.hasOwnProperty("unreadCount")) {
      this[key][id].unreadCount = state.unreadCount;
    }
    if (state.hasOwnProperty("mentionCount")) {
      this[key][id].mentionCount = state.mentionCount;
    }
  }

  #conformState(state) {
    const newState = {
      unreadCount: state.unreadCount || state.unread_count,
      mentionCount: state.mentionCount || state.mention_count,
    };

    if (newState.unreadCount === undefined) {
      delete newState.unreadCount;
    }

    if (newState.mentionCount === undefined) {
      delete newState.mentionCount;
    }

    return newState;
  }

  #publicChannelIds() {
    return this.chatChannelsManager.publicMessageChannels.mapBy("id");
  }

  #directMessageChannelIds() {
    return this.chatChannelsManager.directMessageChannels.mapBy("id");
  }
}
