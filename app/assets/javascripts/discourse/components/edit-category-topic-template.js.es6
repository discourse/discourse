import { buildCategoryPanel } from "discourse/components/edit-category-panel";

export default buildCategoryPanel("topic-template", {
  _activeTabChanged: function() {
    if (this.get("activeTab")) {
      Ember.run.scheduleOnce("afterRender", () =>
        this.$(".d-editor-input").focus()
      );
    }
  }.observes("activeTab")
});
