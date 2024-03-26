import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { disableBodyScroll } from "discourse/lib/body-scroll-lock";

export default class ChatThreadComposer extends Service {
  @service chat;
  @service capabilities;

  @tracked textarea;
  @tracked scrollable;

  @action
  focus(options = {}) {
    this.textarea?.focus(options);

    schedule("afterRender", () => {
      if (!this.capabilities.isIpadOS && this.capabilities.isIOS) {
        disableBodyScroll(this.scrollable);
      }
    });
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
