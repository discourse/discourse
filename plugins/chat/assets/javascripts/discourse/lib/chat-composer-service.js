import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import Service, { service } from "@ember/service";

// The rich editor mounts asynchronously; a focus requested meanwhile is
// replayed when it registers. Only the latest request across composers is kept,
// matching the markdown editor, where the last focus call wins, but text typed
// meanwhile accumulates.
let pendingFocus = null;

export default class ChatComposerService extends Service {
  @service appEvents;

  @tracked editor;
  @tracked scroller;

  #awaitingEditorFor = null;

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
  awaitEditor(owner) {
    this.#awaitingEditorFor = owner;
  }

  // a composer replacing another starts awaiting before the old one tears down
  stopAwaitingEditor(owner) {
    if (this.#awaitingEditorFor !== owner) {
      return;
    }

    this.#awaitingEditorFor = null;

    if (pendingFocus?.owner === this) {
      pendingFocus = null;
    }
  }

  registerEditor(editor) {
    this.editor = editor;
    this.#awaitingEditorFor = null;

    const request = pendingFocus?.owner === this ? pendingFocus : null;
    if (!request) {
      return;
    }

    pendingFocus = null;

    // an editor registers before it loads the draft, and typed text replayed
    // into it then would replace the draft
    schedule("afterRender", () => {
      // never steal focus from a composer the user is already in
      if (
        this.editor === editor &&
        !document.activeElement?.classList.contains("chat-composer__input")
      ) {
        this.focus(request.options);
      }
    });
  }

  unregisterEditor(editor) {
    if (this.editor === editor) {
      this.editor = null;
    }
  }

  @action
  focus(options = {}) {
    // an outgoing composer's editor stays registered until it tears down
    if (this.editor?.element?.isConnected) {
      this.editor.focus(options);
    } else if (this.#awaitingEditorFor) {
      const pendingText =
        pendingFocus?.owner === this ? pendingFocus.options.addText : null;
      const addText = [pendingText, options.addText].filter(Boolean).join("");
      pendingFocus = {
        owner: this,
        options: { ...options, addText: addText || null },
      };
    }
  }

  @action
  blur() {
    this.editor?.blur();
  }
}
