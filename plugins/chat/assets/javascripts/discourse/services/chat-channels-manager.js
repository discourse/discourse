import { cached, tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import Promise from "rsvp";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { debounce } from "discourse-common/utils/decorators";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

const DIRECT_MESSAGE_CHANNELS_LIMIT = 20;

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
  @service router;
  @service site;
  @service siteSettings;
  @tracked _cached = new TrackedObject();

  async find(id, options = { fetchIfNotFound: true }) {
    const existingChannel = this.#findStale(id);
    if (existingChannel) {
      return Promise.resolve(existingChannel);
    } else if (options.fetchIfNotFound) {
      return this.#find(id);
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

    return model;
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
    return this.channels
      .filter(
        (channel) =>
          channel.isCategoryChannel && channel.currentUserMembership.following
      )
      .sort((a, b) => a?.slug?.localeCompare?.(b?.slug));
  }

  get publicMessageChannelsByActivity() {
    return this.#sortChannelsByActivity(this.publicMessageChannels);
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

  #sortChannelsByActivity(channels) {
    return channels.sort((a, b) => {
      // if both channels have mention count, sort by slug
      // otherwise prioritize channel with mention count
      if (a.tracking.mentionCount > 0 && b.tracking.mentionCount > 0) {
        return a.slug?.localeCompare?.(b.slug);
      }

      if (a.tracking.mentionCount > 0 || b.tracking.mentionCount > 0) {
        return a.tracking.mentionCount > b.tracking.mentionCount ? -1 : 1;
      }

      // if both channels have unread count, sort by slug
      // otherwise prioritize channel with unread count
      if (a.tracking.unreadCount > 0 && b.tracking.unreadCount > 0) {
        return a.slug?.localeCompare?.(b.slug);
      }

      if (a.tracking.unreadCount > 0 || b.tracking.unreadCount > 0) {
        return a.tracking.unreadCount > b.tracking.unreadCount ? -1 : 1;
      }

      return a.slug?.localeCompare?.(b.slug);
    });
  }

  #sortDirectMessageChannels(channels) {
    return channels.sort((a, b) => {
      if (!a.lastMessage.id) {
        return 1;
      }

      if (!b.lastMessage.id) {
        return -1;
      }

      if (a.tracking.unreadCount === b.tracking.unreadCount) {
        return new Date(a.lastMessage.createdAt) >
          new Date(b.lastMessage.createdAt)
          ? -1
          : 1;
      } else {
        return a.tracking.unreadCount > b.tracking.unreadCount ? -1 : 1;
      }
    });
  }
}
