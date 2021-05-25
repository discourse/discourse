import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import { reads } from "@ember/object/computed";
import showModal from "discourse/lib/show-modal";

export default Component.extend({
  classNames: ["bulk-select-container"],

  didInsertElement() {
    this._super(...arguments);

    schedule("afterRender", () => {
      let headerHeight =
        document.querySelector(".d-header-wrap").offsetHeight || 0;

      document.querySelector(".bulk-select-container").style.top =
        headerHeight + 20 + "px";
    });
  },

  canDoBulkActions: reads("currentUser.staff"),

  actions: {
    showBulkActions() {
      const controller = showModal("topic-bulk-actions", {
        model: {
          topics: this.selected,
          category: this.category,
        },
        title: "topics.bulk.actions",
      });

      const action = this.action;
      if (action) {
        controller.set("refreshClosure", () => action());
      }
    },
  },
});
