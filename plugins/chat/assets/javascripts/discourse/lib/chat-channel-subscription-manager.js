import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatThreadPreview from "discourse/plugins/chat/discourse/models/chat-thread-preview";
import ChatMessageSubscriptionManager from "./chat-message-subscription-manager";

export default class ChatChannelSubscriptionManager extends ChatMessageSubscriptionManager {
  @service chatChannelNoticesManager;

  @tracked _channel;

  constructor(context, channel, { onNewMessage } = {}) {
    super(context, { onNewMessage });
    this._channel = channel;
    this._subscribe();
  }

  get channel() {
    return this._channel;
  }

  get messagesManager() {
    return this.channel.messagesManager;
  }

  get messageBusChannel() {
    return `/chat/${this.channel.id}`;
  }

  get lastMessageBusId() {
    return this.channel.channelMessageBusLastId;
  }

  set lastMessageBusId(value) {
    this.channel.channelMessageBusLastId = value;
  }

  handleAdditionalTypes(busData) {
    switch (busData.type) {
      case "update_thread_original_message":
        this.handleThreadOriginalMessageUpdate(busData);
        break;
      case "notice":
        this.handleNotice(busData);
        break;
      case "pin":
        this.handlePinMessage(busData);
        break;
      case "unpin":
        this.handleUnpinMessage(busData);
        break;
    }
  }

  handleSentMessage(data) {
    if (data.chat_message.user.id === this.currentUser.id && data.staged_id) {
      const stagedMessage = this.handleStagedMessage(
        this.channel,
        this.messagesManager,
        data
      );
      if (stagedMessage) {
        stagedMessage.cooked = data.chat_message.cooked;
        return;
      }
    }

    const message = ChatMessage.create(this.channel, data.chat_message);
    message.manager = this.channel.messagesManager;
    this.onNewMessage?.(message);
    this.channel.lastMessage = message;
  }

  handleEditMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.message = data.chat_message.message;
      message.cooked = data.chat_message.cooked;
    }
    super.handleEditMessage(data);
  }

  handleDeleteMessage(data) {
    const found = super.handleDeleteMessage(data);
    if (!found) {
      return;
    }

    if (
      this.channel.currentUserMembership.lastReadMessageId === data.deleted_id
    ) {
      this.channel.currentUserMembership.lastReadMessageId =
        data.latest_not_deleted_message_id;
    }
  }

  handleNewThreadCreated(data) {
    this.channel.threadsManager
      .find(this.channel.id, data.thread_id, { fetchIfNotFound: false })
      .then((thread) => {
        thread ??= this.channel.threadsManager.add(
          this.channel,
          data.chat_message.thread
        );

        const channelOriginalMessage = this.channel.messagesManager.findMessage(
          thread.originalMessage.id
        );

        if (channelOriginalMessage) {
          channelOriginalMessage.thread = thread;
        }
      });
  }

  handleNotice(data) {
    this.chatChannelNoticesManager.handleNotice(data);
  }

  handleThreadOriginalMessageUpdate(data) {
    const message = this.messagesManager.findMessage(data.original_message_id);
    if (message?.thread) {
      if (message.thread.preview) {
        message.thread.preview.update(data.preview);
      } else {
        message.thread.preview = ChatThreadPreview.create(data.preview);
      }
    }
  }

  handlePinMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message_id);
    if (message) {
      message.pinned = true;
    }

    this.channel.pinnedMessagesCount++;

    if (
      this.channel.currentUserMembership &&
      data.pinned_by_id !== this.currentUser?.id
    ) {
      this.channel.currentUserMembership.hasUnseenPins = true;
    }
  }

  handleUnpinMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message_id);
    if (message) {
      message.pinned = false;
    }

    this.channel.pinnedMessagesCount = Math.max(
      0,
      this.channel.pinnedMessagesCount - 1
    );
  }
}
