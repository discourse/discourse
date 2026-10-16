import { setOwner } from "@ember/owner";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";

// Rich editor counterpart of TextareaInteractor: the chat composer and its
// services talk to either through this same surface.
export default class RichEditorInteractor {
  @service capabilities;
  @service site;

  textManipulation;

  constructor(owner, textManipulation) {
    setOwner(this, owner);
    this.textManipulation = textManipulation;
  }

  get element() {
    return this.textManipulation.view.dom;
  }

  get value() {
    return this.textManipulation.convertToMarkdown(
      this.textManipulation.view.state.doc
    );
  }

  // The editor is bound to the draft's markdown, so transactions already
  // report their serialized value; nothing to push back in.
  syncValue() {}

  refreshHeight() {}

  @bind
  blur() {
    next(() => {
      this.element.blur();
    });
  }

  @bind
  focus(opts = { ensureAtEnd: false, addText: null }) {
    if (this.capabilities.isIpadOS || this.site.mobileView) {
      return;
    }

    // Keys typed before the editor had focus arrive one per call, so they are
    // inserted right away to keep their order, and as plain text: parsed as
    // markdown, a lone `-` or `#` would become a list or heading.
    if (opts.addText) {
      const { view } = this.textManipulation;
      view.dispatch(view.state.tr.insertText(opts.addText));
    }

    // Focusing fires the composer's focus handlers, which must not run inside
    // the render that mounted the editor.
    next(() => {
      if (opts.ensureAtEnd) {
        this.textManipulation.putCursorAtEnd();
      }

      this.textManipulation.focus();
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

  // The document keeps the partial `:term` while the picker is open, so the
  // editor can find it on its own.
  emojiTermContext() {
    return null;
  }

  insertEmoji(emoji) {
    this.textManipulation.emojiSelected(emoji);
  }
}
