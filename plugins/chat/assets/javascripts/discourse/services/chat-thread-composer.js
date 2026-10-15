import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import {
  requestComposerFocus,
  takeComposerFocusRequest,
} from "discourse/plugins/chat/discourse/lib/pending-composer-focus";

export default class ChatThreadComposer extends Service {
  @service chat;
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
