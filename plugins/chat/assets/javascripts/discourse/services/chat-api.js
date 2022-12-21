import Service, { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import { Promise } from "rsvp";

class Collection {
  @tracked items = [];
  @tracked meta = {};
  @tracked loading = false;

  constructor(resourceURL, handler) {
    this._resourceURL = resourceURL;
    this._handler = handler;
    this._fetchedAll = false;
  }

  get loadMoreURL() {
    return this.meta.load_more_url;
  }

  get totalRows() {
    return this.meta.total_rows;
  }

  get length() {
    return this.items.length;
  }

  // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Iteration_protocols
  [Symbol.iterator]() {
    let index = 0;

    return {
      next: () => {
        if (index < this.items.length) {
          return { value: this.items[index++], done: false };
        } else {
          return { done: true };
        }
      },
    };
  }

  @bind
  load(params = {}) {
    this._fetchedAll = false;

    if (this.loading) {
      return;
    }

    this.loading = true;

    const filteredQueryParams = Object.entries(params).filter(
      ([, v]) => v !== undefined
    );
    const queryString = new URLSearchParams(filteredQueryParams).toString();

    const endpoint = this._resourceURL + (queryString ? `?${queryString}` : "");
    return this.#fetch(endpoint)
      .then((result) => {
        this.items = this._handler(result);
        this.meta = result.meta;
      })
      .finally(() => {
        this.loading = false;
      });
  }

  @bind
  loadMore() {
    if (this.loading) {
      return;
    }

    if (
      this._fetchedAll ||
      (this.totalRows && this.items.length >= this.totalRows)
    ) {
      return;
    }

    let promise;

    this.loading = true;

    if (this.loadMoreURL) {
      promise = this.#fetch(this.loadMoreURL).then((result) => {
        const newItems = this._handler(result);

        if (newItems.length) {
          this.items = this.items.concat(newItems);
        } else {
          this._fetchedAll = true;
        }
        this.meta = result.meta;
      });
    } else {
      promise = Promise.resolve();
    }

    return promise.finally(() => {
      this.loading = false;
    });
  }

  #fetch(url) {
    return ajax(url, { type: "GET" });
  }
}

export default class ChatApi extends Service {
  @service chatChannelsManager;

  getChannel(channelId) {
    return this.#getRequest(`/channels/${channelId}`).then((result) =>
      this.chatChannelsManager.store(result.channel)
    );
  }

  channels() {
    return new Collection(`${this.#basePath}/channels`, (response) => {
      return response.channels.map((channel) =>
        this.chatChannelsManager.store(channel)
      );
    });
  }

  moveChannelMessages(channelId, data = {}) {
    return this.#postRequest(`/channels/${channelId}/messages/moves`, {
      move: data,
    });
  }

  destroyChannel(channelId, data = {}) {
    return this.#deleteRequest(`/channels/${channelId}`, { channel: data });
  }

  createChannel(data = {}) {
    return this.#postRequest("/channels", { channel: data }).then((response) =>
      this.chatChannelsManager.store(response.channel)
    );
  }

  categoryPermissions(categoryId) {
    return ajax(`/chat/api/category-chatables/${categoryId}/permissions`);
  }

  sendMessage(channelId, data = {}) {
    return ajax(`/chat/${channelId}`, {
      ignoreUnsent: false,
      type: "POST",
      data,
    });
  }

  createChannelArchive(channelId, data = {}) {
    return this.#postRequest(`/channels/${channelId}/archives`, {
      archive: data,
    });
  }

  updateChannel(channelId, data = {}) {
    return this.#putRequest(`/channels/${channelId}`, { channel: data });
  }

  updateChannelStatus(channelId, status) {
    return this.#putRequest(`/channels/${channelId}/status`, { status });
  }

  listChannelMemberships(channelId) {
    return new Collection(
      `${this.#basePath}/channels/${channelId}/memberships`,
      (response) => {
        return response.memberships.map((membership) =>
          UserChatChannelMembership.create(membership)
        );
      }
    );
  }

  listCurrentUserChannels() {
    return this.#getRequest(`/channels/me`).then((result) => {
      return (result?.channels || []).map((channel) =>
        this.chatChannelsManager.store(channel)
      );
    });
  }

  followChannel(channelId) {
    return this.#postRequest(`/channels/${channelId}/memberships/me`).then(
      (result) => UserChatChannelMembership.create(result.membership)
    );
  }

  unfollowChannel(channelId) {
    return this.#deleteRequest(`/channels/${channelId}/memberships/me`).then(
      (result) => UserChatChannelMembership.create(result.membership)
    );
  }

  updateCurrentUserChatChannelNotificationsSettings(channelId, data = {}) {
    return this.#putRequest(
      `/channels/${channelId}/notifications-settings/me`,
      { notifications_settings: data }
    );
  }

  get #basePath() {
    return "/chat/api";
  }

  #getRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}/${endpoint}`, {
      type: "GET",
      data,
    });
  }

  #putRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}/${endpoint}`, {
      type: "PUT",
      data,
    });
  }

  #postRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}/${endpoint}`, {
      type: "POST",
      data,
    });
  }

  #deleteRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}/${endpoint}`, {
      type: "DELETE",
      data,
    });
  }
}
