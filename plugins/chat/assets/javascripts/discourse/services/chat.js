import { tracked } from "@glimmer/tracking";
import { action, computed } from "@ember/object";
import { and } from "@ember/object/computed";
import { cancel, next } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { bind } from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import discourseLater from "discourse/lib/later";
import {
  onPresenceChange,
  removeOnPresenceChange,
} from "discourse/lib/user-presence";

const CHAT_ONLINE_OPTIONS = {
  userUnseenTime: 300000, // 5 minutes seconds with no interaction
  browserHiddenTime: 300000, // Or the browser has been in the background for 5 minutes
};

export default class Chat extends Service {
  @service chatApi;
  @service appEvents;
  @service currentUser;
  @service chatSubscriptionsManager;
  @service chatStateManager;
  @service presence;
  @service router;
  @service chatChannelsManager;
  @service chatTrackingStateManager;
  @service chatPanePendingManager;

  cook = null;
  presenceChannel = null;
  isNetworkUnreliable = false;

  @and("currentUser.has_chat_enabled", "siteSettings.chat_enabled") userCanChat;

  @tracked _activeMessage = null;
  @tracked _activeChannel = null;

  init() {
    super.init(...arguments);

    if (this.userCanChat) {
      this.presenceChannel = this.presence.getChannel("/chat/online");

      onPresenceChange({
        callback: this.onPresenceChangeCallback,
        browserHiddenTime: 150000,
        userUnseenTime: 150000,
      });
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.userCanChat) {
      this.chatSubscriptionsManager.stopChannelsSubscriptions();
      removeOnPresenceChange(this.onPresenceChangeCallback);
    }
  }

  get activeChannel() {
    return this._activeChannel;
  }

  set activeChannel(channel) {
    if (!channel) {
      this._activeMessage = null;
    }

    if (this._activeChannel) {
      this._activeChannel.activeThread = null;
    }

    this._activeChannel = channel;
  }

  @computed("currentUser.staff", "currentUser.groups.[]")
  get userCanDirectMessage() {
    if (!this.currentUser) {
      return false;
    }

    return this.currentUser.staff || this.currentUser.can_direct_message;
  }

  @computed("chatChannelsManager.directMessageChannels")
  get userHasDirectMessages() {
    return this.chatChannelsManager.directMessageChannels?.length > 0;
  }

  get userCanAccessDirectMessages() {
    return this.userCanDirectMessage || this.userHasDirectMessages;
  }

  @computed("activeChannel.userSilenced")
  get userCanInteractWithChat() {
    return !this.activeChannel?.userSilenced;
  }

  get activeMessage() {
    return this._activeMessage;
  }

  set activeMessage(hash) {
    if (hash) {
      this._activeMessage = hash;
    } else {
      this._activeMessage = null;
    }
  }

  @bind
  onPresenceChangeCallback(present) {
    if (present) {
      // NOTE: channels is more than a simple array, it also contains
      // tracking and membership data, see Chat::StructuredChannelSerializer
      this.chatApi.listCurrentUserChannels().then((channelsView) => {
        this.chatSubscriptionsManager.stopChannelsSubscriptions();
        this.chatSubscriptionsManager.startChannelsSubscriptions(
          channelsView.meta.message_bus_last_ids
        );

        [
          ...channelsView.public_channels,
          ...channelsView.direct_message_channels,
        ].forEach((channelObject) => {
          this.chatChannelsManager
            .find(channelObject.id, { fetchIfNotFound: false })
            .then((channel) => {
              if (!channel) {
                return;
              }
              // NOTE: We need to do something here for thread tracking
              // state as well on presence change, otherwise we will be back in
              // the same place as the channels were.
              //
              // At some point it would likely be better to just fetch an
              // endpoint that gives you all channel tracking state and the
              // thread tracking state for the current channel.

              // ensures we have the latest message bus ids
              channel.meta.message_bus_last_ids =
                channelObject.meta.message_bus_last_ids;

              const state = channelsView.tracking.channel_tracking[channel.id];
              channel.tracking.unreadCount = state.unread_count;
              channel.tracking.mentionCount = state.mention_count;
              channel.tracking.watchedThreadsUnreadCount =
                state.watched_threads_unread_count;

              channel.currentUserMembership =
                channelObject.current_user_membership;

              this.chatSubscriptionsManager.startChannelSubscription(channel);
            });
        });
      });
    }
  }

