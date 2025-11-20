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
    const channels = this.channels.filter(
      (channel) =>
        channel.isCategoryChannel && channel.currentUserMembership.following
    );

    return channels.sort((a, b) => {
      const pinnedResult = this.#comparePinnedChannels(a, b, "slug");
      if (pinnedResult !== null) {
        return pinnedResult;
      }

      // Both unpinned, sort alphabetically by slug
      const aSlug = a.slug || "";
      const bSlug = b.slug || "";
      return aSlug.localeCompare(bSlug);
    });
  }

  get publicMessageChannelsWithActivity() {
    return this.publicMessageChannels.filter((channel) => channel.hasUnread);
  }

  get publicMessageChannelsByActivity() {
    const channels = [...this.publicMessageChannels];
    const pinned = channels.filter((c) => c.currentUserMembership?.pinned);
    const unpinned = channels.filter((c) => !c.currentUserMembership?.pinned);

    // Sort unpinned by activity
    const sortedUnpinned = this.#sortChannelsByActivity(unpinned);

    return [...pinned, ...sortedUnpinned];
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

  #comparePinnedChannels(a, b, property) {
    const aPinned = a.currentUserMembership?.pinned;
    const bPinned = b.currentUserMembership?.pinned;

    // if both channels are pinned, sort by the specified property
    if (aPinned && bPinned) {
      const aValue = a[property] || "";
      const bValue = b[property] || "";
      return aValue.localeCompare(bValue);
    }

    // prioritize pinned channels over non-pinned
    if (aPinned || bPinned) {
      return aPinned ? -1 : 1;
    }

    return null; // no pinned sorting needed
  }

  #sortChannelsByActivity(channels) {
    return channels.sort((a, b) => {
      const pinnedResult = this.#comparePinnedChannels(a, b, "slug");
      if (pinnedResult !== null) {
        return pinnedResult;
      }

      const stats = {
        a: {
          urgent:
            a.tracking.mentionCount + a.tracking.watchedThreadsUnreadCount,
          unread: a.tracking.unreadCount + a.unreadThreadsCountSinceLastViewed,
        },
        b: {
          urgent:
            b.tracking.mentionCount + b.tracking.watchedThreadsUnreadCount,
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
    });
  }

  #sortDirectMessageChannels(channels) {
    return channels.sort((a, b) => {
      const pinnedResult = this.#comparePinnedChannels(a, b, "title");
      if (pinnedResult !== null) {
        return pinnedResult;
      }

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
      return new Date(a.lastMessage.createdAt) >
        new Date(b.lastMessage.createdAt)
        ? -1
        : 1;
    });
  }
}
