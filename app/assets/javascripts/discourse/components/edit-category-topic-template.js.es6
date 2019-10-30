import { scheduleOnce } from "@ember/runloop";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";

export default buildCategoryPanel("topic-template", {
  _activeTabChanged: function() {
    if (this.activeTab) {
      scheduleOnce("afterRender", () =>
        this.element.querySelector(".d-editor-input").focus()
      );
    }
  }.observes("activeTab")
});
