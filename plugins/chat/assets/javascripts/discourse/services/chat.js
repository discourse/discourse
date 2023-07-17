import deprecated from "discourse-common/lib/deprecated";
import { tracked } from "@glimmer/tracking";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Service, { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { cancel, next } from "@ember/runloop";
import { and } from "@ember/object/computed";
import { computed } from "@ember/object";
import discourseLater from "discourse-common/lib/later";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import {
  onPresenceChange,
  removeOnPresenceChange,
} from "discourse/lib/user-presence";
import { bind } from "discourse-common/utils/decorators";

const CHAT_ONLINE_OPTIONS = {
  userUnseenTime: 300000, // 5 minutes seconds with no interaction
  browserHiddenTime: 300000, // Or the browser has been in the background for 5 minutes
};

export default class Chat extends Service {
  @service chatApi;
  @service appEvents;
  @service currentUser;
  @service chatNotificationManager;
  @service chatSubscriptionsManager;
  @service chatStateManager;
  @service chatDraftsManager;
  @service presence;
  @service router;
  @service site;
  @service chatChannelsManager;
  @service chatTrackingStateManager;

  cook = null;
  presenceChannel = null;
  sidebarActive = false;
  isNetworkUnreliable = false;

  @and("currentUser.has_chat_enabled", "siteSettings.chat_enabled") userCanChat;

  @tracked _activeMessage = null;
  @tracked _activeChannel = null;

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

    return (
      this.currentUser.staff ||
      this.currentUser.isInAnyGroups(
        (this.siteSettings.direct_message_enabled_groups || "11") // trust level 1 auto group
          .split("|")
          .map((groupId) => parseInt(groupId, 10))
      )
    );
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
              // TODO (martin) We need to do something here for thread tracking
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

  setupWithPreloadedChannels(channelsView) {
    this.chatSubscriptionsManager.startChannelsSubscriptions(
      channelsView.meta.message_bus_last_ids
    );
    this.presenceChannel.subscribe(channelsView.global_presence_channel_state);

    [
      ...channelsView.public_channels,
      ...channelsView.direct_message_channels,
    ].forEach((channelObject) => {
      const storedChannel = this.chatChannelsManager.store(channelObject);
      const storedDraft = (this.currentUser?.chat_drafts || []).find(
        (draft) => draft.channel_id === storedChannel.id
      );

      if (storedDraft) {
        this.chatDraftsManager.add(
          ChatMessage.createDraftMessage(
            storedChannel,
            Object.assign(
              { user: this.currentUser },
              JSON.parse(storedDraft.data)
            )
          )
        );
      }

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

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.userCanChat) {
      this.chatSubscriptionsManager.stopChannelsSubscriptions();
      removeOnPresenceChange(this.onPresenceChangeCallback);
    }
  }

  updatePresence() {
    next(() => {
      if (this.isDestroyed || this.isDestroying) {
        return;
      }

      if (this.currentUser.user_option?.hide_profile_and_presence) {
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
    return this.chatNotificationManager.shouldCountChatInDocTitle()
      ? this.chatTrackingStateManager.allChannelUrgentCount
      : 0;
  }

  switchChannelUpOrDown(direction) {
    const { activeChannel } = this;
    if (!activeChannel) {
      return; // Chat isn't open. Return and do nothing!
    }

    let currentList, otherList;
    if (activeChannel.isDirectMessageChannel) {
      currentList = this.chatChannelsManager.truncatedDirectMessageChannels;
      otherList = this.chatChannelsManager.publicMessageChannels;
    } else {
      currentList = this.chatChannelsManager.publicMessageChannels;
      otherList = this.chatChannelsManager.truncatedDirectMessageChannels;
    }

    const directionUp = direction === "up";
    const currentChannelIndex = currentList.findIndex(
      (c) => c.id === activeChannel.id
    );

    let nextChannelInSameList =
      currentList[currentChannelIndex + (directionUp ? -1 : 1)];
    if (nextChannelInSameList) {
      // You're navigating in the same list of channels, just use index +- 1
      return this.router.transitionTo(
        "chat.channel",
        ...nextChannelInSameList.routeModels
      );
    }

    // You need to go to the next list of channels, if it exists.
    const nextList = otherList.length ? otherList : currentList;
    const nextChannel = directionUp
      ? nextList[nextList.length - 1]
      : nextList[0];

    if (nextChannel.id !== activeChannel.id) {
      return this.router.transitionTo(
        "chat.channel",
        ...nextChannel.routeModels
      );
    }
  }

  getIdealFirstChannelId() {
    // When user opens chat we need to give them the 'best' channel when they enter.
    //
    // Look for public channels with mentions. If one exists, enter that.
    // Next best is a DM channel with unread messages.
    // Next best is a public channel with unread messages.
    // Then we fall back to the chat_default_channel_id site setting
    // if that is present and in the list of channels the user can access.
    // If none of these options exist, then we get the first public channel,
    // or failing that the first DM channel.
    // Defined in order of significance.
    let publicChannelWithMention,
      dmChannelWithUnread,
      publicChannelWithUnread,
      publicChannel,
      dmChannel,
      defaultChannel;

    this.chatChannelsManager.channels.forEach((channel) => {
      const membership = channel.currentUserMembership;

      if (!membership.following) {
        return;
      }

      if (channel.isDirectMessageChannel) {
        if (!dmChannelWithUnread && channel.tracking.unreadCount > 0) {
          dmChannelWithUnread = channel.id;
        } else if (!dmChannel) {
          dmChannel = channel.id;
        }
      } else {
        if (membership.unread_mentions > 0) {
          publicChannelWithMention = channel.id;
          return; // <- We have a public channel with a mention. Break and return this.
        } else if (
          !publicChannelWithUnread &&
          channel.tracking.unreadCount > 0
        ) {
          publicChannelWithUnread = channel.id;
        } else if (
          !defaultChannel &&
          parseInt(this.siteSettings.chat_default_channel_id || 0, 10) ===
            channel.id
        ) {
          defaultChannel = channel.id;
        } else if (!publicChannel) {
          publicChannel = channel.id;
        }
      }
    });

    return (
      publicChannelWithMention ||
      dmChannelWithUnread ||
      publicChannelWithUnread ||
      defaultChannel ||
      publicChannel ||
      dmChannel
    );
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
    const usernames = (channel.chatable.users || [])
      .mapBy("username")
      .concat(user.username)
      .uniq();

    return this.upsertDmChannelForUsernames(usernames);
  }

  // @param {array} usernames - The usernames to create or fetch the direct message
  // channel for. The current user will automatically be included in the channel
  // when it is created.
  upsertDmChannelForUsernames(usernames) {
    return ajax("/chat/api/direct-message-channels.json", {
      method: "POST",
      data: { target_usernames: usernames.uniq() },
    })
      .then((response) => {
        const channel = this.chatChannelsManager.store(response.channel);
        this.chatChannelsManager.follow(channel);
        return channel;
      })
      .catch(popupAjaxError);
  }

  // @param {array} usernames - The usernames to fetch the direct message
  // channel for. The current user will automatically be included as a
  // participant to fetch the channel for.
  getDmChannelForUsernames(usernames) {
    return ajax("/chat/direct_messages.json", {
      data: { usernames: usernames.uniq().join(",") },
    });
  }

  addToolbarButton() {
    deprecated(
      "Use the new chat API `api.registerChatComposerButton` instead of `chat.addToolbarButton`"
    );
  }
}
