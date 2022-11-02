import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";
export default class ChatApi {
  static async chatChannelMemberships(channelId, data) {
    return await ajax(`/chat/api/chat_channels/${channelId}/memberships.json`, {
      data,
    }).catch(popupAjaxError);
  }

  static async updateChatChannelNotificationsSettings(channelId, data = {}) {
    return await ajax(
      `/chat/api/chat_channels/${channelId}/notifications_settings.json`,
      {
        method: "PUT",
        data,
      }
    ).catch(popupAjaxError);
  }

  static async sendMessage(channelId, data = {}) {
    return ajax(`/chat/${channelId}.json`, {
      ignoreUnsent: false,
      method: "POST",
      data,
    });
  }

  static async chatChannels(data = {}) {
    if (data?.status === "all") {
      delete data.status;
    }

    return await ajax(`/chat/api/chat_channels.json`, {
      method: "GET",
      data,
    })
      .then((channels) =>
        channels.map((channel) => ChatChannel.create(channel))
      )
      .catch(popupAjaxError);
  }

  static async modifyChatChannel(channelId, data) {
    return await this._performRequest(
      `/chat/api/chat_channels/${channelId}.json`,
      {
        method: "PUT",
        data,
      }
    );
  }

  static async unfollowChatChannel(channel) {
    return await this._performRequest(
      `/chat/chat_channels/${channel.id}/unfollow.json`,
      {
        method: "POST",
      }
    ).then((updatedChannel) => {
      channel.updateMembership(updatedChannel.current_user_membership);

      // doesn't matter if this is inaccurate, it will be eventually consistent
      // via the channel-metadata MessageBus channel
      channel.set("memberships_count", channel.memberships_count - 1);
      return channel;
    });
  }

  static async followChatChannel(channel) {
    return await this._performRequest(
      `/chat/chat_channels/${channel.id}/follow.json`,
      {
        method: "POST",
      }
    ).then((updatedChannel) => {
      channel.updateMembership(updatedChannel.current_user_membership);

      // doesn't matter if this is inaccurate, it will be eventually consistent
      // via the channel-metadata MessageBus channel
      channel.set("memberships_count", channel.memberships_count + 1);
      return channel;
    });
  }

  static async categoryPermissions(categoryId) {
    return await this._performRequest(
      `/chat/api/category-chatables/${categoryId}/permissions.json`
    );
  }

  static async _performRequest(...args) {
    return await ajax(...args).catch(popupAjaxError);
  }
}