  markNetworkAsUnreliable() {
    cancel(this._networkCheckHandler);

    this.set("isNetworkUnreliable", true);

    this._networkCheckHandler = discourseLater(() => {
      if (this.isDestroyed || this.isDestroying) {
        return;
      }

      this.markNetworkAsReliable();
    }, 30000);
  }

  markNetworkAsReliable() {
    cancel(this._networkCheckHandler);

    this.set("isNetworkUnreliable", false);
  }

  async loadChannels() {
    // We want to be able to call this method multiple times, but only
    // actually load the channels once. This is because we might call
    // this method before the chat is fully initialized, and we don't
    // want to load the channels multiple times in that case.
    try {
      if (this.chatStateManager.hasPreloadedChannels) {
        return;
      }

      if (!this.loadingChannels) {
        this.loadingChannels = new Promise((resolve) => {
          this.chatApi.listCurrentUserChannels().then((result) => {
            this.setupWithPreloadedChannels(result);
            this.chatStateManager.hasPreloadedChannels = true;
            resolve();
          });
        });
      }

      return this.loadingChannels;
    } catch (e) {
      popupAjaxError(e);
    }
  }

  setupWithPreloadedChannels(channelsView) {
    this.chatSubscriptionsManager.startChannelsSubscriptions(
      channelsView.meta.message_bus_last_ids
    );
    this.presenceChannel.subscribe(channelsView.global_presence_channel_state);

    this.chatChannelsManager.hasThreads = channelsView.has_threads ?? false;

    [
      ...channelsView.public_channels,
      ...channelsView.direct_message_channels,
    ].forEach((channelObject) => {
      const storedChannel = this.chatChannelsManager.store(channelObject);

      if (channelsView.unread_thread_overview?.[storedChannel.id]) {
        storedChannel.threadsManager.unreadThreadOverview =
          channelsView.unread_thread_overview[storedChannel.id];
      }

      return this.chatChannelsManager.follow(storedChannel);
    });

    this.chatTrackingStateManager.setupWithPreloadedState(
      channelsView.tracking
    );
  }

  updatePresence() {
    next(() => {
      if (this.isDestroyed || this.isDestroying) {
        return;
      }

      if (this.currentUser.user_option?.hide_presence) {
        return;
      }

      if (this.chatStateManager.isActive) {
        this.presenceChannel.enter({ activeOptions: CHAT_ONLINE_OPTIONS });
      } else {
        this.presenceChannel.leave();
      }
    });
  }

  getDocumentTitleCount() {
    if (this.currentUser?.user_option?.title_count_mode === "notifications") {
      return this.chatTrackingStateManager.allChannelUrgentCount;
    } else {
      return this.chatPanePendingManager.totalPendingMessageCount;
    }
  }

  switchChannelUpOrDown(direction, unreadOnly = false) {
    const { activeChannel } = this;
    if (!activeChannel) {
      return; // Chat isn't open. Return and do nothing!
    }

    // Build unified channel list matching sidebar order
    const allChannels = unreadOnly
      ? this.#getOrderedChannelsWithActivity(activeChannel)
      : this.#getOrderedChannels();

    if (allChannels.length === 0) {
      return;
    }

    const directionUp = direction === "up";
    const currentIndex = allChannels.findIndex(
      (c) => c.id === activeChannel.id
    );

    let nextIndex;
    if (currentIndex === -1) {
      // Active channel not in list, go to start/end
      nextIndex = directionUp ? allChannels.length - 1 : 0;
    } else {
      nextIndex = currentIndex + (directionUp ? -1 : 1);
      // Wrap around
      if (nextIndex < 0) {
        nextIndex = allChannels.length - 1;
      } else if (nextIndex >= allChannels.length) {
        nextIndex = 0;
      }
    }

    const nextChannel = allChannels[nextIndex];
    if (nextChannel && nextChannel.id !== activeChannel.id) {
      return this.router.transitionTo(
        "chat.channel",
        ...nextChannel.routeModels
      );
    }
  }

  /**
   * Returns channels in sidebar display order: starred, public, DMs.
   *
   * @returns {Array} Ordered array of chat channels matching sidebar order
   */
  #getOrderedChannels() {
    const manager = this.chatChannelsManager;

