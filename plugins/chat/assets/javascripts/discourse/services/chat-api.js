import Service, { service } from "@ember/service";
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

  channel(channelId) {
    return this.#getRequest(`/channels/${channelId}`);
  }

  channelThreadMessages(channelId, threadId, params = {}) {
    return this.#getRequest(
      `/channels/${channelId}/threads/${threadId}/messages?${new URLSearchParams(
        params
      ).toString()}`
    );
  }

  channelMessages(channelId, params = {}) {
    return this.#getRequest(
      `/channels/${channelId}/messages?${new URLSearchParams(
        params
      ).toString()}`
    );
  }

  /**
   * Flags a message in a channel.
   * @param {number} channelId - The ID of the channel.
   * @param {number} messageId - The ID of the message to flag.
   * @param {object} params - Params of the flag.
   * @param {integer} params.flag_type_id
   * @param {string} [params.message]
   * @param {boolean} [params.is_warning]
   * @param {boolean} [params.queue_for_review]
   * @param {boolean} [params.take_action]
   * @returns {Promise}
   *
   * @example
   *
   *    this.chatApi.flagMessage(5, 1);
   */
  flagMessage(channelId, messageId, params = {}) {
    return this.#postRequest(
      `/channels/${channelId}/messages/${messageId}/flags`,
      params
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
    return this.#getRequest(`/channels/${channelId}/threads/${threadId}`);
  }

  /**
   * Loads all threads for a channel.
   * For now we only get the 50 threads ordered
   * by the last message sent by the user then the
   * thread creation date, later we will paginate
   * and add filters.
   * @param {number} channelId - The ID of the channel.
   * @returns {Promise}
   */
  threads(channelId, handler) {
    return new Collection(
      `${this.#basePath}/channels/${channelId}/threads`,
      handler
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
  channels(params = {}) {
    return new Collection(
      `${this.#basePath}/channels`,
      (response) => {
        return response.channels.map((channel) =>
          this.chatChannelsManager.store(channel)
        );
      },
      params
    );
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
   * @param {number} [data.thread_id] - The ID of the thread where this message should be posted.
   * @param {number} [data.topic_id] - The ID of the currently visible topic in drawer mode.
   * @param {number} [data.post_ids] - The ID of the currently visible posts in drawer mode.
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
   * Stop streaming of a message
   * @param {number} channelId - ID of the channel.
   * @param {number} messageId - ID of the message.
   * @returns {Promise}
   */
  stopMessageStreaming(channelId, messageId) {
    return this.#deleteRequest(
      `/channels/${channelId}/messages/${messageId}/streaming`
    );
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
   * Trashes (soft deletes) multiple chat messages.
   * @param {number} channelId - ID of the channel.
   * @param {Array.<number>} messageIds - IDs of the messages to delete.
   * @returns {Promise}
   */
  trashMessages(channelId, messageIds) {
    return this.#deleteRequest(`/channels/${channelId}/messages`, {
      message_ids: messageIds,
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
   * Creates a thread.
   * @param {number} channelId - The ID of the channel.
   * @param {number} originalMessageId - The ID of the original message.
   * @param {object} data - Params of the thread.
   * @param {string} [data.title] - Title of the thread.
   * @returns {Promise}
   */
  createThread(channelId, originalMessageId, data = {}) {
    return this.#postRequest(`/channels/${channelId}/threads`, {
      title: data.title,
      original_message_id: originalMessageId,
    });
  }

  /**
   * Creates a message interaction.
   * @param {number} channelId - The ID of the channel.
   * @param {number} messageId - The ID of the message.
   * @param {object} data - Params of the intereaction.
   * @param {string} data.action_id - The ID of the action.
   * @returns {Promise}
   */
  createInteraction(channelId, messageId, data = {}) {
    return this.#postRequest(
      `/channels/${channelId}/messages/${messageId}/interactions`,
      data
    );
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
  listChannelMemberships(channelId, params = {}) {
    return new Collection(
      `${this.#basePath}/channels/${channelId}/memberships`,
      (response) => {
        return response.memberships.map((membership) =>
          UserChatChannelMembership.create(membership)
        );
      },
      params
    );
  }

  /**
   * Lists public and direct message channels of the current user.
   * @returns {Promise}
   */
  listCurrentUserChannels() {
    return this.#getRequest("/me/channels");
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
    return this.#deleteRequest(
      `/channels/${channelId}/memberships/me/follows`
    ).then((result) => UserChatChannelMembership.create(result.membership));
  }

  /**
   * Destroys the membership of current user on a channel.
   *
   * @param {number} channelId - The ID of the channel.
   * @returns {Promise}
   */
  async leaveChannel(channelId) {
    await this.#deleteRequest(`/channels/${channelId}/memberships/me`);
    const channel = await this.chatChannelsManager.find(channelId, {
      fetchIfNotFound: false,
    });
    if (channel) {
      this.chatChannelsManager.remove(channel);
    }
  }

  /**
   * Get the list of tracked threads for the current user.
   *
   * @returns {Promise}
   */
  userThreads(handler) {
    return new Collection(`${this.#basePath}/me/threads`, handler);
  }

  /**
   * Update notifications settings of current user for a channel.
   * @param {number} channelId - The ID of the channel.
   * @param {object} data - The settings to modify.
   * @param {boolean} [data.muted] - Mutes the channel.
   * @param {string} [data.notification_level] - Notifications level: never, mention or always.
   * @returns {Promise}
   */
  updateCurrentUserChannelNotificationsSettings(channelId, data = {}) {
    return this.#putRequest(
      `/channels/${channelId}/notifications-settings/me`,
      { notifications_settings: data }
    );
  }

  /**
   * Update notifications settings of current user for a thread.
   * @param {number} channelId - The ID of the channel.
   * @param {number} threadId - The ID of the thread.
   * @param {object} data - The settings to modify.
   * @param {boolean} [data.notification_level] - The new notification level, c.f. Chat::NotificationLevels. Threads only support
   *  "regular" and "tracking" for now.
   * @returns {Promise}
   */
  updateCurrentUserThreadNotificationsSettings(channelId, threadId, data) {
    return this.#putRequest(
      `/channels/${channelId}/threads/${threadId}/notifications-settings/me`,
      { notification_level: data.notificationLevel }
    );
  }

  /**
   * Update thread title prompt of current user for a thread.
   * @param {number} channelId - The ID of the channel.
   * @param {number} threadId - The ID of the thread.
   * @returns {Promise}
   */
  updateCurrentUserThreadTitlePrompt(channelId, threadId) {
    return this.#postRequest(
      `/channels/${channelId}/threads/${threadId}/mark-thread-title-prompt-seen/me`
    );
  }

  /**
   * Saves a draft for the channel, which includes message contents and uploads.
   * @param {number} channelId - The ID of the channel.
   * @param {object} data - The draft data, see ChatMessage.toJSONDraft() for more details.
   * @returns {Promise}
   */
  saveDraft(channelId, data, options = {}) {
    let endpoint = `/chat/api/channels/${channelId}`;
    if (options.threadId) {
      endpoint += `/threads/${options.threadId}`;
    }
    endpoint += "/drafts";

    return ajax(endpoint, {
      type: "POST",
      data: {
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
    return this.#putRequest(
      `/channels/${channelId}/messages/${messageId}/restore`
    );
  }

  /**
   * Rebakes the cooked HTML of a single message in a channel.
   *
   * @param {number} channelId - The ID of the channel for the message being restored.
   * @param {number} messageId - The ID of the message being restored.
   */
  rebakeMessage(channelId, messageId) {
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
    return this.#putRequest(
      `/channels/${channelId}/messages/${messageId}`,
      data
    );
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
   * Lists all possible chatables.
   *
   * @param {term} string - The term to search for. # prefix will scope to channels, @ to users.
   *
   * @returns {Promise}
   */
  chatables(args = {}) {
    return this.#getRequest("/chatables", args);
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
    return this.#putRequest(
      `/channels/${channelId}/read?message_id=${messageId}`
    );
  }

  /**
   * Marks messages for a single user chat thread membership as read. If no
   * message ID is provided, then the latest message for the channel is fetched
   * on the server and used for the last read message.
   *
   * @param {number} channelId - The ID of the channel for the thread being marked as read.
   * @param {number} threadId - The ID of the thread being marked as read.
   * @param {number} messageId - The ID of the message being marked as read.
   * @returns {Promise}
   */
  markThreadAsRead(channelId, threadId, messageId) {
    return this.#putRequest(
      `/channels/${channelId}/threads/${threadId}/read?message_id=${messageId}`
    );
  }

  /**
   * Updates settings of a thread.
   *
   * @param {number} channelId - The ID of the channel for the thread being edited.
   * @param {number} threadId - The ID of the thread being edited.
   * @param {object} data - Params of the edit.
   * @param {string} data.title - The new title for the thread.
   */
  editThread(channelId, threadId, data) {
    return this.#putRequest(`/channels/${channelId}/threads/${threadId}`, data);
  }

  /**
   * Generate a quote for a list of messages.
   *
   * @param {number} channelId - The ID of the channel containing the messages.
   * @param {Array<number>} messageIds - The IDs of the messages to quote.
   */
  generateQuote(channelId, messageIds) {
    return ajax(`/chat/${channelId}/quote`, {
      type: "POST",
      data: { message_ids: messageIds },
    });
  }

  /**
   * Invite users to a channel.
   *
   * @param {number} channelId - The ID of the channel.
   * @param {Array<number>} userIds - The IDs of the users to invite.
   * @param {object} options
   * @param {number} options.chat_message_id - A message ID to display in the invite.
   */
  invite(channelId, userIds, options = {}) {
    return this.#postRequest(`/channels/${channelId}/invites`, {
      user_ids: userIds,
      message_id: options.messageId,
    });
  }

  /**
   * Add members to a channel.
   *
   * @param {number} channelId - The ID of the channel.
   * @param {object} targets
   * @param {Array<string>} targets.usernames - The usernames of the users to add.
   * @param {Array<string>} targets.groups - The groups names of the groups to add.
   */
  addMembersToChannel(channelId, targets) {
    return this.#postRequest(`/channels/${channelId}/memberships`, {
      usernames: targets.usernames,
      groups: targets.groups,
    });
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
