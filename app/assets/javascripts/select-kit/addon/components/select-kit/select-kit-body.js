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

  init() {
    this._super(...arguments);

    this.focusOutHandler = bind(this, this.handleFocusOut);
  },

  didInsertElement() {
    this._super(...arguments);
    this.element.style.position = "relative";
    this.element.addEventListener("focusout", this.focusOutHandler, true);
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

    // multi-selects need to keep the UI visible when adding/removing items
    // for these cases, we can't rely on event.relatedTarget
    // because the element may have already been removed from the DOM
    // so we cannot check if the element is contained within the main element
    if (this.selectKit.mainElement().classList.contains("multi-select")) {
      const hasClass = [
        "select-kit-row",
        "selected-choice",
        "filter-input",
      ].some((className) => event.target.classList.contains(className));

      if (hasClass) {
        return;
      }
    }

    this.selectKit.close(event);
  },
});
