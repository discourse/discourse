import Component from "@ember/component";
import { bind } from "@ember/runloop";
import { computed } from "@ember/object";
import layout from "select-kit/templates/components/select-kit/select-kit-body";

export default Component.extend({
  layout,
  classNames: ["select-kit-body"],
  classNameBindings: ["emptyBody:empty-body"],

  emptyBody: computed("selectKit.{filter,hasNoContent}", function () {
    return false;
  }),

  rootEventType: "focusout",

  init() {
    this._super(...arguments);

    this.handleRootFocusOutHandler = bind(this, this.handleRootFocusOut);
  },

  didInsertElement() {
    this._super(...arguments);

    this.element.style.position = "relative";

    this.element.addEventListener(
      this.rootEventType,
      this.handleRootFocusOutHandler,
      true
    );
  },

  willDestroyElement() {
    this._super(...arguments);

    this.element.removeEventListener(
      this.rootEventType,
      this.handleRootFocusOutHandler,
      true
    );
  },

  handleRootFocusOut(event) {
    if (!this.selectKit.isExpanded) {
      return;
    }

    if (!this.selectKit.mainElement()) {
      return;
    }

    if (this.selectKit.mainElement().contains(event.relatedTarget)) {
      return;
    }

    if (this.selectKit.mainElement()) {
      this.selectKit.close(event);
    }
  },
});
