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
}
