import ChatComposer from "./chat-composer";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { action } from "@ember/object";

export default class ChatChannelThreadComposer extends ChatComposer {
  @action
  reset(channel, thread) {
    this.message = ChatMessage.createDraftMessage(channel, {
      user: this.currentUser,
    });
    this.message.thread = thread;
  }

  @action
  replyTo(message) {
    console.log("reply to", message);
    this.chat.activeMessage = null;
    this.message.thread = message.thread;
    this.message.inReplyTo = message;
  }
}
