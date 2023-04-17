import { inject as service } from "@ember/service";
import ChatPaneBaseSubscriptionsManager from "./chat-pane-base-subscriptions-manager";

export default class ChatChannelPaneSubscriptionsManager extends ChatPaneBaseSubscriptionsManager {
  @service chat;
  @service currentUser;

  get messageBusChannel() {
    return `/chat/${this.model.id}`;
  }

  get messageBusLastId() {
    return this.model.channelMessageBusLastId;
  }

  // TODO (martin) Implement this for the channel, since it involves a bunch
  // of scrolling and pane-specific logic. Will leave the existing sub inside
  // ChatLivePane for now.
  handleSentMessage() {
    return;
  }

  // TODO (martin) Move scrolling functionality to pane from ChatLivePane?
  afterProcessedMessage() {
    // this.scrollToLatestMessage();
    return;
  }

  handleBulkDeleteMessage(data) {
    data.deleted_ids.forEach((deletedId) => {
      this.handleDeleteMessage({
        deleted_id: deletedId,
        deleted_at: data.deleted_at,
      });
    });
  }

  handleThreadCreated(data) {
    const message = this.messagesManager.findMessage(data.chat_message.id);
    if (message) {
      message.threadId = data.chat_message.thread_id;
      message.threadReplyCount = 0;
    }
  }

  handleThreadOriginalMessageUpdate(data) {
    const message = this.messagesManager.findMessage(data.original_message_id);
    if (message) {
      if (data.action === "increment_reply_count") {
        // TODO (martin) In future we should use a replies_count delivered
        // from the server and simply update the message accordingly, for
        // now we don't have an accurate enough count for this.
        message.threadReplyCount += 1;
      }
    }
  }
}
