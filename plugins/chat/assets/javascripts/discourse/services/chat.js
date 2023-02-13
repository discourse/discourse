import deprecated from "discourse-common/lib/deprecated";
import { tracked } from "@glimmer/tracking";
import userSearch from "discourse/lib/user-search";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Service, { inject as service } from "@ember/service";
import Site from "discourse/models/site";
import { ajax } from "discourse/lib/ajax";
import { generateCookFunction } from "discourse/lib/text";
import { cancel, next } from "@ember/runloop";
import { and } from "@ember/object/computed";
import { computed } from "@ember/object";
import { Promise } from "rsvp";
import simpleCategoryHashMentionTransform from "discourse/plugins/chat/discourse/lib/simple-category-hash-mention-transform";
import discourseDebounce from "discourse-common/lib/debounce";
import discourseLater from "discourse-common/lib/later";
import userPresent from "discourse/lib/user-presence";

export const LIST_VIEW = "list_view";
export const CHAT_VIEW = "chat_view";
export const DRAFT_CHANNEL_VIEW = "draft_channel_view";

const CHAT_ONLINE_OPTIONS = {
  userUnseenTime: 300000, // 5 minutes seconds with no interaction
  browserHiddenTime: 300000, // Or the browser has been in the background for 5 minutes
};

const READ_INTERVAL = 1000;

export default class Chat extends Service {
  @service appEvents;
  @service chatNotificationManager;
  @service chatSubscriptionsManager;
  @service chatStateManager;
  @service presence;
  @service router;
  @service site;
  @service chatChannelsManager;

  @tracked activeChannel = null;

  cook = null;
  presenceChannel = null;
  sidebarActive = false;
  isNetworkUnreliable = false;

  @and("currentUser.has_chat_enabled", "siteSettings.chat_enabled") userCanChat;

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

  init() {
    super.init(...arguments);

    if (this.userCanChat) {
      this.presenceChannel = this.presence.getChannel("/chat/online");
      this.draftStore = {};

      if (this.currentUser.chat_drafts) {
        this.currentUser.chat_drafts.forEach((draft) => {
          this.draftStore[draft.channel_id] = JSON.parse(draft.data);
        });
      }
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

  setupWithPreloadedChannels(channels) {
    this.chatSubscriptionsManager.startChannelsSubscriptions(
      channels.meta.message_bus_last_ids
    );
    this.presenceChannel.subscribe(channels.global_presence_channel_state);

    [...channels.public_channels, ...channels.direct_message_channels].forEach(
      (channelObject) => {
        const channel = this.chatChannelsManager.store(channelObject);
        return this.chatChannelsManager.follow(channel);
      }
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.userCanChat) {
      this.chatSubscriptionsManager.stopChannelsSubscriptions();
    }
  }

  loadCookFunction(categories) {
    if (this.cook) {
      return Promise.resolve(this.cook);
    }

    const markdownOptions = {
      featuresOverride: Site.currentProp(
        "markdown_additional_options.chat.limited_pretty_text_features"
      ),
      markdownItRules: Site.currentProp(
        "markdown_additional_options.chat.limited_pretty_text_markdown_rules"
      ),
      hashtagTypesInPriorityOrder:
        this.site.hashtag_configurations["chat-composer"],
      hashtagIcons: this.site.hashtag_icons,
    };

    return generateCookFunction(markdownOptions).then((cookFunction) => {
      return this.set("cook", (raw) => {
        return simpleCategoryHashMentionTransform(
          cookFunction(raw),
          categories
        );
      });
    });
  }

  updatePresence() {
    next(() => {
      if (this.isDestroyed || this.isDestroying) {
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
      ? this.chatChannelsManager.unreadUrgentCount
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

  searchPossibleDirectMessageUsers(options) {
    // TODO: implement a chat specific user search function
    return userSearch(options);
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

      if (channel.isDirectMessageChannel) {
        if (!dmChannelWithUnread && membership.unread_count > 0) {
          dmChannelWithUnread = channel.id;
        } else if (!dmChannel) {
          dmChannel = channel.id;
        }
      } else {
        if (membership.unread_mentions > 0) {
          publicChannelWithMention = channel.id;
          return; // <- We have a public channel with a mention. Break and return this.
        } else if (!publicChannelWithUnread && membership.unread_count > 0) {
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

  _fireOpenMessageAppEvent(messageId) {
    this.appEvents.trigger("chat-live-pane:highlight-message", messageId);
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
    return ajax("/chat/direct_messages/create.json", {
      method: "POST",
      data: { usernames: usernames.uniq() },
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

  _saveDraft(channelId, draft) {
    const data = { chat_channel_id: channelId };
    if (draft) {
      data.data = JSON.stringify(draft);
    }

    ajax("/chat/drafts.json", { type: "POST", data, ignoreUnsent: false })
      .then(() => {
        this.markNetworkAsReliable();
      })
      .catch((error) => {
        // we ignore a draft which can't be saved because it's too big
        // and only deal with network error for now
        if (!error.jqXHR?.responseJSON?.errors?.length) {
          this.markNetworkAsUnreliable();
        }
      });
  }

  setDraftForChannel(channel, draft) {
    if (
      draft &&
      (draft.value || draft.uploads.length > 0 || draft.replyToMsg)
    ) {
      this.draftStore[channel.id] = draft;
    } else {
      delete this.draftStore[channel.id];
      draft = null; // _saveDraft will destroy draft
    }

    discourseDebounce(this, this._saveDraft, channel.id, draft, 2000);
  }

  getDraftForChannel(channelId) {
    return (
      this.draftStore[channelId] || {
        value: "",
        uploads: [],
        replyToMsg: null,
      }
    );
  }

  updateLastReadMessage() {
    discourseDebounce(this, this._queuedReadMessageUpdate, READ_INTERVAL);
  }

  _queuedReadMessageUpdate() {
    const visibleMessages = document.querySelectorAll(
      ".chat-message-container[data-visible=true]"
    );
    const channel = this.activeChannel;

    if (
      !channel?.isFollowing ||
      visibleMessages?.length === 0 ||
      !userPresent()
    ) {
      return;
    }

    const latestUnreadMsgId = parseInt(
      visibleMessages[visibleMessages.length - 1].dataset.id,
      10
    );

    const membership = channel.currentUserMembership;
    const hasUnreadMessages =
      latestUnreadMsgId > membership.last_read_message_id;
    if (
      hasUnreadMessages ||
      membership.unread_count > 0 ||
      membership.unread_mentions > 0
    ) {
      channel.updateLastReadMessage(latestUnreadMsgId);
    }
  }

  addToolbarButton() {
    deprecated(
      "Use the new chat API `api.registerChatComposerButton` instead of `chat.addToolbarButton`"
    );
  }
}
