import { inject as service } from "@ember/service";
import ChatPaneBaseSubscriptionsManager from "./chat-pane-base-subscriptions-manager";
import ChatThreadPreview from "../models/chat-thread-preview";

export default class ChatChannelPaneSubscriptionsManager extends ChatPaneBaseSubscriptionsManager {
  @service chat;
  @service currentUser;

  get messageBusChannel() {
    return `/chat/${this.model.id}`;
  }

  get messageBusLastId() {
    return this.model.channelMessageBusLastId;
  }

  handleSentMessage() {
    return;
  }

  handleThreadOriginalMessageUpdate(data) {
    const message = this.messagesManager.findMessage(data.original_message_id);
    if (message) {
      message.thread.preview = ChatThreadPreview.create(data.preview);
    }
  }

  _afterDeleteMessage(targetMsg, data) {
    if (this.model.currentUserMembership.lastReadMessageId === targetMsg.id) {
      this.model.currentUserMembership.lastReadMessageId =
        data.latest_not_deleted_message_id;
    }
  }
}
