import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { disableBodyScroll } from "discourse/lib/body-scroll-lock";

export default class ChatThreadComposer extends Service {
  @service chat;
  @service capabilities;
  @service appEvents;
  @service site;

  @tracked textarea;
  @tracked scroller;

  init() {
    super.init(...arguments);
    this.appEvents.on("discourse:focus-changed", this, this.blur);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("discourse:focus-changed", this, this.blur);
  }

  @action
  focus(options = {}) {
    this.textarea?.focus(options);

    schedule("afterRender", () => {
      if (this.capabilities.isIOS && !this.capabilities.isIpadOS) {
        disableBodyScroll(this.scroller, { reverse: true });
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

    if (this.site.desktopView) {
      this.focus({ refreshHeight: true, ensureAtEnd: true });
    }
  }

  @action
  replyTo() {
    this.chat.activeMessage = null;
  }
}
