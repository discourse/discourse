import Component from "@ember/component";
import { bind } from "@ember/runloop";
import { computed } from "@ember/object";
import layout from "select-kit/templates/components/select-kit/select-kit-body";

export default Component.extend({
  layout,
  classNames: ["select-kit-body"],
  attributeBindings: ["role", "selectKitId:data-select-kit-id"],
  selectKitId: computed("selectKit.uniqueID", function () {
    return `${this.selectKit.uniqueID}-body`;
  }),
  rootEventType: "click",

  role: "listbox",

  init() {
    this._super(...arguments);

    this.handleRootMouseDownHandler = bind(this, this.handleRootMouseDown);
  },

  didInsertElement() {
    this._super(...arguments);

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
      `[data-select-kit-id=${this.selectKit.uniqueID}-header]`
    );

    if (headerElement && headerElement.contains(event.target)) {
      return;
    }

    if (this.element.contains(event.target)) {
      return;
    }

    this.selectKit.close(event);
  },
});
