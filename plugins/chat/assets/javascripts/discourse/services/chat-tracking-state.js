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
    this.unreadCount = params.unreadCount;
    this.mentionCount = params.mentionCount;
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
    const publicChannelIds =
      this.chatChannelsManager.publicMessageChannels.mapBy("id");
    return publicChannelIds.reduce((unreadCount, channelId) => {
      return unreadCount + this.getChannelState(channelId).unreadCount;
    }, 0);
  }

  get allChannelUrgentCount() {
    const publicChannelIds =
      this.chatChannelsManager.publicMessageChannels.mapBy("id");
    const directMessageChannelIds =
      this.chatChannelsManager.directMessageChannels.mapBy("id");

    let publicChannelMentionCount = publicChannelIds.reduce(
      (unreadCount, channelId) => {
        return unreadCount + this.getChannelState(channelId).mentionCount;
      },
      0
    );

    let dmChannelUnreadCount = directMessageChannelIds.reduce(
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

  getChannelState(channelId) {
    return this._channels[channelId];
  }

  setThreadState(threadId, state) {
    this.#setState(threadId, "_threads", state);
  }

  getThreadState(threadId) {
    return this._threads[threadId];
  }

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
}
