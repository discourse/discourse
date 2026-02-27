import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { cloneJSON } from "discourse/lib/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";

export default class ChatMessageSubscriptionManager {
  @service chat;
  @service currentUser;
  @service messageBus;

  constructor(context, { onNewMessage } = {}) {
    setOwner(this, getOwner(context));
    this.onNewMessage = onNewMessage;
  }

  _subscribe() {
    this.messageBus.subscribe(
      this.messageBusChannel,
      this.onMessage,
      this.lastMessageBusId
    );
  }

  get messageBusChannel() {
    throw new Error("messageBusChannel must be implemented by subclass");
  }

  get messagesManager() {
    throw new Error("messagesManager must be implemented by subclass");
  }

  get lastMessageBusId() {
    throw new Error("lastMessageBusId must be implemented by subclass");
  }

  set lastMessageBusId(_value) {
    throw new Error("lastMessageBusId setter must be implemented by subclass");
  }

  get channel() {
    throw new Error("channel must be implemented by subclass");
  }

  teardown() {
    this.messageBus.unsubscribe(this.messageBusChannel, this.onMessage);
  }

  @bind
  onMessage(busData, _, lastMessageBusId) {
    if (
      this.lastMessageBusId >= 0 &&
      lastMessageBusId !== this.lastMessageBusId + 1
    ) {
      this.chat.flagDesync(
        `${this.messageBusChannel}: expected ${this.lastMessageBusId + 1}, got ${lastMessageBusId}`
      );
    }

    switch (busData.type) {
      case "sent":
        this.handleSentMessage(busData);
        break;
      case "reaction":
        this.handleReactionMessage(busData);
        break;
      case "processed":
        this.handleProcessedMessage(busData);
        break;
      case "edit":
        this.handleEditMessage(busData);
        break;
      case "delete":
        this.handleDeleteMessage(busData);
        break;
      case "bulk_delete":
        this.handleBulkDeleteMessage(busData);
        break;
      case "restore":
        this.handleRestoreMessage(busData);
        break;
      case "flag":
        this.handleFlaggedMessage(busData);
        break;
      case "thread_created":
        this.handleNewThreadCreated(busData);
        break;
    }

    this.handleAdditionalTypes(busData);

    this.lastMessageBusId = lastMessageBusId;
  }

  handleAdditionalTypes() {}

  handleSentMessage() {
    throw new Error("handleSentMessage must be implemented by subclass");
  }

  handleStagedMessage(channel, messagesManager, data) {
    const stagedMessage = messagesManager.findStagedMessage(data.staged_id);

    if (!stagedMessage) {
      return;
    }

    stagedMessage.error = null;
    stagedMessage.id = data.chat_message.id;
    stagedMessage.staged = false;
    stagedMessage.excerpt = data.chat_message.excerpt;
    stagedMessage.channel = channel;
    stagedMessage.createdAt = new Date(data.chat_message.created_at);

    return stagedMessage;
  }

  handleProcessedMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.cooked = data.chat_message.cooked;
      message.uploads = cloneJSON(data.chat_message.uploads || []);
      message.processed = true;
      message.incrementVersion();
    }
  }

  handleReactionMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message_id);
    if (message) {
      message.react(data.emoji, data.action, data.user, this.currentUser.id);
    }
  }

  handleEditMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.excerpt = data.chat_message.excerpt;
      message.uploads = cloneJSON(data.chat_message.uploads || []);
      message.edited = data.chat_message.edited;
      message.streaming = data.chat_message.streaming;
    }
  }

  handleBulkDeleteMessage(data) {
    data.deleted_ids.forEach((deletedId) => {
      this.handleDeleteMessage({
        deleted_id: deletedId,
        deleted_at: data.deleted_at,
      });
    });
  }

  handleDeleteMessage(data) {
    const deletedId = data.deleted_id;
    const targetMsg = this.messagesManager.findMessage(deletedId);

    if (!targetMsg) {
      return false;
    }

    if (this.currentUser.staff || this.currentUser.id === targetMsg.user.id) {
      targetMsg.deletedAt = data.deleted_at;
      targetMsg.deletedById = data.deleted_by_id;
      targetMsg.expanded = false;
    } else {
      this.messagesManager.removeMessage(targetMsg);
    }

    return true;
  }

  handleRestoreMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.deletedAt = null;
    } else {
      const newMessage = ChatMessage.create(this.channel, data.chat_message);
      newMessage.manager = this.messagesManager;
      this.messagesManager.addMessages([newMessage]);
    }
  }

  handleFlaggedMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message_id);
    if (message) {
      message.reviewableId = data.reviewable_id;
    }
  }

  handleNewThreadCreated() {}
}
