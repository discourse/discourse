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
    let promise = Promise.resolve();

    if (this.loading) {
      return promise;
    }

    if (
      this._fetchedAll ||
      (this.totalRows && this.items.length >= this.totalRows)
    ) {
      return promise;
    }

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
    }

    return promise.finally(() => {
      this.loading = false;
    });
  }

  #fetch(url) {
    return ajax(url, { type: "GET" });
  }
}

/**
 * @module ChatApi
 * @public
 */
export default class ChatApi extends Service {
  @service chatChannelsManager;

  /**
   * Get a channel by its ID.
   * @param {number} channelId - The ID of the channel.
   * @returns {Promise}
   *
   * @example
   *
   *    this.chatApi.channel(1).then(channel => { ... })
   */
  channel(channelId) {
    return this.#getRequest(`/channels/${channelId}`).then((result) =>
      this.chatChannelsManager.store(result.channel)
    );
  }

  /**
   * List all accessible category channels of the current user.
   * @returns {Collection}
   *
   * @example
   *
   *    this.chatApi.channels.then(channels => { ... })
   */
  channels() {
    return new Collection(`${this.#basePath}/channels`, (response) => {
      return response.channels.map((channel) =>
        this.chatChannelsManager.store(channel)
      );
    });
  }

  /**
   * Moves messages from one channel to another.
   * @param {number} channelId - The ID of the original channel.
   * @param {object} data - Params of the move.
   * @param {Array.<number>} data.message_ids - IDs of the moved messages.
   * @param {number} data.destination_channel_id - ID of the channel where the messages are moved to.
   * @returns {Promise}
   *
   * @example
   *
   *   this.chatApi
   *     .moveChannelMessages(1, {
   *       message_ids: [2, 3],
   *       destination_channel_id: 4,
   *     }).then(() => { ... })
   */
  moveChannelMessages(channelId, data = {}) {
    return this.#postRequest(`/channels/${channelId}/messages/moves`, {
      move: data,
    });
  }

  /**
   * Destroys a channel.
   * @param {number} channelId - The ID of the channel.
   * @param {string} channelName - The name of the channel to be destroyed, used as confirmation.
   * @returns {Promise}
   *
   * @example
   *
   *    this.chatApi.destroyChannel(1, "foo").then(() => { ... })
   */
  destroyChannel(channelId, channelName) {
    return this.#deleteRequest(`/channels/${channelId}`, {
      channel: { name_confirmation: channelName },
    });
  }

  /**
   * Creates a channel.
   * @param {object} data - Params of the channel.
   * @param {string} data.name - The name of the channel.
   * @param {string} data.chatable_id - The category of the channel.
   * @param {string} data.description - The description of the channel.
   * @param {boolean} [data.auto_join_users] - Should users join this channel automatically.
   * @returns {Promise}
   *
   * @example
   *
   *    this.chatApi
   *      .createChannel({ name: "foo", chatable_id: 1, description "bar" })
   *      .then((channel) => { ... })
   */
  createChannel(data = {}) {
    return this.#postRequest("/channels", { channel: data }).then((response) =>
      this.chatChannelsManager.store(response.channel)
    );
  }

  /**
   * Lists chat permissions for a category.
   * @param {number} categoryId - ID of the category.
   * @returns {Promise}
   */
  categoryPermissions(categoryId) {
    return this.#getRequest(`/category-chatables/${categoryId}/permissions`);
  }

  /**
   * Sends a message.
   * @param {number} channelId - ID of the channel.
   * @param {object} data - Params of the message.
   * @param {string} data.message - The raw content of the message in markdown.
   * @param {string} data.cooked - The cooked content of the message.
   * @param {number} [data.in_reply_to_id] - The ID of the replied-to message.
   * @param {number} [data.staged_id] - The staged ID of the message before it was persisted.
   * @param {Array.<number>} [data.upload_ids] - Array of upload ids linked to the message.
   * @returns {Promise}
   */
  sendMessage(channelId, data = {}) {
    return ajax(`/chat/${channelId}`, {
      ignoreUnsent: false,
      type: "POST",
      data,
    });
  }

  /**
   * Creates a channel archive.
   * @param {number} channelId - The ID of the channel.
   * @param {object} data - Params of the archive.
   * @param {string} data.selection - "new_topic" or "existing_topic".
   * @param {string} [data.title] - Title of the topic when creating a new topic.
   * @param {string} [data.category_id] - ID of the category used when creating a new topic.
   * @param {Array.<string>} [data.tags] - tags used when creating a new topic.
   * @param {string} [data.topic_id] - ID of the topic when using an existing topic.
   * @returns {Promise}
   */
  createChannelArchive(channelId, data = {}) {
    return this.#postRequest(`/channels/${channelId}/archives`, {
      archive: data,
    });
  }

  /**
   * Updates a channel.
   * @param {number} channelId - The ID of the channel.
   * @param {object} data - Params of the archive.
   * @param {string} [data.description] - Description of the channel.
   * @param {string} [data.name] - Name of the channel.
   * @returns {Promise}
   */
  updateChannel(channelId, data = {}) {
    return this.#putRequest(`/channels/${channelId}`, { channel: data });
  }

  /**
   * Updates the status of a channel.
   * @param {number} channelId - The ID of the channel.
   * @param {string} status - The new status, can be "open" or "closed".
   * @returns {Promise}
   */
  updateChannelStatus(channelId, status) {
    return this.#putRequest(`/channels/${channelId}/status`, { status });
  }

  /**
   * Lists members of a channel.
   * @param {number} channelId - The ID of the channel.
   * @returns {Collection}
   */
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

  /**
   * Lists public and direct message channels of the current user.
   * @returns {Promise}
   */
  listCurrentUserChannels() {
    return this.#getRequest("/channels/me").then((result) => {
      return (result?.channels || []).map((channel) =>
        this.chatChannelsManager.store(channel)
      );
    });
  }

  /**
   * Makes current user follow a channel.
   * @param {number} channelId - The ID of the channel.
   * @returns {Promise}
   */
  followChannel(channelId) {
    return this.#postRequest(`/channels/${channelId}/memberships/me`).then(
      (result) => UserChatChannelMembership.create(result.membership)
    );
  }

  /**
   * Makes current user unfollow a channel.
   * @param {number} channelId - The ID of the channel.
   * @returns {Promise}
   */
  unfollowChannel(channelId) {
    return this.#deleteRequest(`/channels/${channelId}/memberships/me`).then(
      (result) => UserChatChannelMembership.create(result.membership)
    );
  }

  /**
   * Update notifications settings of current user for a channel.
   * @param {number} channelId - The ID of the channel.
   * @param {object} data - The settings to modify.
   * @param {boolean} [data.muted] - Mutes the channel.
   * @param {string} [data.desktop_notification_level] - Notifications level on desktop: never, mention or always.
   * @param {string} [data.mobile_notification_level] - Notifications level on mobile: never, mention or always.
   * @returns {Promise}
   */
  updateCurrentUserChannelNotificationsSettings(channelId, data = {}) {
    return this.#putRequest(
      `/channels/${channelId}/notifications-settings/me`,
      { notifications_settings: data }
    );
  }

  get #basePath() {
    return "/chat/api";
  }

  #getRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "GET",
      data,
    });
  }

  #putRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "PUT",
      data,
    });
  }

  #postRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "POST",
      data,
    });
  }

  #deleteRequest(endpoint, data = {}) {
    return ajax(`${this.#basePath}${endpoint}`, {
      type: "DELETE",
      data,
    });
  }
}
