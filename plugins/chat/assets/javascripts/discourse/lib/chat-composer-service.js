import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";

// The rich editor mounts asynchronously; a focus requested meanwhile is
// replayed when it registers. Only the latest request across composers is kept,
// matching the markdown editor, where the last focus call wins.
let pendingFocus = null;

export default class ChatComposerService extends Service {
  @service appEvents;

  @tracked editor;
  @tracked scroller;

  #awaitingEditor = false;

  init() {
    super.init(...arguments);
    this.appEvents.on("discourse:focus-changed", this, this.blur);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("discourse:focus-changed", this, this.blur);
  }

  /**
   * Marks the composer as mounted but still loading its editor, so focus
   * requests are kept for it instead of being dropped.
   */
  awaitEditor() {
    this.#awaitingEditor = true;
  }

  stopAwaitingEditor() {
    this.#awaitingEditor = false;

    if (pendingFocus?.owner === this) {
      pendingFocus = null;
    }
  }

  registerEditor(editor) {
    this.editor = editor;
    this.#awaitingEditor = false;

    const request = pendingFocus?.owner === this ? pendingFocus : null;
    if (!request) {
      return;
    }

    pendingFocus = null;

    // never steal focus from a composer the user is already in
    if (!document.activeElement?.classList.contains("chat-composer__input")) {
      this.focus(request.options);
    }
  }

  unregisterEditor(editor) {
    if (this.editor === editor) {
      this.editor = null;
    }
  }

  @action
  focus(options = {}) {
    if (this.editor) {
      this.editor.focus(options);
    } else if (this.#awaitingEditor) {
      pendingFocus = { owner: this, options };
    }
  }

  @action
  blur() {
    this.editor?.blur();
  }
}
