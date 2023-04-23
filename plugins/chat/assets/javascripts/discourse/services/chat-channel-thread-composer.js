import ChatChannelComposer from "./chat-channel-composer";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { action } from "@ember/object";

export default class extends ChatChannelComposer {
  get model() {
    return this.chat.activeChannel.activeThread;
  }

  @action
  reset() {
    this.message = ChatMessage.createDraftMessage(this.chat.activeChannel, {
      user: this.currentUser,
      thread_id: this.model.id,
    });
  }

  _persistDraft() {
    // eslint-disable-next-line no-console
    console.debug(
      "Drafts are unsupported for chat threads at this point in time"
    );
    return;
  }
}
