import Service from "@ember/service";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
export default class ChatDraftsManager extends Service {
  drafts = {};

  add(message) {
    if (message instanceof ChatMessage) {
      this.drafts[message.channel.id] = message;
    } else {
      throw new Error("message must be an instance of ChatMessage");
    }
  }

  get({ channelId }) {
    return this.drafts[channelId];
  }

  remove({ channelId }) {
    delete this.drafts[channelId];
  }

  reset() {
    this.drafts = {};
  }
}
