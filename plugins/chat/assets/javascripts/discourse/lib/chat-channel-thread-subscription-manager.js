import { tracked } from "@glimmer/tracking";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatMessageSubscriptionManager from "./chat-message-subscription-manager";

export default class ChatChannelThreadSubscriptionManager extends ChatMessageSubscriptionManager {
  @tracked thread;

  constructor(context, thread, { onNewMessage } = {}) {
    super(context, { onNewMessage });
    this.thread = thread;
    this._subscribe();
  }

  get channel() {
    return this.thread.channel;
  }

  get messagesManager() {
    return this.thread.messagesManager;
  }

  get messageBusChannel() {
    return `/chat/${this.thread.channel.id}/thread/${this.thread.id}`;
  }

  get lastMessageBusId() {
    return this.thread.threadMessageBusLastId;
  }

  set lastMessageBusId(value) {
    this.thread.threadMessageBusLastId = value;
  }

  handleSentMessage(data) {
    if (data.chat_message.user.id === this.currentUser.id && data.staged_id) {
      const stagedMessage = this.handleStagedMessage(
        this.thread.channel,
        this.messagesManager,
        data
      );
      if (stagedMessage) {
        return;
      }
    }

    const message = ChatMessage.create(this.thread.channel, data.chat_message);
    message.thread = this.thread;
    message.manager = this.messagesManager;
    this.onNewMessage?.(message);
  }

  handleDeleteMessage(data) {
    const found = super.handleDeleteMessage(data);
    if (!found) {
      return;
    }

    if (
      this.thread.currentUserMembership?.lastReadMessageId === data.deleted_id
    ) {
      this.thread.currentUserMembership.lastReadMessageId =
        data.latest_not_deleted_message_id;
    }
  }

  handleNewThreadCreated(data) {
    this.thread.threadsManager
      .find(this.thread.id, data.thread_id, { fetchIfNotFound: true })
      .then((thread) => {
        const channelOriginalMessage = this.thread.messagesManager.findMessage(
          thread.originalMessage.id
        );

        if (channelOriginalMessage) {
          channelOriginalMessage.thread = thread;
        }
      });
  }
}
