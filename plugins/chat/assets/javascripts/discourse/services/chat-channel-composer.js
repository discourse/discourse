import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { disableBodyScroll } from "discourse/lib/body-scroll-lock";

export default class ChatChannelComposer extends Service {
  @service chat;
  @service chatApi;
  @service currentUser;
  @service router;
  @service("chat-thread-composer") threadComposer;
  @service loadingSlider;
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
    message.channel.draft = message;

    if (this.site.desktopView) {
      this.focus({ refreshHeight: true, ensureAtEnd: true });
    }
  }

  @action
  async replyTo(message) {
    this.chat.activeMessage = null;

    if (message.channel.threadingEnabled) {
      if (!message.thread?.id) {
        try {
          this.loadingSlider.transitionStarted();
          const threadObject = await this.chatApi.createThread(
            message.channel.id,
            message.id
          );
          message.thread = message.channel.threadsManager.add(
            message.channel,
            threadObject
          );
        } finally {
          this.loadingSlider.transitionEnded();
        }
      }

      message.channel.resetDraft(this.currentUser);

      await this.router.transitionTo(
        "chat.channel.thread",
        ...message.thread.routeModels
      );

      this.threadComposer.focus({ ensureAtEnd: true, refreshHeight: true });
    } else {
      message.channel.draft.inReplyTo = message;
      this.focus({ ensureAtEnd: true, refreshHeight: true });
    }
  }
}
