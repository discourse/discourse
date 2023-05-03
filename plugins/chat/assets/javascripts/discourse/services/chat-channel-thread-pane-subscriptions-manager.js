import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatPaneBaseSubscriptionsManager from "./chat-pane-base-subscriptions-manager";

export default class ChatChannelThreadPaneSubscriptionsManager extends ChatPaneBaseSubscriptionsManager {
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

    const message = ChatMessage.create(
      this.chat.activeChannel,
      data.chat_message
    );
    this.messagesManager.addMessages([message]);

    // TODO (martin) All the scrolling and new message indicator shenanigans,
    // as well as handling marking the thread as read.
  }

  // NOTE: noop, there is nothing to do when a thread is created
  // inside the thread panel.
  handleThreadCreated() {
    return;
  }

  // NOTE: noop, there is nothing to do when a thread original message
  // is updated inside the thread panel (for now).
  handleThreadOriginalMessageUpdate() {
    return;
  }
}
