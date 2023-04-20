import Service, { inject as service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import UserChatChannelMembership from "discourse/plugins/chat/discourse/models/user-chat-channel-membership";
import Collection from "../lib/collection";

/**
 * Chat API service. Provides methods to interact with the chat API.
 *
 * @module ChatApi
 * @implements {@ember/service}
 */
export default class ChatApi extends Service {
  @service chat;
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
   * Get a thread in a channel by its ID.
   * @param {number} channelId - The ID of the channel.
   * @param {number} threadId - The ID of the thread.
   * @returns {Promise}
   *
   * @example
   *
   *    this.chatApi.thread(5, 1).then(thread => { ... })
   */
  thread(channelId, threadId) {
    return this.#getRequest(`/channels/${channelId}/threads/${threadId}`).then(
      (result) => this.chat.activeChannel.threadsManager.store(result.thread)
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
   * @returns {Promise}
   *
   * @example
   *
   *    this.chatApi.destroyChannel(1).then(() => { ... })
   */
  destroyChannel(channelId) {
    return this.#deleteRequest(`/channels/${channelId}`);
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
   * Trashes (soft deletes) a chat message.
   * @param {number} channelId - ID of the channel.
   * @param {number} messageId - ID of the message.
   * @returns {Promise}
   */
  trashMessage(channelId, messageId) {
    return this.#deleteRequest(`/channels/${channelId}/messages/${messageId}`);
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
   * Returns messages of a channel, from the last message or a specificed target.
   * @param {number} channelId - The ID of the channel.
   * @param {object} data - Params of the query.
   * @param {integer} data.targetMessageId - ID of the targeted message.
   * @param {integer} data.messageId - ID of the targeted message.
   * @param {integer} data.direction - Fetch past or future messages.
   * @param {integer} data.pageSize - Max number of messages to fetch.
   * @returns {Promise}
   */
  messages(channelId, data = {}) {
    let path;
    const args = {};

    if (data.targetMessageId) {
      path = `/chat/lookup/${data.targetMessageId}`;
      args.chat_channel_id = channelId;
    } else {
      args.page_size = data.pageSize;
      path = `/chat/${channelId}/messages`;

      if (data.messageId) {
        args.message_id = data.messageId;
      }

      if (data.direction) {
        args.direction = data.direction;
      }

      if (data.threadId) {
        args.thread_id = data.threadId;
      }
    }

    return ajax(path, { data: args });
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

  /**
   * Saves a draft for the channel, which includes message contents and uploads.
   * @param {number} channelId - The ID of the channel.
   * @param {object} data - The draft data, see ChatMessageDraft.toJSON() for more details.
   * @returns {Promise}
   */
  saveDraft(channelId, data) {
    // TODO (martin) Change this to postRequest after moving DraftsController into Api::DraftsController
    return ajax("/chat/drafts", {
      type: "POST",
      data: {
        chat_channel_id: channelId,
        data,
      },
      ignoreUnsent: false,
    })
      .then(() => {
        this.chat.markNetworkAsReliable();
      })
      .catch((error) => {
        // we ignore a draft which can't be saved because it's too big
        // and only deal with network error for now
        if (!error.jqXHR?.responseJSON?.errors?.length) {
          this.chat.markNetworkAsUnreliable();
        }
      });
  }

  /**
   * Adds or removes an emoji reaction for a message inside a channel.
   * @param {number} channelId - The ID of the channel.
   * @param {number} messageId - The ID of the message to react on.
   * @param {string} emoji - The text version of the emoji without colons, e.g. tada
   * @param {string} reaction - Either "add" or "remove"
   * @returns {Promise}
   */
  publishReaction(channelId, messageId, emoji, reactAction) {
    // TODO (martin) Not ideal, this should have a chat API controller endpoint.
    return ajax(`/chat/${channelId}/react/${messageId}`, {
      type: "PUT",
      data: {
        react_action: reactAction,
        emoji,
      },
    });
  }

  /**
   * Restores a single deleted chat message in a channel.
   *
   * @param {number} channelId - The ID of the channel for the message being restored.
   * @param {number} messageId - The ID of the message being restored.
   */
  restoreMessage(channelId, messageId) {
    // TODO (martin) Not ideal, this should have a chat API controller endpoint.
    return ajax(`/chat/${channelId}/restore/${messageId}`, {
      type: "PUT",
    });
  }

  /**
   * Rebakes the cooked HTML of a single message in a channel.
   *
   * @param {number} channelId - The ID of the channel for the message being restored.
   * @param {number} messageId - The ID of the message being restored.
   */
  rebakeMessage(channelId, messageId) {
    // TODO (martin) Not ideal, this should have a chat API controller endpoint.
    return ajax(`/chat/${channelId}/${messageId}/rebake`, {
      type: "PUT",
    });
  }

  /**
   * Saves an edit to a message's contents in a channel.
   *
   * @param {number} channelId - The ID of the channel for the message being edited.
   * @param {number} messageId - The ID of the message being edited.
   * @param {object} data - Params of the edit.
   * @param {string} data.new_message - The edited content of the message.
   * @param {Array<number>} data.upload_ids - The uploads attached to the message after editing.
   */
  editMessage(channelId, messageId, data) {
    // TODO (martin) Not ideal, this should have a chat API controller endpoint.
    return ajax(`/chat/${channelId}/edit/${messageId}`, {
      type: "PUT",
      data,
    });
  }

  /**
   * Marks messages for all of a user's chat channel memberships as read.
   *
   * @returns {Promise}
   */
  markAllChannelsAsRead() {
    return this.#putRequest(`/channels/read`);
  }

  /**
   * Marks messages for a single user chat channel membership as read. If no
   * message ID is provided, then the latest message for the channel is fetched
   * on the server and used for the last read message.
   *
   * @param {number} channelId - The ID of the channel for the message being marked as read.
   * @param {number} [messageId] - The ID of the message being marked as read.
   * @returns {Promise}
   */
  markChannelAsRead(channelId, messageId = null) {
    return this.#putRequest(`/channels/${channelId}/read/${messageId}`);
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
