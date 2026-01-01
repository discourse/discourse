import { cached, tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import Promise from "rsvp";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { debounce } from "discourse/lib/decorators";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

const DIRECT_MESSAGE_CHANNELS_LIMIT = 50;

/*
  The ChatChannelsManager service is responsible for managing the loaded chat channels.
  It provides helpers to facilitate using and managing loaded channels instead of constantly
  fetching them from the server.
*/

export default class ChatChannelsManager extends Service {
  @service chatApi;
  @service chatSubscriptionsManager;
  @service chatStateManager;
  @service currentUser;
  @service chatDraftsManager;
  @service siteSettings;

  @tracked hasThreads = false;
  @tracked _cached = new TrackedObject();

  async find(id, options = { fetchIfNotFound: true }) {
    const existingChannel = this.#findStale(id);
    if (existingChannel) {
      return Promise.resolve(existingChannel);
    } else if (options.fetchIfNotFound) {
      return await this.#find(id);
    } else {
      return Promise.resolve();
    }
  }

  @cached
  get channels() {
    return Object.values(this._cached);
  }

  store(channelObject, options = {}) {
    let model;

    if (!options.replace) {
      model = this.#findStale(channelObject.id);
    }

    if (!model) {
      if (channelObject instanceof ChatChannel) {
        model = channelObject;
      } else {
        model = ChatChannel.create(channelObject);
      }
      this.#cache(model);
    }

    if (
      channelObject.meta?.message_bus_last_ids?.channel_message_bus_last_id !==
      undefined
    ) {
      model.channelMessageBusLastId =
        channelObject.meta.message_bus_last_ids.channel_message_bus_last_id;
    }

    this.#storeDraftsForChannel(model);

    return model;
  }

  #storeDraftsForChannel(channel) {
    const userChatDrafts = this.currentUser?.chat_drafts;

    if (!userChatDrafts) {
      return;
    }

    const storedDrafts = userChatDrafts.filter(
      (draft) => draft.channel_id === channel.id
    );

    storedDrafts.forEach((storedDraft) => {
      if (
        this.chatDraftsManager.get(
          storedDraft.channel_id,
          storedDraft.thread_id
        )
      ) {
        return;
      }

      this.chatDraftsManager.add(
        ChatMessage.createDraftMessage(
          channel,
          Object.assign(
            { user: this.currentUser },
            JSON.parse(storedDraft.data)
          )
        ),
        storedDraft.channel_id,
        storedDraft.thread_id,
        false
      );
    });
  }

  async follow(model) {
    this.chatSubscriptionsManager.startChannelSubscription(model);

    if (!model.currentUserMembership.following) {
      return this.chatApi.followChannel(model.id).then((membership) => {
        model.currentUserMembership = membership;
        return model;
      });
    } else {
      return model;
    }
  }

  async unfollow(model) {
    try {
      this.chatSubscriptionsManager.stopChannelSubscription(model);
      model.currentUserMembership = await this.chatApi.unfollowChannel(
        model.id
      );
      return model;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @debounce(300)
  async markAllChannelsRead() {
    // The user tracking state for each channel marked read will be propagated by MessageBus
    return this.chatApi.markAllChannelsAsRead();
  }

  remove(model) {
    if (!model) {
      return;
    }
    this.chatSubscriptionsManager.stopChannelSubscription(model);
    delete this._cached[model.id];
  }

  @cached
  get hasThreadedChannels() {
    return this.allChannels?.some((channel) => channel.threadingEnabled);
  }

  get shouldShowMyThreads() {
    return this.hasThreadedChannels && this.hasThreads;
  }

  get allChannels() {
    return [...this.publicMessageChannels, ...this.directMessageChannels].sort(
      (a, b) => {
        return b?.currentUserMembership?.lastViewedAt?.localeCompare?.(
          a?.currentUserMembership?.lastViewedAt
        );
      }
    );
  }

  @cached
  get publicMessageChannels() {
    return this.#sortChannelsByProperty(
      this.channels.filter(
        (channel) =>
          channel.isCategoryChannel && channel.currentUserMembership.following
      ),
      "slug"
    );
  }

  get publicMessageChannelsWithActivity() {
    return this.publicMessageChannels.filter((channel) => channel.hasUnread);
  }

  get publicMessageChannelsByActivity() {
    return this.#sortChannelsByActivity([...this.publicMessageChannels]);
  }

  /**
   * Returns all public message channels sorted by activity (unreads first).
   * Used in mobile/drawer mode where starred channels appear in both tabs.
   *
   * @returns {ChatChannel[]} Array of public channels sorted by activity
   */
  get allPublicChannelsByActivity() {
    return this.#sortChannelsByActivityUnreadsFirst([
      ...this.publicMessageChannels,
    ]);
  }

  /**
   * Returns public message channels that are not starred, sorted by activity.
   * Falls back to all public channels by activity if starring is disabled.
   * Channels with unreads appear first, then sorted alphabetically.
   *
   * @returns {ChatChannel[]} Array of unstarred public channels sorted by activity
   */
  get unstarredPublicMessageChannelsByActivity() {
    return this.#sortChannelsByActivity(
      this.channels.filter(
        (channel) =>
          channel.isCategoryChannel &&
          channel.currentUserMembership?.following &&
          !channel.currentUserMembership?.starred
      )
    );
  }

  @cached
  get directMessageChannels() {
    return this.#sortDirectMessageChannels(
      this.channels.filter((channel) => {
        const membership = channel.currentUserMembership;
        return channel.isDirectMessageChannel && membership.following;
      })
    );
  }

  get directMessageChannelsWithActivity() {
    return this.directMessageChannels.filter((channel) => channel.hasUnread);
  }

  get truncatedDirectMessageChannels() {
    return this.directMessageChannels.slice(0, DIRECT_MESSAGE_CHANNELS_LIMIT);
  }

  /**
   * Returns all direct message channels sorted by activity (unreads first).
   * Used in mobile/drawer mode where starred channels appear in both tabs.
   *
   * @returns {ChatChannel[]} Array of DM channels sorted by activity
   */
  get directMessageChannelsByActivity() {
    return this.#sortDirectMessageChannelsByActivity(
      this.channels.filter((channel) => {
        const membership = channel.currentUserMembership;
        return channel.isDirectMessageChannel && membership?.following;
      })
    );
  }

  get truncatedDirectMessageChannelsByActivity() {
    return this.directMessageChannelsByActivity.slice(
      0,
      DIRECT_MESSAGE_CHANNELS_LIMIT
    );
  }

  /**
   * Returns all channels (public and DM) that the current user has starred.
   * Public channels are sorted alphabetically by slug, DMs by title.
   *
   * @returns {ChatChannel[]} Array of starred channels
   */
  get starredChannels() {
    const starredPublic = this.channels
      .filter(
        (channel) =>
          channel.isCategoryChannel &&
          channel.currentUserMembership?.following &&
          channel.currentUserMembership?.starred
      )
      .sort((a, b) => (a.slug || "").localeCompare(b.slug || ""));

    const starredDMs = this.channels
      .filter(
        (channel) =>
          channel.isDirectMessageChannel &&
          channel.currentUserMembership?.following &&
          channel.currentUserMembership?.starred
      )
      .sort((a, b) => (a.title || "").localeCompare(b.title || ""));

    return [...starredPublic, ...starredDMs];
  }

  /**
   * Checks if the current user has any starred channels.
   *
   * @returns {boolean} True if user has starred at least one channel
   */
  get hasStarredChannels() {
    return this.starredChannels.length > 0;
  }

  /**
   * Returns all starred channels sorted by activity (unreads first).
   * Prioritizes unread status over channel type:
   * 1. Unread public channels (sorted by activity)
   * 2. Unread DMs/Groups (sorted by activity)
   * 3. Read public channels (sorted by activity)
   * 4. Read DMs/Groups (sorted by activity)
   *
   * @returns {ChatChannel[]} Array of starred channels sorted by activity
   */
  get starredChannelsByActivity() {
    const starredChannels = this.channels.filter(
      (channel) =>
        channel.currentUserMembership?.following &&
        channel.currentUserMembership?.starred
    );

    return starredChannels.sort((a, b) => {
      const aUrgent = this.#getChannelUrgentCount(a);
      const bUrgent = this.#getChannelUrgentCount(b);
      const aUnread = this.#getChannelUnreadCount(a);
      const bUnread = this.#getChannelUnreadCount(b);

      const aHasActivity = aUrgent > 0 || aUnread > 0;
      const bHasActivity = bUrgent > 0 || bUnread > 0;

      // First: prioritize channels with activity over those without
      if (aHasActivity !== bHasActivity) {
        return aHasActivity ? -1 : 1;
      }

      // Within the same activity state, sort by channel type (public first)
      if (a.isDirectMessageChannel !== b.isDirectMessageChannel) {
        return a.isDirectMessageChannel ? 1 : -1;
      }

      // Within the same channel type and activity state:
      // If both have activity, prioritize by urgent then unread
      if (aHasActivity && bHasActivity) {
        if (aUrgent > 0 && bUrgent > 0) {
          return this.#compareByLastActivity(a, b);
        }
        if (aUrgent > 0 || bUrgent > 0) {
          return aUrgent > bUrgent ? -1 : 1;
        }
        if (aUnread > 0 && bUnread > 0) {
          return this.#compareByLastActivity(a, b);
        }
        if (aUnread > 0 || bUnread > 0) {
          return aUnread > bUnread ? -1 : 1;
        }
      }

      // Sort remaining by last activity
      return this.#compareByLastActivity(a, b);
    });
  }

  #getChannelUrgentCount(channel) {
    if (channel.isDirectMessageChannel) {
      return (
        channel.tracking.unreadCount +
        channel.tracking.mentionCount +
        channel.tracking.watchedThreadsUnreadCount
      );
    }
    return (
      channel.tracking.mentionCount + channel.tracking.watchedThreadsUnreadCount
    );
  }

  #getChannelUnreadCount(channel) {
    return (
      channel.tracking.unreadCount + channel.unreadThreadsCountSinceLastViewed
    );
  }

  #compareByLastActivity(a, b) {
    const aDate = a.lastMessage?.createdAt
      ? new Date(a.lastMessage.createdAt)
      : new Date(0);
    const bDate = b.lastMessage?.createdAt
      ? new Date(b.lastMessage.createdAt)
      : new Date(0);
    return bDate - aDate;
  }

  /**
   * Returns public message channels that are not starred.
   * Falls back to all public channels if starring is disabled.
   * Channels are sorted with starred channels first, then by slug.
   *
   * @returns {ChatChannel[]} Array of unstarred public channels
   */
  get unstarredPublicMessageChannels() {
    return this.#sortChannelsByProperty(
      this.channels.filter(
        (channel) =>
          channel.isCategoryChannel &&
          channel.currentUserMembership?.following &&
          !channel.currentUserMembership?.starred
      ),
      "slug"
    );
  }

  /**
   * Returns direct message channels that are not starred.
   * Falls back to all DM channels if starring is disabled.
   * Channels are sorted with starred channels first, then by activity.
   *
   * @returns {ChatChannel[]} Array of unstarred DM channels
   */
  get unstarredDirectMessageChannels() {
    return this.#sortDirectMessageChannels(
      this.channels.filter((channel) => {
        const membership = channel.currentUserMembership;
        return (
          channel.isDirectMessageChannel &&
          membership?.following &&
          !membership?.starred
        );
      })
    );
  }

  get truncatedUnstarredDirectMessageChannels() {
    return this.unstarredDirectMessageChannels.slice(
      0,
      DIRECT_MESSAGE_CHANNELS_LIMIT
    );
  }

  async #find(id) {
    try {
      const result = await this.chatApi.channel(id);
      return this.store(result.channel);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get publicMessageChannelsEmpty() {
    return (
      this.publicMessageChannels?.length === 0 &&
      this.chatStateManager.hasPreloadedChannels
    );
  }

  get displayPublicChannels() {
    if (!this.siteSettings.enable_public_channels) {
      return false;
    }

    if (!this.chatStateManager.hasPreloadedChannels) {
      return false;
    }

    if (this.publicMessageChannelsEmpty) {
      return (
        this.currentUser?.staff ||
        this.currentUser?.has_joinable_public_channels
      );
    }

    return true;
  }

  #cache(channel) {
    if (!channel) {
      return;
    }

    this._cached[channel.id] = channel;
  }

  #findStale(id) {
    return this._cached[id];
  }

  /**
   * Compares two channels for sorting, prioritizing starred channels.
   * Returns a sort value if starred status differs, or if both are starred.
   * Returns null if both channels have the same starred status (both unstarred).
   *
   * @param {ChatChannel} a - First channel to compare
   * @param {ChatChannel} b - Second channel to compare
   * @param {string} property - Property name to use for sorting starred channels
   * @returns {number|null} Sort value (-1, 0, 1) or null if no starred sorting needed
   */
  #compareStarredChannels(a, b, property) {
    const aStarred = a.currentUserMembership?.starred;
    const bStarred = b.currentUserMembership?.starred;

    // if both channels are starred, sort by the specified property
    if (aStarred && bStarred) {
      const aValue = a[property] || "";
      const bValue = b[property] || "";
      return aValue.localeCompare(bValue);
    }

    // prioritize starred channels over non-starred
    if (aStarred || bStarred) {
      return aStarred ? -1 : 1;
    }

    return null; // no starred sorting needed
  }

  /**
   * Wraps a comparison function with starred channel prioritization.
   * Starred channels are always sorted first, then the provided comparison
   * function is used for unstarred channels.
   *
   * @param {string} property - Property name to use for sorting starred channels
   * @param {Function} compareFn - Comparison function for unstarred channels
   * @returns {Function} Wrapped comparison function
   */
  #withStarredPriority(property, compareFn) {
    return (a, b) => {
      const starredResult = this.#compareStarredChannels(a, b, property);
      if (starredResult !== null) {
        return starredResult;
      }
      return compareFn(a, b);
    };
  }

  #sortChannelsByActivity(channels) {
    return channels.sort(
      this.#withStarredPriority("slug", (a, b) => {
        return this.#compareChannelsByActivity(a, b);
      })
    );
  }

  /**
   * Sorts public channels by activity without starred priority.
   * Unreads come first regardless of starred status.
   */
  #sortChannelsByActivityUnreadsFirst(channels) {
    return channels.sort((a, b) => {
      return this.#compareChannelsByActivity(a, b);
    });
  }

  #compareChannelsByActivity(a, b) {
    const stats = {
      a: {
        urgent: a.tracking.mentionCount + a.tracking.watchedThreadsUnreadCount,
        unread: a.tracking.unreadCount + a.unreadThreadsCountSinceLastViewed,
      },
      b: {
        urgent: b.tracking.mentionCount + b.tracking.watchedThreadsUnreadCount,
        unread: b.tracking.unreadCount + b.unreadThreadsCountSinceLastViewed,
      },
    };

    // if both channels have urgent count, sort by slug
    // otherwise prioritize channel with urgent count
    if (stats.a.urgent > 0 && stats.b.urgent > 0) {
      return a.slug?.localeCompare?.(b.slug);
    }

    if (stats.a.urgent > 0 || stats.b.urgent > 0) {
      return stats.a.urgent > stats.b.urgent ? -1 : 1;
    }

    // if both channels have unread messages or threads, sort by slug
    // otherwise prioritize channel with unread count
    if (stats.a.unread > 0 && stats.b.unread > 0) {
      return a.slug?.localeCompare?.(b.slug);
    }

    if (stats.a.unread > 0 || stats.b.unread > 0) {
      return stats.a.unread > stats.b.unread ? -1 : 1;
    }

    return a.slug?.localeCompare?.(b.slug);
  }

  #sortChannelsByProperty(channels, property) {
    return channels.sort(
      this.#withStarredPriority(property, (a, b) => {
        return (a[property] || "").localeCompare(b[property] || "");
      })
    );
  }

  #sortDirectMessageChannels(channels) {
    return channels.sort(
      this.#withStarredPriority("title", (a, b) => {
        return this.#compareDirectMessageChannelsByActivity(a, b);
      })
    );
  }

  /**
   * Sorts DM channels by activity without starred priority.
   * Unreads come first regardless of starred status.
   */
  #sortDirectMessageChannelsByActivity(channels) {
    return channels.sort((a, b) => {
      return this.#compareDirectMessageChannelsByActivity(a, b);
    });
  }

  #compareDirectMessageChannelsByActivity(a, b) {
    if (!a.lastMessage.id) {
      return 1;
    }

    if (!b.lastMessage.id) {
      return -1;
    }

    const aUrgent =
      a.tracking.unreadCount +
      a.tracking.mentionCount +
      a.tracking.watchedThreadsUnreadCount;

    const bUrgent =
      b.tracking.unreadCount +
      b.tracking.mentionCount +
      b.tracking.watchedThreadsUnreadCount;

    const aUnread = a.unreadThreadsCountSinceLastViewed;
    const bUnread = b.unreadThreadsCountSinceLastViewed;

    // if both channels have urgent count, sort by last message date
    if (aUrgent > 0 && bUrgent > 0) {
      return new Date(a.lastMessage.createdAt) >
        new Date(b.lastMessage.createdAt)
        ? -1
        : 1;
    }

    // otherwise prioritize channel with urgent count
    if (aUrgent > 0 || bUrgent > 0) {
      return aUrgent > bUrgent ? -1 : 1;
    }

    // if both channels have unread threads, sort by last thread reply date
    if (aUnread > 0 && bUnread > 0) {
      return a.lastUnreadThreadDate > b.lastUnreadThreadDate ? -1 : 1;
    }

    // otherwise prioritize channel with unread thread count
    if (aUnread > 0 || bUnread > 0) {
      return aUnread > bUnread ? -1 : 1;
    }

    // read channels are sorted by last message date
    return new Date(a.lastMessage.createdAt) > new Date(b.lastMessage.createdAt)
      ? -1
      : 1;
  }
}
