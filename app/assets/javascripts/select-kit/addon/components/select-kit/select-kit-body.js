import Component from "@ember/component";
import { bind } from "discourse-common/utils/decorators";
import { computed } from "@ember/object";

export default Component.extend({
  classNames: ["select-kit-body"],
  classNameBindings: ["emptyBody:empty-body"],

  emptyBody: computed("selectKit.{filter,hasNoContent}", function () {
    return false;
  }),

  didInsertElement() {
    this._super(...arguments);
    this.element.style.position = "relative";
    this.selectKit
      .mainElement()
      .addEventListener("focusout", this._handleFocusOut, true);
  },

  willDestroyElement() {
    this._super(...arguments);
    this.selectKit
      .mainElement()
      .removeEventListener("focusout", this._handleFocusOut, true);
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
