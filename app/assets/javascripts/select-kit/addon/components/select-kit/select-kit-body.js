import Component from "@ember/component";
import { bind } from "@ember/runloop";
import { computed } from "@ember/object";

export default Component.extend({
  classNames: ["select-kit-body"],
  classNameBindings: ["emptyBody:empty-body"],

  emptyBody: computed("selectKit.{filter,hasNoContent}", function () {
    return false;
  }),

  rootEventType: "click",

  init() {
    this._super(...arguments);

    this.handleRootMouseDownHandler = bind(this, this.handleRootMouseDown);
  },

  didInsertElement() {
    this._super(...arguments);

    this.element.style.position = "relative";

    document.addEventListener(
      this.rootEventType,
      this.handleRootMouseDownHandler,
      true
    );
  },

  willDestroyElement() {
    this._super(...arguments);

    document.removeEventListener(
      this.rootEventType,
      this.handleRootMouseDownHandler,
      true
    );
  },

  handleRootMouseDown(event) {
    if (!this.selectKit.isExpanded) {
      return;
    }

    const headerElement = document.querySelector(
      `#${this.selectKit.uniqueID}-header`
    );

    if (headerElement && headerElement.contains(event.target)) {
      return;
    }

    if (this.element.contains(event.target)) {
      return;
    }

    if (this.selectKit.mainElement()) {
      this.selectKit.close(event);
    }
  },
});