    return [
      ...manager.starredChannels,
      ...manager.unstarredPublicMessageChannels,
      ...manager.truncatedUnstarredDirectMessageChannels,
    ];
  }

  /**
   * Returns channels with unread activity in sidebar display order.
   * If the active channel has no unreads, inserts it at its proper position
   * relative to other channels with activity.
   *
   * @param {ChatChannel} activeChannel - The currently active channel
   * @returns {Array} Ordered array of channels with activity
   */
  #getOrderedChannelsWithActivity(activeChannel) {
    const manager = this.chatChannelsManager;

    // Filter each section for channels with activity
    const starredWithActivity = manager.starredChannels.filter(
      (c) => c.hasUnread
    );
    const publicWithActivity = manager.unstarredPublicMessageChannels.filter(
      (c) => c.hasUnread
    );
    const dmsWithActivity =
      manager.truncatedUnstarredDirectMessageChannels.filter(
        (c) => c.hasUnread
      );

    const allChannels = [
      ...starredWithActivity,
      ...publicWithActivity,
      ...dmsWithActivity,
    ];

    // If the active channel has no unread messages, insert it at its proper position
    if (!activeChannel.hasUnread) {
      const orderedChannels = this.#getOrderedChannels();
      const activeIndexInOrdered = orderedChannels.findIndex(
        (c) => c.id === activeChannel.id
      );

      if (activeIndexInOrdered !== -1) {
        // Find the last unread channel before the active channel's position
        let insertAfterIndex = -1;
        for (let i = activeIndexInOrdered - 1; i >= 0; i--) {
          const channelAtPos = orderedChannels[i];
          const indexInActivity = allChannels.findIndex(
            (c) => c.id === channelAtPos.id
          );
          if (indexInActivity !== -1) {
            insertAfterIndex = indexInActivity;
            break;
          }
        }

        // Insert the active channel after the found unread channel (or at start)
        allChannels.splice(insertAfterIndex + 1, 0, activeChannel);
      }
    }

    return allChannels;
  }

  _fireOpenFloatAppEvent(channel, messageId = null) {
    messageId
      ? this.router.transitionTo(
          "chat.channel.near-message",
          ...channel.routeModels,
          messageId
        )
      : this.router.transitionTo("chat.channel", ...channel.routeModels);
  }

  async followChannel(channel) {
    return this.chatChannelsManager.follow(channel);
  }

  async unfollowChannel(channel) {
    return this.chatChannelsManager.unfollow(channel).then(() => {
      if (channel === this.activeChannel && channel.isDirectMessageChannel) {
        this.router.transitionTo("chat");
      }
    });
  }

  upsertDmChannelForUser(channel, user) {
    const usernames = uniqueItemsFromArray(
      (channel.chatable.users || [])
        .map((item) => item.username)
        .concat(user.username)
    );

    return this.upsertDmChannel({ usernames });
  }

  // @param {object} targets - The targets to create or fetch the direct message
  // channel for. The current user will automatically be included in the channel when it is created.
  // @param {array} [targets.usernames] - The usernames to include in the direct message channel.
  // @param {array} [targets.groups] - The groups to include in the direct message channel.
  // @param {object} opts - Optional values when fetching or creating the direct message channel.
  // @param {string|null} [opts.name] - Name for the direct message channel.
  // @param {boolean} [opts.upsert] - Should we attempt to fetch existing channel before creating a new one.
  createDmChannel(targets, opts = { name: null, upsert: false }) {
    return ajax("/chat/api/direct-message-channels.json", {
      method: "POST",
      data: {
        target_usernames: targets.usernames
          ? uniqueItemsFromArray(targets.usernames)
          : null,
        target_groups: targets.groups
          ? uniqueItemsFromArray(targets.groups)
          : null,
        upsert: opts.upsert,
        name: opts.name,
      },
    })
      .then((response) => {
        const channel = this.chatChannelsManager.store(response.channel);
        this.chatChannelsManager.follow(channel);
        return channel;
      })
      .catch(popupAjaxError);
  }

  upsertDmChannel(targets, name = null) {
    return this.createDmChannel(targets, { name, upsert: true });
  }

  // @param {array} usernames - The usernames to fetch the direct message
  // channel for. The current user will automatically be included as a
  // participant to fetch the channel for.
  getDmChannelForUsernames(usernames) {
    return ajax("/chat/direct_messages.json", {
      data: { usernames: uniqueItemsFromArray(usernames).join(",") },
    });
  }

  addToolbarButton() {
    deprecated(
      "Use the new chat API `api.registerChatComposerButton` instead of `chat.addToolbarButton`",
      { id: "discourse.chat.addToolbarButton" }
    );
  }

  @action
  toggleDrawer() {
    this.chatStateManager.didToggleDrawer();
    this.appEvents.trigger(
      "chat:toggle-expand",
      this.chatStateManager.isDrawerExpanded
    );
  }
}
