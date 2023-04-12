import Service, { inject as service } from "@ember/service";
import EmberObject from "@ember/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { cloneJSON } from "discourse-common/lib/object";
import { bind } from "discourse-common/utils/decorators";

export default class ChatChannelPaneSubscriptionsManager extends Service {
  @service chat;
  @service currentUser;

  get messageBusChannel() {
    return `/chat/${this.model.id}`;
  }

  get messageBusLastId() {
    return this.model.channelMessageBusLastId;
  }

  get messagesManager() {
    return this.model.messagesManager;
  }

  subscribe(model) {
    this.unsubscribe();
    this.model = model;
    this.messageBus.subscribe(
      this.messageBusChannel,
      this.onMessage,
      this.messageBusLastId
    );
  }

  unsubscribe() {
    if (!this.model) {
      return;
    }
    this.messageBus.unsubscribe(this.messageBusChannel, this.onMessage);
    this.model = null;
  }

  @bind
  onMessage(busData) {
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
      case "mention_warning":
        this.handleMentionWarning(busData);
        break;
      case "self_flagged":
        this.handleSelfFlaggedMessage(busData);
        break;
      case "flag":
        this.handleFlaggedMessage(busData);
        break;
      case "thread_created":
        this.handleThreadCreated(busData);
        break;
    }
  }

  handleSentMessage() {
    // TODO (martin) Implement this for the channel, since it involves a bunch
    // of scrolling and pane-specific logic. Will leave the existing sub inside
    // ChatLivePane for now.
  }

  handleReactionMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message_id);
    if (message) {
      message.react(data.emoji, data.action, data.user, this.currentUser.id);
    }
  }

  handleProcessedMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.cooked = data.chat_message.cooked;

      // TODO (martin) Move scrolling functionality to pane?
      // this.scrollToLatestMessage();
    }
  }

  handleEditMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.message = data.chat_message.message;
      message.cooked = data.chat_message.cooked;
      message.excerpt = data.chat_message.excerpt;
      message.uploads = cloneJSON(data.chat_message.uploads || []);
      message.edited = true;
      message.incrementVersion();
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
      targetMsg.expanded = false;
    } else {
      this.messagesManager.removeMessage(targetMsg);
    }
  }

  handleRestoreMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.deletedAt = null;
    } else {
      this.messagesManager.addMessages([
        ChatMessage.create(this.args.channel, data.chat_message),
      ]);
    }
  }

  handleMentionWarning(data) {
    const message = this.messagesManager.findMessage(data.chat_message_id);
    if (message) {
      message.mentionWarning = EmberObject.create(data);
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

  handleThreadCreated(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.threadId = data.chat_message.thread_id;
      message.threadReplyCount = 1;
    }
  }
}
