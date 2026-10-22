import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import Service, { service } from "@ember/service";

// The rich editor mounts asynchronously; a focus requested meanwhile is
// replayed when it registers. Only the latest request across composers is kept,
// matching the markdown editor, where the last focus call wins.
let pendingFocus = null;

export default class ChatComposerService extends Service {
  @service appEvents;
  @service capabilities;
  @service site;

  /** @type {import("discourse/lib/composer/text-manipulation").TextManipulation | null} */
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

  /**
   * @param {Object} [options]
   * @param {boolean} [options.ensureAtEnd] moves the caret to the end
   * @param {string} [options.addText] text typed while the editor wasn't focused
   */
  @action
  focus(options = {}) {
    const { editor } = this;

    if (!editor) {
      if (this.#awaitingEditor) {
        pendingFocus = { owner: this, options };
      }
      return;
    }

    if (this.capabilities.isIpadOS || this.site.mobileView) {
      return;
    }

    // inserted now to keep typed keys in order
    if (options.addText) {
      editor.insertTypedText(options.addText);
    }

    // Focusing fires the composer's focus handlers, which must not run inside
    // the render that mounted the editor.
    next(() => {
      if (options.ensureAtEnd) {
        editor.putCursorAtEnd();
      } else {
        editor.focus();
      }
    });
  }

  @action
  blur() {
    const element = this.editor?.element;
    next(() => element?.blur());
  }
}
