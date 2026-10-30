import { action } from "@ember/object";
import { service } from "@ember/service";
import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import ChatComposer from "../../chat-composer.gjs";

export default class ChatComposerPendingThread extends ChatComposer {
  // eslint-disable-next-line discourse/no-unused-services
  @service("chat-thread-composer") composer;
  @service currentUser;

  context = "thread";
  composerId = "pending-thread-composer";
  presenceChannelName = null;

  get disabled() {
    return (
      this.args.disabled ||
      this.pane.sending ||
      !this.chat.userCanInteractWithChat ||
      !this.args.channel.canModifyMessages(this.currentUser)
    );
  }

  get draft() {
    return this.args.draft;
  }

  get lastMessage() {
    return null;
  }

  get pane() {
    return this.args.pane;
  }

  get placeholder() {
    return this.args.placeholder;
  }

  handleEscape(event) {
    event.stopPropagation();
    event.target.blur();
  }

  lastUserMessage() {
    return null;
  }

  @action
  persistDraft() {
    this.args.onDraftChanged?.(this.draft);
  }

  @action
  resetDraft() {
    this.args.onResetDraft?.();
  }

  @action
  sendPickedGif(message) {
    if (this.inProgressUploadsCount) {
      this.draft.message = [this.draft.message, message]
        .filter(Boolean)
        .join("\n");
      this.persistDraft();
      return;
    }
    return this.args.onSendMessage(
      ChatMessage.createDraftMessage(this.args.channel, {
        user: this.currentUser,
        message,
      })
    );
  }
}
