import ChatMessage from "discourse/plugins/chat/discourse/models/chat-message";
import { action } from "@ember/object";
import Service, { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class ChatThreadComposer extends Service {
  @service chat;

  @tracked message;
  @tracked textarea;

  @action
  focus(options = {}) {
    this.textarea?.focus(options);
  }

  @action
  blur() {
    this.textarea?.blur();
  }

  @action
  reset(thread) {
    this.message = ChatMessage.createDraftMessage(thread.channel, {
      user: this.currentUser,
      thread,
    });
  }

  @action
  cancel() {
    if (this.message.editing) {
      this.reset(this.message.thread);
    } else if (this.message.inReplyTo) {
      this.message.inReplyTo = null;
    }
  }

  @action
  edit(message) {
    this.chat.activeMessage = null;
    message.editing = true;
    this.message = message;
    this.focus({ refreshHeight: true, ensureAtEnd: true });
  }

  @action
  replyTo() {
    this.chat.activeMessage = null;
  }
}
