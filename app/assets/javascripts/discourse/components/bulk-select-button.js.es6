import showModal from "discourse/lib/show-modal";

export default Ember.Component.extend({
  classNames: ["bulk-select-container"],

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
