import slugifyChannel from "discourse/plugins/chat/discourse/lib/slugify-channel";
import deprecated from "discourse-common/lib/deprecated";
import userSearch from "discourse/lib/user-search";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Service, { inject as service } from "@ember/service";
import Site from "discourse/models/site";
import { ajax } from "discourse/lib/ajax";
import { A } from "@ember/array";
import { generateCookFunction } from "discourse/lib/text";
import { cancel, next } from "@ember/runloop";
import { and } from "@ember/object/computed";
import { Promise } from "rsvp";
import ChatChannel, {
  CHANNEL_STATUSES,
  CHATABLE_TYPES,
} from "discourse/plugins/chat/discourse/models/chat-channel";
import simpleCategoryHashMentionTransform from "discourse/plugins/chat/discourse/lib/simple-category-hash-mention-transform";
import discourseDebounce from "discourse-common/lib/debounce";
import EmberObject, { computed } from "@ember/object";
import ChatApi from "discourse/plugins/chat/discourse/lib/chat-api";
import discourseLater from "discourse-common/lib/later";
import userPresent from "discourse/lib/user-presence";
import { bind } from "discourse-common/utils/decorators";

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
  @service chatStateManager;
  @service presence;
  @service router;
  @service site;

  activeChannel = null;
  allChannels = null;
  cook = null;
  directMessageChannels = null;
  hasFetchedChannels = false;
  hasUnreadMessages = false;
  idToTitleMap = null;
  lastUserTrackingMessageId = null;
  messageId = null;
  presenceChannel = null;
  publicChannels = null;
  sidebarActive = false;
  unreadUrgentCount = null;
  directMessagesLimit = 20;
  isNetworkUnreliable = false;
  @and("currentUser.has_chat_enabled", "siteSettings.chat_enabled") userCanChat;
  _fetchingChannels = null;
  _onNewMentionsCallbacks = new Map();
  _onNewMessagesCallbacks = new Map();

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
      this.set("allChannels", []);
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
    this.currentUser.set("chat_channel_tracking_state", {});
    this._processChannels(channels || {});
    this.subscribeToChannelMessageBus();
    this.userChatChannelTrackingStateChanged();
    this.appEvents.trigger("chat:refresh-channels");
  }

  setupWithoutPreloadedChannels() {
    this.getChannels().then(() => {
      this.subscribeToChannelMessageBus();
    });
  }

  subscribeToChannelMessageBus() {
    this._subscribeToNewChannelUpdates();
    this._subscribeToUserTrackingChannel();
    this._subscribeToChannelEdits();
    this._subscribeToChannelMetadata();
    this._subscribeToChannelStatusChange();
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (this.userCanChat) {
      this.set("allChannels", null);
      this._unsubscribeFromNewDmChannelUpdates();
      this._unsubscribeFromUserTrackingChannel();
      this._unsubscribeFromChannelEdits();
      this._unsubscribeFromChannelMetadata();
      this._unsubscribeFromChannelStatusChange();
      this._unsubscribeFromAllChatChannels();
    }
  }

  setActiveChannel(channel) {
    this.set("activeChannel", channel);
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

      if (
        this.chatStateManager.isFullPageActive ||
        this.chatStateManager.isDrawerActive
      ) {
        this.presenceChannel.enter({ activeOptions: CHAT_ONLINE_OPTIONS });
      } else {
        this.presenceChannel.leave();
      }
    });
  }

  getDocumentTitleCount() {
    return this.chatNotificationManager.shouldCountChatInDocTitle()
      ? this.unreadUrgentCount
      : 0;
  }

  _channelObject() {
    return {
      publicChannels: this.publicChannels,
      directMessageChannels: this.directMessageChannels,
    };
  }

  truncateDirectMessageChannels(channels) {
    return channels.slice(0, this.directMessagesLimit);
  }

  async getChannelsWithFilter(filter, opts = { excludeActiveChannel: true }) {
    let sortedChannels = this.allChannels.sort((a, b) => {
      return new Date(a.last_message_sent_at) > new Date(b.last_message_sent_at)
        ? -1
        : 1;
    });

    const trimmedFilter = filter.trim();
    const lowerCasedFilter = filter.toLowerCase();
    const { activeChannel } = this;

    return sortedChannels.filter((channel) => {
      if (
        opts.excludeActiveChannel &&
        activeChannel &&
        activeChannel.id === channel.id
      ) {
        return false;
      }
      if (!trimmedFilter.length) {
        return true;
      }

      if (channel.isDirectMessageChannel) {
        let userFound = false;
        channel.chatable.users.forEach((user) => {
          if (
            user.username.toLowerCase().includes(lowerCasedFilter) ||
            user.name?.toLowerCase().includes(lowerCasedFilter)
          ) {
            return (userFound = true);
          }
        });
        return userFound;
      } else {
        return channel.title.toLowerCase().includes(lowerCasedFilter);
      }
    });
  }

  switchChannelUpOrDown(direction) {
    const { activeChannel } = this;
    if (!activeChannel) {
      return; // Chat isn't open. Return and do nothing!
    }

    let currentList, otherList;
    if (activeChannel.isDirectMessageChannel) {
      currentList = this.truncateDirectMessageChannels(
        this.directMessageChannels
      );
      otherList = this.publicChannels;
    } else {
      currentList = this.publicChannels;
      otherList = this.truncateDirectMessageChannels(
        this.directMessageChannels
      );
    }

    const directionUp = direction === "up";
    const currentChannelIndex = currentList.findIndex(
      (c) => c.id === activeChannel.id
    );

    let nextChannelInSameList =
      currentList[currentChannelIndex + (directionUp ? -1 : 1)];
    if (nextChannelInSameList) {
      // You're navigating in the same list of channels, just use index +- 1
      return this.openChannel(nextChannelInSameList);
    }

    // You need to go to the next list of channels, if it exists.
    const nextList = otherList.length ? otherList : currentList;
    const nextChannel = directionUp
      ? nextList[nextList.length - 1]
      : nextList[0];

    if (nextChannel.id !== activeChannel.id) {
      return this.openChannel(nextChannel);
    }
  }

  getChannels() {
    return new Promise((resolve) => {
      if (this.hasFetchedChannels) {
        return resolve(this._channelObject());
      }

      if (!this._fetchingChannels) {
        this._fetchingChannels = this._refreshChannels();
      }

      this._fetchingChannels
        .then(() => resolve(this._channelObject()))
        .finally(() => (this._fetchingChannels = null));
    });
  }

  forceRefreshChannels() {
    this.set("hasFetchedChannels", false);
    this._unsubscribeFromAllChatChannels();
    return this.getChannels();
  }

  refreshTrackingState() {
    if (!this.currentUser) {
      return;
    }

    return ajax("/chat/chat_channels.json")
      .then((response) => {
        this.currentUser.set("chat_channel_tracking_state", {});
        (response.direct_message_channels || []).forEach((channel) => {
          this._updateUserTrackingState(channel);
        });
        (response.public_channels || []).forEach((channel) => {
          this._updateUserTrackingState(channel);
        });
      })
      .finally(() => {
        this.userChatChannelTrackingStateChanged();
      });
  }

  _refreshChannels() {
    return new Promise((resolve) => {
      this.setProperties({
        loading: true,
        allChannels: [],
      });
      this.currentUser.set("chat_channel_tracking_state", {});
      ajax("/chat/chat_channels.json").then((channels) => {
        this._processChannels(channels);
        this.userChatChannelTrackingStateChanged();
        this.appEvents.trigger("chat:refresh-channels");
        resolve(this._channelObject());
      });
    });
  }

  _processChannels(channels) {
    // Must be set first because `processChannels` relies on this data.
    this.set("messageBusLastIds", channels.message_bus_last_ids);
    this.setProperties({
      publicChannels: A(
        this.sortPublicChannels(
          (channels.public_channels || []).map((channel) =>
            this.processChannel(channel)
          )
        )
      ),
      directMessageChannels: A(
        this.sortDirectMessageChannels(
          (channels.direct_message_channels || []).map((channel) =>
            this.processChannel(channel)
          )
        )
      ),
      hasFetchedChannels: true,
      loading: false,
    });
    const idToTitleMap = {};
    this.allChannels.forEach((c) => {
      idToTitleMap[c.id] = c.title;
    });
    this.set("idToTitleMap", idToTitleMap);
    this.presenceChannel.subscribe(channels.global_presence_channel_state);
  }

  reSortDirectMessageChannels() {
    this.set(
      "directMessageChannels",
      this.sortDirectMessageChannels(this.directMessageChannels)
    );
  }

  async getChannelBy(key, value) {
    return this.getChannels().then(() => {
      if (!isNaN(value)) {
        value = parseInt(value, 10);
      }
      return (this.allChannels || []).findBy(key, value);
    });
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
    return this.getChannels().then(() => {
      // Defined in order of significance.
      let publicChannelWithMention,
        dmChannelWithUnread,
        publicChannelWithUnread,
        publicChannel,
        dmChannel,
        defaultChannel;

      for (const [channel, state] of Object.entries(
        this.currentUser.chat_channel_tracking_state
      )) {
        if (state.chatable_type === CHATABLE_TYPES.directMessageChannel) {
          if (!dmChannelWithUnread && state.unread_count > 0) {
            dmChannelWithUnread = channel;
          } else if (!dmChannel) {
            dmChannel = channel;
          }
        } else {
          if (state.unread_mentions > 0) {
            publicChannelWithMention = channel;
            break; // <- We have a public channel with a mention. Break and return this.
          } else if (!publicChannelWithUnread && state.unread_count > 0) {
            publicChannelWithUnread = channel;
          } else if (
            !defaultChannel &&
            parseInt(this.siteSettings.chat_default_channel_id || 0, 10) ===
              parseInt(channel, 10)
          ) {
            defaultChannel = channel;
          } else if (!publicChannel) {
            publicChannel = channel;
          }
        }
      }
      return (
        publicChannelWithMention ||
        dmChannelWithUnread ||
        publicChannelWithUnread ||
        defaultChannel ||
        publicChannel ||
        dmChannel
      );
    });
  }

  sortPublicChannels(channels) {
    return channels.sort((a, b) => a.title.localeCompare(b.title));
  }

  sortDirectMessageChannels(channels) {
    return channels.sort((a, b) => {
      const unreadCountA =
        this.currentUser.chat_channel_tracking_state[a.id]?.unread_count || 0;
      const unreadCountB =
        this.currentUser.chat_channel_tracking_state[b.id]?.unread_count || 0;
      if (unreadCountA === unreadCountB) {
        return new Date(a.last_message_sent_at) >
          new Date(b.last_message_sent_at)
          ? -1
          : 1;
      } else {
        return unreadCountA > unreadCountB ? -1 : 1;
      }
    });
  }

  getIdealFirstChannelIdAndTitle() {
    return this.getIdealFirstChannelId().then((channelId) => {
      if (!channelId) {
        return;
      }
      return {
        id: channelId,
        title: this.idToTitleMap[channelId],
      };
    });
  }

  async openChannelAtMessage(channelId, messageId = null) {
    let channel = await this.getChannelBy("id", channelId);
    if (channel) {
      return this._openFoundChannelAtMessage(channel, messageId);
    }

    return ajax(`/chat/chat_channels/${channelId}`).then((response) => {
      const queryParams = messageId ? { messageId } : {};
      return this.router.transitionTo(
        "chat.channel",
        response.id,
        slugifyChannel(response),
        { queryParams }
      );
    });
  }

  async openChannel(channel) {
    return this._openFoundChannelAtMessage(channel);
  }

  async _openFoundChannelAtMessage(channel, messageId = null) {
    if (
      this.router.currentRouteName === "chat.channel.index" &&
      this.activeChannel?.id === channel.id
    ) {
      this.setActiveChannel(channel);
      this._fireOpenMessageAppEvent(messageId);
      return Promise.resolve();
    }

    this.setActiveChannel(channel);

    if (
      this.chatStateManager.isFullPageActive ||
      this.site.mobileView ||
      this.chatStateManager.isFullPagePreferred
    ) {
      const queryParams = messageId ? { messageId } : {};

      return this.router.transitionTo(
        "chat.channel",
        channel.id,
        slugifyChannel(channel),
        { queryParams }
      );
    } else {
      this._fireOpenFloatAppEvent(channel, messageId);
      return Promise.resolve();
    }
  }

  _fireOpenFloatAppEvent(channel, messageId = null) {
    messageId
      ? this.appEvents.trigger(
          "chat:open-channel-at-message",
          channel,
          messageId
        )
      : this.appEvents.trigger("chat:open-channel", channel);
  }

  _fireOpenMessageAppEvent(messageId) {
    this.appEvents.trigger("chat-live-pane:highlight-message", messageId);
  }

  async startTrackingChannel(channel) {
    if (!channel.current_user_membership.following) {
      return;
    }

    let existingChannel = await this.getChannelBy("id", channel.id);
    if (existingChannel) {
      return existingChannel; // User is already tracking this channel. return!
    }

    const existingChannels = channel.isDirectMessageChannel
      ? this.directMessageChannels
      : this.publicChannels;

    // this check shouldn't be needed given the previous check to existingChannel
    // this is a safety net, to ensure we never track duplicated channels
    existingChannel = existingChannels.findBy("id", channel.id);
    if (existingChannel) {
      return existingChannel;
    }

    const newChannel = this.processChannel(channel);
    existingChannels.pushObject(newChannel);
    this.currentUser.chat_channel_tracking_state[channel.id] =
      EmberObject.create({
        unread_count: 1,
        unread_mentions: 0,
        chatable_type: channel.chatable_type,
      });
    this.userChatChannelTrackingStateChanged();
    if (channel.isDirectMessageChannel) {
      this.reSortDirectMessageChannels();
    }
    if (channel.isPublicChannel) {
      this.set("publicChannels", this.sortPublicChannels(this.publicChannels));
    }
    this.appEvents.trigger("chat:refresh-channels");
    return newChannel;
  }

  async stopTrackingChannel(channel) {
    return this.getChannelBy("id", channel.id).then((existingChannel) => {
      if (existingChannel) {
        return this.forceRefreshChannels();
      }
    });
  }

  _subscribeToChannelMetadata() {
    this.messageBus.subscribe(
      "/chat/channel-metadata",
      this._onChannelMetadata,
      this.messageBusLastIds.channel_metadata
    );
  }

  _subscribeToChannelEdits() {
    this.messageBus.subscribe(
      "/chat/channel-edits",
      this._onChannelEdits,
      this.messageBusLastIds.channel_edits
    );
  }

  _subscribeToChannelStatusChange() {
    this.messageBus.subscribe("/chat/channel-status", this._onChannelStatus);
  }

  _unsubscribeFromChannelStatusChange() {
    this.messageBus.unsubscribe("/chat/channel-status", this._onChannelStatus);
  }

  _unsubscribeFromChannelEdits() {
    this.messageBus.unsubscribe("/chat/channel-edits", this._onChannelEdits);
  }

  _unsubscribeFromChannelMetadata() {
    this.messageBus.unsubscribe(
      "/chat/channel-metadata",
      this._onChannelMetadata
    );
  }

  _subscribeToNewChannelUpdates() {
    this.messageBus.subscribe(
      "/chat/new-channel",
      this._onNewChannel,
      this.messageBusLastIds.new_channel
    );
  }

  _unsubscribeFromNewDmChannelUpdates() {
    this.messageBus.unsubscribe("/chat/new-channel", this._onNewChannel);
  }

  _subscribeToSingleUpdateChannel(channel) {
    if (channel.current_user_membership.muted) {
      return;
    }

    // We do this first so we don't multi-subscribe to mention + messages
    // messageBus channels for this chat channel, since _subscribeToSingleUpdateChannel
    // is called from multiple places.
    this._unsubscribeFromChatChannel(channel);

    if (!channel.isDirectMessageChannel) {
      this._subscribeToMentionChannel(channel);
    }

    this._subscribeToNewMessagesChannel(channel);
  }

  _subscribeToMentionChannel(channel) {
    const onNewMentions = () => {
      const trackingState =
        this.currentUser.chat_channel_tracking_state[channel.id];

      if (trackingState) {
        const count = (trackingState.unread_mentions || 0) + 1;
        trackingState.set("unread_mentions", count);
        this.userChatChannelTrackingStateChanged();
      }
    };

    this._onNewMentionsCallbacks.set(channel.id, onNewMentions);

    this.messageBus.subscribe(
      `/chat/${channel.id}/new-mentions`,
      onNewMentions,
      channel.message_bus_last_ids.new_mentions
    );
  }

  _subscribeToNewMessagesChannel(channel) {
    const onNewMessages = (busData) => {
      const trackingState =
        this.currentUser.chat_channel_tracking_state[channel.id];

      if (busData.user_id === this.currentUser.id) {
        // User sent message, update tracking state to no unread
        trackingState.set("chat_message_id", busData.message_id);
      } else {
        // Ignored user sent message, update tracking state to no unread
        if (this.currentUser.ignored_users.includes(busData.username)) {
          trackingState.set("chat_message_id", busData.message_id);
        } else {
          // Message from other user. Increment trackings state
          if (busData.message_id > (trackingState.chat_message_id || 0)) {
            trackingState.set("unread_count", trackingState.unread_count + 1);
          }
        }
      }

      this.userChatChannelTrackingStateChanged();
      channel.set("last_message_sent_at", new Date());

      const directMessageChannel = (this.directMessageChannels || []).findBy(
        "id",
        parseInt(channel.id, 10)
      );

      if (directMessageChannel) {
        this.reSortDirectMessageChannels();
      }
    };

    this._onNewMessagesCallbacks.set(channel.id, onNewMessages);

    this.messageBus.subscribe(
      `/chat/${channel.id}/new-messages`,
      onNewMessages,
      channel.message_bus_last_ids.new_messages
    );
  }

  @bind
  _onChannelMetadata(busData) {
    this.getChannelBy("id", busData.chat_channel_id).then((channel) => {
      if (channel) {
        channel.setProperties({
          memberships_count: busData.memberships_count,
        });
        this.appEvents.trigger("chat:refresh-channel-members");
      }
    });
  }

  @bind
  _onChannelEdits(busData) {
    this.getChannelBy("id", busData.chat_channel_id).then((channel) => {
      if (channel) {
        channel.setProperties({
          title: busData.name,
          description: busData.description,
        });
      }
    });
  }

  @bind
  _onChannelStatus(busData) {
    this.getChannelBy("id", busData.chat_channel_id).then((channel) => {
      if (!channel) {
        return;
      }

      channel.set("status", busData.status);

      // it is not possible for the user to set their last read message id
      // if the channel has been archived, because all the messages have
      // been deleted. we don't want them seeing the blue dot anymore so
      // just completely reset the unreads
      if (busData.status === CHANNEL_STATUSES.archived) {
        this.currentUser.chat_channel_tracking_state[channel.id] = {
          unread_count: 0,
          unread_mentions: 0,
          chatable_type: channel.chatable_type,
        };
        this.userChatChannelTrackingStateChanged();
      }

      this.appEvents.trigger("chat:refresh-channel", channel.id);
    }, this.messageBusLastIds.channel_status);
  }

  @bind
  _onNewChannel(busData) {
    this.startTrackingChannel(ChatChannel.create(busData.chat_channel));
  }

  async followChannel(channel) {
    return ChatApi.followChatChannel(channel).then(() => {
      this.startTrackingChannel(channel);
      this._subscribeToSingleUpdateChannel(channel);
    });
  }

  async unfollowChannel(channel) {
    return ChatApi.unfollowChatChannel(channel).then(() => {
      this._unsubscribeFromChatChannel(channel);
      this.stopTrackingChannel(channel);

      if (channel === this.activeChannel && channel.isDirectMessageChannel) {
        this.router.transitionTo("chat");
      }
    });
  }

  _unsubscribeFromAllChatChannels() {
    (this.allChannels || []).forEach((channel) => {
      this._unsubscribeFromChatChannel(channel);
    });
  }

  _unsubscribeFromChatChannel(channel) {
    this.messageBus.unsubscribe("/chat/*", this._onNewMessagesCallbacks);
    if (!channel.isDirectMessageChannel) {
      this.messageBus.unsubscribe("/chat/*", this._onNewMentionsCallbacks);
    }
  }

  _subscribeToUserTrackingChannel() {
    this.messageBus.subscribe(
      `/chat/user-tracking-state/${this.currentUser.id}`,
      this._onUserTrackingState,
      this.messageBusLastIds.user_tracking_state
    );
  }

  _unsubscribeFromUserTrackingChannel() {
    this.messageBus.unsubscribe(
      `/chat/user-tracking-state/${this.currentUser.id}`,
      this._onUserTrackingState
    );
  }

  @bind
  _onUserTrackingState(busData, _, messageId) {
    const lastId = this.lastUserTrackingMessageId;

    // we don't want this state to go backwards, only catch
    // up if messages from messagebus were missed
    if (!lastId || messageId > lastId) {
      this.lastUserTrackingMessageId = messageId;
    }

    // we are too far out of sync, we should resync everything.
    // this will trigger a route transition and blur the chat input
    if (lastId && messageId > lastId + 1) {
      return this.forceRefreshChannels();
    }

    const trackingState =
      this.currentUser.chat_channel_tracking_state[busData.chat_channel_id];

    if (trackingState) {
      trackingState.set("chat_message_id", busData.chat_message_id);
      trackingState.set("unread_count", 0);
      trackingState.set("unread_mentions", 0);
      this.userChatChannelTrackingStateChanged();
    }
  }

  resetTrackingStateForChannel(channelId) {
    const trackingState =
      this.currentUser.chat_channel_tracking_state[channelId];
    if (trackingState) {
      trackingState.set("unread_count", 0);
      this.userChatChannelTrackingStateChanged();
    }
  }

  userChatChannelTrackingStateChanged() {
    this._recalculateUnreadMessages();
    this.appEvents.trigger("chat:user-tracking-state-changed");
  }

  _recalculateUnreadMessages() {
    let unreadPublicCount = 0;
    let unreadUrgentCount = 0;
    let headerNeedsRerender = false;

    Object.values(this.currentUser.chat_channel_tracking_state).forEach(
      (state) => {
        if (state.muted) {
          return;
        }

        if (state.chatable_type === CHATABLE_TYPES.directMessageChannel) {
          unreadUrgentCount += state.unread_count || 0;
        } else {
          unreadUrgentCount += state.unread_mentions || 0;
          unreadPublicCount += state.unread_count || 0;
        }
      }
    );

    let hasUnreadPublic = unreadPublicCount > 0;
    if (hasUnreadPublic !== this.hasUnreadMessages) {
      headerNeedsRerender = true;
      this.set("hasUnreadMessages", hasUnreadPublic);
    }

    if (unreadUrgentCount !== this.unreadUrgentCount) {
      headerNeedsRerender = true;
      this.set("unreadUrgentCount", unreadUrgentCount);
    }

    this.currentUser.notifyPropertyChange("chat_channel_tracking_state");
    if (headerNeedsRerender) {
      this.appEvents.trigger("chat:rerender-header");
      this.appEvents.trigger("notifications:changed");
    }
  }

  processChannel(channel) {
    channel = ChatChannel.create(channel);
    this._subscribeToSingleUpdateChannel(channel);
    this._updateUserTrackingState(channel);
    this.allChannels.push(channel);
    return channel;
  }

  _updateUserTrackingState(channel) {
    this.currentUser.chat_channel_tracking_state[channel.id] =
      EmberObject.create({
        chatable_type: channel.chatable_type,
        muted: channel.current_user_membership.muted,
        unread_count: channel.current_user_membership.unread_count,
        unread_mentions: channel.current_user_membership.unread_mentions,
        chat_message_id: channel.current_user_membership.last_read_message_id,
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
        const chatChannel = ChatChannel.create(response.chat_channel);
        this.startTrackingChannel(chatChannel);
        return chatChannel;
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

    ajax("/chat/drafts", { type: "POST", data, ignoreUnsent: false })
      .then(() => {
        this.markNetworkAsReliable();
      })
      .catch((error) => {
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

    const hasUnreadMessages = latestUnreadMsgId > channel.lastSendReadMessageId;

    if (
      !hasUnreadMessages &&
      this.currentUser.chat_channel_tracking_state[this.activeChannel.id]
        ?.unread_count > 0
    ) {
      // Weird state here where the chat_channel_tracking_state is wrong. Need to reset it.
      this.resetTrackingStateForChannel(this.activeChannel.id);
    }

    if (hasUnreadMessages) {
      channel.updateLastReadMessage(latestUnreadMsgId);
    }
  }

  addToolbarButton() {
    deprecated(
      "Use the new chat API `api.registerChatComposerButton` instead of `chat.addToolbarButton`"
    );
  }
}
