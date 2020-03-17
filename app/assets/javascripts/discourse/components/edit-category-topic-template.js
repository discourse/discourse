import { scheduleOnce } from "@ember/runloop";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import { observes } from "discourse-common/utils/decorators";

export default buildCategoryPanel("topic-template", {
  @observes("activeTab")
  _activeTabChanged: function() {
    if (this.activeTab) {
      scheduleOnce("afterRender", () =>
        this.element.querySelector(".d-editor-input").focus()
      );
    }
  }
});
