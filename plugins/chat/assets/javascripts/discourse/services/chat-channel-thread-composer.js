import ChatChannelComposer from "./chat-channel-composer";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { action } from "@ember/object";

export default class extends ChatChannelComposer {
  @action
  reset(channel) {
    this.message = ChatMessage.createDraftMessage(channel, {
      user: this.currentUser,
      thread_id: channel.activeThread.id,
    });
  }
}
