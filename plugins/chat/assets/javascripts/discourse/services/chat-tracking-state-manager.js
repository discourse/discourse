import Service, { inject as service } from "@ember/service";
import { getOwner } from "discourse-common/lib/get-owner";
import { setOwner } from "@ember/application";
import { tracked } from "@glimmer/tracking";

export class ChatTrackingState {
  @service chatTrackingStateManager;

  @tracked _unreadCount = 0;
  @tracked _mentionCount = 0;

  constructor(owner, params = {}) {
    setOwner(this, owner);
    this._unreadCount = params.hasOwnProperty("unreadCount")
      ? params.unreadCount
      : 0;
    this._mentionCount = params.hasOwnProperty("mentionCount")
      ? params.mentionCount
      : 0;
  }

  reset() {
    this._unreadCount = 0;
    this._mentionCount = 0;
  }

  get unreadCount() {
    return this._unreadCount;
  }

  set unreadCount(value) {
    this._unreadCount = value;
  }

  get mentionCount() {
    return this._mentionCount;
  }

  set mentionCount(value) {
    const valueChanged = this._mentionCount !== value;
    this._mentionCount = value;
    if (valueChanged) {
      this.chatTrackingStateManager.triggerNotificationsChanged();
    }
  }
}

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
  // to avoid having to load all the threads across all channels into memory at once.
  setupWithPreloadedState({ channel_tracking = {} }) {
    this.#publicChannels().forEach((channel) => {
      if (channel_tracking[channel.id.toString()]) {
        this.#setState(channel, channel_tracking[channel.id.toString()]);
      }
    });

    this.#directMessageChannels().forEach((channel) => {
      if (channel_tracking[channel.id.toString()]) {
        this.#setState(channel, channel_tracking[channel.id.toString()]);
      }
    });
  }

  get publicChannelUnreadCount() {
    return this.#publicChannels().reduce((unreadCount, channel) => {
      return unreadCount + channel.tracking.unreadCount;
    }, 0);
  }

  get allChannelUrgentCount() {
    let publicChannelMentionCount = this.#publicChannels().reduce(
      (mentionCount, channel) => {
        return mentionCount + channel.tracking.mentionCount;
      },
      0
    );

    let dmChannelUnreadCount = this.#directMessageChannels().reduce(
      (unreadCount, channel) => {
        return unreadCount + channel.tracking.unreadCount;
      },
      0
    );

    return publicChannelMentionCount + dmChannelUnreadCount;
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

  #setState(model, state) {
    if (!model.tracking) {
      model.tracking = new ChatTrackingState(getOwner(this), {
        unreadCount: state.unread_count,
        mentionCount: state.mention_count,
      });
      return;
    }
    model.tracking.unreadCount = state.unread_count;
    model.tracking.mentionCount = state.mention_count;
  }

  #publicChannels() {
    return this.chatChannelsManager.publicMessageChannels;
  }

  #directMessageChannels() {
    return this.chatChannelsManager.directMessageChannels;
  }
}
