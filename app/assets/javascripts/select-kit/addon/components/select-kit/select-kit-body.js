import Component from "@ember/component";
import { bind } from "@ember/runloop";
import { computed } from "@ember/object";
import layout from "select-kit/templates/components/select-kit/select-kit-body";

export default Component.extend({
  layout,
  classNames: ["select-kit-body"],
  classNameBindings: ["emptyBody:empty-body"],
  focusInMultiSelect: false,

  emptyBody: computed("selectKit.{filter,hasNoContent}", function () {
    return false;
  }),

  init() {
    this._super(...arguments);

    this.focusOutHandler = bind(this, this.handleFocusOut);
    this.focusInHandler = bind(this, this.handleFocusIn);
  },

  didInsertElement() {
    this._super(...arguments);
    this.element.style.position = "relative";
    this.element.addEventListener("focusout", this.focusOutHandler, true);
    this.element.addEventListener("focusin", this.focusInHandler, true);
  },

  willDestroyElement() {
    this._super(...arguments);
    this.element.removeEventListener("focusout", this.focusOutHandler, true);
  },

  handleFocusOut(event) {
    if (!this.selectKit.isExpanded) {
      return;
    }

    if (!this.selectKit.mainElement()) {
      return;
    }

    if (this.selectKit.mainElement().contains(event.relatedTarget)) {
      return;
    }

    // TODO: FIX THIS
    // multi-selects need to keep the UI visible when adding/removing items
    // for these cases, we can't rely on event.relatedTarget
    // because the element may have already been removed from the DOM
    // so we cannot check if the element is contained within the main element
    if (this.focusInMultiSelect) {
      this.focusInMultiSelect = false;
      return;
    }

    this.selectKit.close(event);
  },

  handleFocusIn(event) {
    if (this.selectKit.mainElement().classList.contains("multi-select")) {
      if (this.selectKit.mainElement().contains(event.relatedTarget)) {
        this.focusInMultiSelect = true;
      }
    }
  },
});
