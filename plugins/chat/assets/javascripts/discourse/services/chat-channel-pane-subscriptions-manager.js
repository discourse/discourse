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

  handleThreadOriginalMessageUpdate(data) {
    const message = this.messagesManager.findMessage(data.original_message_id);
    if (message) {
      if (data.replies_count) {
        message.threadReplyCount = data.replies_count;
      }
      message.threadTitle = data.title;
    }
  }
}
