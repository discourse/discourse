import Component from "@ember/component";
import {
  openLinkInNewTab,
  shouldOpenInNewTab,
} from "discourse/lib/click-track";

export default Component.extend({
  didInsertElement() {
    this._super(...arguments);
    $(this.element).on("click.discourse-open-tab", "a", (event) => {
      if (event.target && event.target.tagName === "A") {
        if (shouldOpenInNewTab(event.target.href)) {
          openLinkInNewTab(event.target);
        }
      }
    });
  },

  willDestroyElement() {
    this._super(...arguments);
    $(this.element).off("click.discourse-open-tab", "a");
  },
});
