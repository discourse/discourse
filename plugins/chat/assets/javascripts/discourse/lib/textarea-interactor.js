import { registerDestructor } from "@ember/destroyable";
import EmberObject from "@ember/object";
import { setOwner } from "@ember/owner";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";

// Markdown editor counterpart of RichEditorInteractor: the chat composer and
// its services talk to either through this same surface.
export default class TextareaInteractor extends EmberObject {
  @service capabilities;
  @service site;

  textManipulation;

  constructor(owner, textManipulation) {
    super(...arguments);
    setOwner(this, owner);
    this.textManipulation = textManipulation;
    this.textarea = textManipulation.textarea;
    this.element = this.textarea;

    this.textarea.addEventListener("paste", this.textManipulation.paste);
    registerDestructor(this, (instance) => instance.teardown());
  }

  get value() {
    return this.textarea.value;
  }

  set value(value) {
    this.textarea.value = value;
    const event = new Event("input", {
      bubbles: true,
      cancelable: true,
    });
    this.textarea.dispatchEvent(event);
  }

  // Text manipulation writes straight to the textarea, so the draft only
  // learns about it through a synthetic input event.
  syncValue(value) {
    this.value = value;
  }

  // Captures where a partial `:term` sits before the emoji picker opens, since
  // closing the keyboard for it loses the caret.
  emojiTermContext() {
    const value = this.textarea.value;
    const caretPosition = this.textarea.selectionStart;

    if (!value || caretPosition === undefined) {
      return null;
    }

    const incompleteMatch = value
      .substring(0, caretPosition)
      .match(/(:[\p{L}\p{N}_-]+)$/u);

    if (!incompleteMatch) {
      return null;
    }

    return {
      emojiTermStart: caretPosition - incompleteMatch[1].length,
      emojiTermEnd: caretPosition - 1,
    };
  }

  insertEmoji(emoji, context) {
    if (context?.emojiTermStart == null) {
      this.emojiSelected(emoji);
      return;
    }

    const value = this.textarea.value;
    const valueUpToCursor = `${value.substring(0, context.emojiTermStart)}:${emoji}: `;
    const valueAfterCursor = value.substring(context.emojiTermEnd + 1);
    this.value = `${valueUpToCursor}${valueAfterCursor}`;
    this.textarea.setSelectionRange(
      valueUpToCursor.length,
      valueUpToCursor.length
    );
  }

  teardown() {
    this.textarea.removeEventListener("paste", this.textManipulation.paste);
  }

  @bind
  blur() {
    next(() => {
      this.textarea.blur();
    });
  }

  @bind
  focus(opts = { ensureAtEnd: false, refreshHeight: true, addText: null }) {
    next(() => {
      if (opts.refreshHeight) {
        this.refreshHeight();
      }

      if (opts.ensureAtEnd) {
        this.ensureCaretAtEnd();
      }

      if (this.capabilities.isIpadOS || this.site.mobileView) {
        return;
      }

      if (opts.addText) {
        this.textManipulation.addText(
          this.textManipulation.getSelected(),
          opts.addText
        );
      }

      this.textManipulation.blurAndFocus();
    });
  }

  @bind
  ensureCaretAtEnd() {
    schedule("afterRender", () => {
      this.textarea.setSelectionRange(
        this.textarea.value.length,
        this.textarea.value.length
      );
    });
  }

  @bind
  refreshHeight() {
    schedule("afterRender", () => {
      // this is a quirk which forces us to `auto` first or textarea
      // won't resize
      this.textarea.style.height = "auto";

      // +1 is to workaround a rounding error visible on electron
      // causing scrollbars to show when they shouldn’t
      this.textarea.style.height = this.textarea.scrollHeight + 1 + "px";
    });
  }

  @bind
  getSelected() {
    return this.textManipulation.getSelected(...arguments);
  }

  @bind
  applySurround() {
    return this.textManipulation.applySurround(...arguments);
  }

  @bind
  addText() {
    return this.textManipulation.addText(...arguments);
  }

  @bind
  applyLink() {
    return this.textManipulation.applyLink(...arguments);
  }

  emojiSelected(code) {
    this.textManipulation.emojiSelected(code);
  }
}
