import ChatChannelComposer from "./chat-channel-composer";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { action } from "@ember/object";
import I18n from "I18n";

export default class extends ChatChannelComposer {
  get thread() {
    return this.channel.activeThread;
  }

  get placeholder() {
    return I18n.t("chat.placeholder_thread");
  }

  @action
  reset() {
    this.message = ChatMessage.createDraftMessage(this.channel, {
      user: this.currentUser,
      thread_id: this.thread.id,
    });
  }

  persistDraft() {
    // eslint-disable-next-line no-console
    console.debug(
      "Drafts are unsupported for chat threads at this point in time"
    );
    return;
  }
}
