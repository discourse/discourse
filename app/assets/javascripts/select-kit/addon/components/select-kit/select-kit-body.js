import Component from "@ember/component";
import { bind } from "discourse-common/utils/decorators";
import { next } from "@ember/runloop";
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
    document.addEventListener("click", this.handleClick, true);
    this.selectKit
      .mainElement()
      .addEventListener("keydown", this._handleKeydown, true);
  },

  willDestroyElement() {
    this._super(...arguments);
    document.removeEventListener("click", this.handleClick, true);
    this.selectKit
      .mainElement()
      ?.removeEventListener("keydown", this._handleKeydown, true);
  },

  @bind
  handleClick(event) {
    if (!this.selectKit.isExpanded || !this.selectKit.mainElement()) {
      return;
    }

    if (this.selectKit.mainElement().contains(event.target)) {
      return;
    }

    this.selectKit.close(event);
  },

  @bind
  _handleKeydown(event) {
    if (!this.selectKit.isExpanded || event.key !== "Tab") {
      return;
    }

    next(() => {
      if (
        this.isDestroying ||
        this.isDestroyed ||
        this.selectKit.mainElement()?.contains(document.activeElement)
      ) {
        return;
      }

      this.selectKit.close(event);
    });
  },
});
