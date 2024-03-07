import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";

export default class ChatThreadComposer extends Service {
  @service chat;

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
  edit(message) {
    this.chat.activeMessage = null;
    message.editing = true;
    message.thread.draft = message;
    this.focus({ refreshHeight: true, ensureAtEnd: true });
  }

  @action
  replyTo() {
    this.chat.activeMessage = null;
  }
}
