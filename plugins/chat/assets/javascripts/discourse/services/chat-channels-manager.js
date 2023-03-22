import Service, { inject as service } from "@ember/service";
import Promise from "rsvp";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
import { tracked } from "@glimmer/tracking";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { popupAjaxError } from "discourse/lib/ajax-error";

const DIRECT_MESSAGE_CHANNELS_LIMIT = 20;

/*
  The ChatChannelsManager service is responsible for managing the loaded chat channels.
  It provides helpers to facilitate using and managing laoded channels instead of constantly
  fetching them from the server.
*/

export default class ChatChannelsManager extends Service {
  @service chatSubscriptionsManager;
  @service chatApi;
  @service currentUser;
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

  get channels() {
    return Object.values(this._cached);
  }

  store(channelObject) {
    let model = this.#findStale(channelObject.id);

    if (!model) {
      model = ChatChannel.create(channelObject);
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
        model.currentUserMembership.following = membership.following;
        model.currentUserMembership.muted = membership.muted;
        model.currentUserMembership.desktop_notification_level =
          membership.desktop_notification_level;
        model.currentUserMembership.mobile_notification_level =
          membership.mobile_notification_level;

        return model;
      });
    } else {
      return Promise.resolve(model);
    }
  }

  async unfollow(model) {
    this.chatSubscriptionsManager.stopChannelSubscription(model);

    return this.chatApi.unfollowChannel(model.id).then((membership) => {
      model.currentUserMembership = membership;

      return model;
    });
  }

  remove(model) {
    this.chatSubscriptionsManager.stopChannelSubscription(model);
    delete this._cached[model.id];
  }

  get unreadCount() {
    let count = 0;
    this.publicMessageChannels.forEach((channel) => {
      count += channel.currentUserMembership.unread_count || 0;
    });
    return count;
  }

  get unreadUrgentCount() {
    let count = 0;
    this.channels.forEach((channel) => {
      if (channel.isDirectMessageChannel) {
        count += channel.currentUserMembership.unread_count || 0;
      }
      count += channel.currentUserMembership.unread_mentions || 0;
    });
    return count;
  }

  get publicMessageChannels() {
    return this.channels
      .filter(
        (channel) =>
          channel.isCategoryChannel && channel.currentUserMembership.following
      )
      .sort((a, b) => a?.slug?.localeCompare?.(b?.slug));
  }

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
    return this.chatApi
      .channel(id)
      .catch(popupAjaxError)
      .then((channel) => {
        this.#cache(channel);
        return channel;
      });
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

  #sortDirectMessageChannels(channels) {
    return channels.sort((a, b) => {
      const unreadCountA = a.currentUserMembership.unread_count || 0;
      const unreadCountB = b.currentUserMembership.unread_count || 0;
      if (unreadCountA === unreadCountB) {
        return new Date(a.lastMessageSentAt) > new Date(b.lastMessageSentAt)
          ? -1
          : 1;
      } else {
        return unreadCountA > unreadCountB ? -1 : 1;
      }
    });
  }
}
