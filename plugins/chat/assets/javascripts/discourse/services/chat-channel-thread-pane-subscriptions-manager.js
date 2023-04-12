import ChatChannelPaneSubscriptionsManager from "./chat-channel-pane-subscriptions-manager";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { handleStagedMessage } from "discourse/plugins/chat/discourse/lib/staged-message-handler";

export default class ChatChannelThreadPaneSubscriptionsManager extends ChatChannelPaneSubscriptionsManager {
  get messageBusChannel() {
    return `/chat/${this.model.channelId}/thread/${this.model.id}`;
  }

  get messageBusLastId() {
    return this.model.threadMessageBusLastId;
  }

  // NOTE: This is a noop, there is nothing to do when a thread is created
  // inside the thread panel.
  handleThreadCreated() {
    return;
  }

  handleSentMessage(data) {
    if (data.chat_message.user.id === this.currentUser.id && data.staged_id) {
      return handleStagedMessage(this.messagesManager, data);
    }

    const message = ChatMessage.create(
      this.chat.activeChannel,
      data.chat_message
    );
    this.messagesManager.addMessages([message]);

    // TODO (martin) All the scrolling and new message indicator shenanigans.
  }
}
