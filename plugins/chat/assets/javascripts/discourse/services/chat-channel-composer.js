import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import {
  requestComposerFocus,
  takeComposerFocusRequest,
} from "discourse/plugins/chat/discourse/lib/pending-composer-focus";

export default class ChatChannelComposer extends Service {
  @service chat;
  @service chatApi;
  @service currentUser;
  @service router;
  @service("chat-thread-composer") threadComposer;
  @service loadingSlider;
  @service appEvents;
  @service site;

  @tracked editor;
  @tracked scroller;

  init() {
    super.init(...arguments);
    this.appEvents.on("discourse:focus-changed", this, this.blur);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("discourse:focus-changed", this, this.blur);
  }

  registerEditor(editor) {
    this.editor = editor;

    const options = takeComposerFocusRequest(this);

    // never steal focus from a composer the user is already in
    if (
      options &&
      !document.activeElement?.classList.contains("chat-composer__input")
    ) {
      this.focus(options);
    }
  }

  unregisterEditor(editor) {
    if (this.editor === editor) {
      this.editor = null;
    }
  }

  @action
  focus(options = {}) {
    if (!this.editor) {
      requestComposerFocus(this, options);
      return;
    }

    this.editor.focus(options);
  }

  @action
  blur() {
    this.editor?.blur();
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

      try {
        await this.router.transitionTo(
          "chat.channel.thread",
          ...message.thread.routeModels
        );
      } catch (e) {
        if (e.name !== "TransitionAborted") {
          throw e;
        }
      }

      this.threadComposer.focus({ ensureAtEnd: true, refreshHeight: true });
    } else {
      message.channel.draft.inReplyTo = message;
      this.focus({ ensureAtEnd: true, refreshHeight: true });
    }
  }
}
