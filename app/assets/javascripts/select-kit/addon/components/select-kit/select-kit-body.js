import Component from "@ember/component";
import { bind } from "discourse-common/utils/decorators";
import { computed } from "@ember/object";
import layout from "select-kit/templates/components/select-kit/select-kit-body";

export default Component.extend({
  layout,
  classNames: ["select-kit-body"],
  classNameBindings: ["emptyBody:empty-body"],

  emptyBody: computed("selectKit.{filter,hasNoContent}", function () {
    return false;
  }),

  didInsertElement() {
    this._super(...arguments);
    this.element.style.position = "relative";
    this.element.addEventListener("focusout", this._handleFocusOut, true);
  },

  willDestroyElement() {
    this._super(...arguments);
    this.element.removeEventListener("focusout", this._handleFocusOut, true);
  },

  @bind
  _handleFocusOut(event) {
    if (!this.selectKit.isExpanded) {
      return;
    }

    if (!this.selectKit.mainElement()) {
      return;
    }

    if (this.selectKit.mainElement().contains(event.relatedTarget)) {
      return;
    }

    // We have to use a custom flag for multi-selects to keep UI visible.
    // We can't rely on event.relatedTarget for these cases because,
    // when adding/removing items in a multi-select, the DOM element
    // has already been removed by this point, and therefore
    // event.relatedTarget is going to be null.
    if (this.selectKit.multiSelectInFocus) {
      this.selectKit.set("multiSelectInFocus", false);
      return;
    }

    this.selectKit.close(event);
  },
});
