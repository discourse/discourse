import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatPaneBaseSubscriptionsManager from "./chat-pane-base-subscriptions-manager";

export default class ChatThreadPaneSubscriptionsManager extends ChatPaneBaseSubscriptionsManager {
  get messageBusChannel() {
    return `/chat/${this.model.channel.id}/thread/${this.model.id}`;
  }

  get messageBusLastId() {
    return this.model.threadMessageBusLastId;
  }

  handleSentMessage(data) {
    if (data.chat_message.user.id === this.currentUser.id && data.staged_id) {
      const stagedMessage = this.handleStagedMessageInternal(
        this.model.channel,
        data
      );
      if (stagedMessage) {
        return;
      }
    }

    const message = ChatMessage.create(this.model.channel, data.chat_message);
    message.thread = this.model;
    this.messagesManager.addMessages([message]);
  }

  // NOTE: noop, there is nothing to do when a thread original message
  // is updated inside the thread panel (for now).
  handleThreadOriginalMessageUpdate() {
    return;
  }

  // NOTE: We don't yet handle notices inside of threads so do nothing.
  handleNotice() {
    return;
  }

  _afterDeleteMessage(targetMsg, data) {
    if (this.model.currentUserMembership?.lastReadMessageId === targetMsg.id) {
      this.model.currentUserMembership.lastReadMessageId =
        data.latest_not_deleted_message_id;
    }
  }
}
