import Component from "@ember/component";
import { computed } from "@ember/object";
import { bind } from "@ember/runloop";

export default Component.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-body",
  classNames: ["select-kit-body"],
  attributeBindings: ["selectKitId:data-select-kit-id"],
  selectKitId: computed("selectKit.uniqueID", function() {
    return `${this.selectKit.uniqueID}-body`;
  }),
  rootEventType: "click",

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
  }
});
