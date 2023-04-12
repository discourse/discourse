import Service, { inject as service } from "@ember/service";
import { bind } from "discourse-common/utils/decorators";

export default class ChatChannelThreadIndicatorSubscriptionsManager extends Service {
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
      case "update_thread_indicator":
        this.handleThreadIndicatorUpdate(busData);
        break;
    }
  }

  handleThreadIndicatorUpdate(data) {
    const message = this.messagesManager.findMessage(data.original_message_id);
    if (message) {
      if (data.action === "increment_reply_count") {
        // TODO (martin) In future we should use a replies_count delivered from the server.
        message.threadReplyCount += 1;
      }
    }
  }
}
