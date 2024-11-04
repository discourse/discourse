import { registerDestructor } from "@ember/destroyable";
import EmberObject from "@ember/object";
import { setOwner } from "@ember/owner";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import TextareaTextManipulation from "discourse/lib/textarea-text-manipulation";

// This class sole purpose is to provide a way to interact with the textarea
// using the existing TextareaTextManipulation mixin without using it directly
// in the composer component. It will make future migration easier.
export default class TextareaInteractor extends EmberObject {
  @service capabilities;
  @service site;
  @service siteSettings;

  textManipulation;

  constructor(owner, textarea) {
    super(...arguments);
    setOwner(this, owner);
    this.textarea = textarea;
    this.element = textarea;

    this.textManipulation = new TextareaTextManipulation(owner, {
      textarea,
      // we don't need app events
      eventPrefix: null,
    });

    // paste is using old native ember events defined on composer
    this.textarea.addEventListener("paste", this.textManipulation.paste);
    registerDestructor(this, (instance) => instance.teardown());
  }

  teardown() {
    this.textarea.removeEventListener("paste", this.textManipulation.paste);
  }

  set value(value) {
    this.textarea.value = value;
    const event = new Event("input", {
      bubbles: true,
      cancelable: true,
    });
    this.textarea.dispatchEvent(event);
  }

  blur() {
    next(() => {
      schedule("afterRender", () => {
        this.textarea.blur();
      });
    });
  }

  focus(opts = { ensureAtEnd: false, refreshHeight: true, addText: null }) {
    next(() => {
      schedule("afterRender", () => {
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
    });
  }

  ensureCaretAtEnd() {
    schedule("afterRender", () => {
      this.textarea.setSelectionRange(
        this.textarea.value.length,
        this.textarea.value.length
      );
    });
  }

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

  getSelected() {
    return this.textManipulation.getSelected(...arguments);
  }

  applySurround() {
    return this.textManipulation.applySurround(...arguments);
  }

  addText() {
    return this.textManipulation.addText(...arguments);
  }

  isInside() {
    return this.textManipulation.isInside(...arguments);
  }
}
