import { tracked } from "@glimmer/tracking";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import { cloneJSON } from "discourse/lib/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatThreadPreview from "discourse/plugins/chat/discourse/models/chat-thread-preview";

export default class ChatChannelSubscriptionManager {
  @service currentUser;
  @service chatChannelNoticesManager;
  @service messageBus;

  @tracked channel;

  constructor(context, channel, { onNewMessage } = {}) {
    setOwner(this, getOwner(context));

    this.channel = channel;
    this.onNewMessage = onNewMessage;

    this.messageBus.subscribe(
      this.messageBusChannel,
      this.onMessage,
      this.channel.channelMessageBusLastId
    );
  }

  get messagesManager() {
    return this.channel.messagesManager;
  }

  get messageBusChannel() {
    return `/chat/${this.channel.id}`;
  }

  teardown() {
    this.messageBus.unsubscribe(this.messageBusChannel, this.onMessage);
  }

  @bind
  onMessage(busData, _, __, lastMessageBusId) {
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
      case "refresh":
        this.handleRefreshMessage(busData);
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
      case "self_flagged":
        this.handleSelfFlaggedMessage(busData);
        break;
      case "flag":
        this.handleFlaggedMessage(busData);
        break;
      case "thread_created":
        this.handleNewThreadCreated(busData);
        break;
      case "update_thread_original_message":
        this.handleThreadOriginalMessageUpdate(busData);
        break;
      case "notice":
        this.handleNotice(busData);
        break;
    }

    this.channel.channelMessageBusLastId = lastMessageBusId;
  }

  handleSentMessage(data) {
    if (data.chat_message.user.id === this.currentUser.id && data.staged_id) {
      const stagedMessage = this.handleStagedMessage(
        this.channel,
        this.messagesManager,
        data
      );
      if (stagedMessage) {
        return;
      }
    }

    const message = ChatMessage.create(this.channel, data.chat_message);
    message.manager = this.channel.messagesManager;
    this.onNewMessage?.(message);
    this.channel.lastMessage = message;
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
    stagedMessage.cooked = data.chat_message.cooked;

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
      message.message = data.chat_message.message;
      message.cooked = data.chat_message.cooked;
      message.excerpt = data.chat_message.excerpt;
      message.uploads = cloneJSON(data.chat_message.uploads || []);
      message.edited = data.chat_message.edited;
      message.streaming = data.chat_message.streaming;
    }
  }

  handleRefreshMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.incrementVersion();
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
      return;
    }

    if (this.currentUser.staff || this.currentUser.id === targetMsg.user.id) {
      targetMsg.deletedAt = data.deleted_at;
      targetMsg.deletedById = data.deleted_by_id;
      targetMsg.expanded = false;
    } else {
      this.messagesManager.removeMessage(targetMsg);
    }

    if (this.channel.currentUserMembership.lastReadMessageId === targetMsg.id) {
      this.channel.currentUserMembership.lastReadMessageId =
        data.latest_not_deleted_message_id;
    }
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

  handleSelfFlaggedMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message_id);
    if (message) {
      message.userFlagStatus = data.user_flag_status;
    }
  }

  handleFlaggedMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message_id);
    if (message) {
      message.reviewableId = data.reviewable_id;
    }
  }

  handleNewThreadCreated(data) {
    this.channel.threadsManager
      .find(this.channel.id, data.thread_id, { fetchIfNotFound: true })
      .then((thread) => {
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
}
