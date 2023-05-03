import Service, { inject as service } from "@ember/service";
import EmberObject from "@ember/object";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { cloneJSON } from "discourse-common/lib/object";
import { bind } from "discourse-common/utils/decorators";

// TODO (martin) This export can be removed once we move the handleSentMessage
// code completely out of ChatLivePane
export function handleStagedMessage(channel, messagesManager, data) {
  const stagedMessage = messagesManager.findStagedMessage(data.staged_id);

  if (!stagedMessage) {
    return;
  }

  stagedMessage.error = null;
  stagedMessage.id = data.chat_message.id;
  stagedMessage.staged = false;
  stagedMessage.excerpt = data.chat_message.excerpt;

  if (stagedMessage.thread.id !== data.chat_message.thread_id) {
    stagedMessage.thread.id = data.chat_message.thread_id;
  }

  stagedMessage.channel = channel;
  stagedMessage.createdAt = data.chat_message.created_at;

  const inReplyToMsg = messagesManager.findMessage(
    data.chat_message.in_reply_to?.id
  );
  if (inReplyToMsg && !inReplyToMsg.thread) {
    inReplyToMsg.thread.id = data.chat_message.thread_id;
  }

  stagedMessage.cooked = data.chat_message.cooked;

  return stagedMessage;
}

/**
 * Handles subscriptions for MessageBus messages sent from Chat::Publisher
 * to the channel and thread panes. There are individual services for
 * each (ChatChannelPaneSubscriptionsManager and ChatChannelThreadPaneSubscriptionsManager)
 * that implement their own logic where necessary. Functions which will
 * always be different between the two raise a "not implemented" error in
 * the base class, and the child class must define the associated function,
 * even if it is a noop in that context.
 *
 * For example, in the thread context there is no need to handle the thread
 * creation event, because the panel will not be open in that case.
 */
export default class ChatPaneBaseSubscriptionsManager extends Service {
  @service chat;
  @service currentUser;

  get messageBusChannel() {
    throw "not implemented";
  }

  get messageBusLastId() {
    throw "not implemented";
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

  // TODO (martin) This can be removed once we move the handleSentMessage
  // code completely out of ChatLivePane
  handleStagedMessageInternal(channel, data) {
    return handleStagedMessage(channel, this.messagesManager, data);
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
        this.handleNewThreadCreated(busData);
        break;
      case "update_thread_original_message":
        this.handleThreadOriginalMessageUpdate(busData);
        break;
    }
  }

  handleSentMessage() {
    throw "not implemented";
  }

  handleProcessedMessage(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.cooked = data.chat_message.cooked;
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
      message.edited = true;
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

  handleNewThreadCreated(data) {
    this.model.threadsManager
      .find(this.model.id, data.staged_thread_id, { fetchIfNotFound: false })
      .then((stagedThread) => {
        stagedThread.staged = false;
        stagedThread.id = data.thread_id;
        stagedThread.originalMessage.thread = stagedThread;
        const channelOriginalMessage = this.model.messagesManager.findMessage(
          stagedThread.originalMessage.id
        );
        channelOriginalMessage.thread = stagedThread;
        channelOriginalMessage.threadReplyCount = 1;
        const threadMessage = stagedThread.messagesManager.findMessage(
          data.chat_message.id
        );
        threadMessage.tread = stagedThread;
      });
  }

  handleThreadOriginalMessageUpdate() {
    throw "not implemented";
  }
}
