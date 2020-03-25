import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  classNames: ["bulk-select-container"],

  didInsertElement() {
    this._super(...arguments);

    schedule("afterRender", () => {
      let mainOutletPadding =
        window.getComputedStyle(document.querySelector("#main-outlet"))
          .paddingTop || 0;

      document.querySelector(
        ".bulk-select-container"
      ).style.top = mainOutletPadding;
    });
  },

  actions: {
    showBulkActions() {
      const controller = showModal("topic-bulk-actions", {
        model: {
          topics: this.selected,
          category: this.category
        },
        title: "topics.bulk.actions"
      });

      const action = this.action;
      if (action) {
        controller.set("refreshClosure", () => action());
      }
    }
  }
});
