import { buildCategoryPanel } from "discourse/components/edit-category-panel";

export default buildCategoryPanel("topic-template", {
  _activeTabChanged: function() {
    if (this.activeTab) {
      Ember.run.scheduleOnce("afterRender", () =>
        this.element.querySelector(".d-editor-input").focus()
      );
    }
  }.observes("activeTab")
});
