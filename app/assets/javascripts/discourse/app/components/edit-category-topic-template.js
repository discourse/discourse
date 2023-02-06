import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import { observes } from "discourse-common/utils/decorators";
import { schedule } from "@ember/runloop";

export default buildCategoryPanel("topic-template", {
  // Modals are defined using the singleton pattern.
  // Opening the insert link modal will destroy the edit category modal.
  showInsertLinkButton: false,

  @observes("activeTab")
  _activeTabChanged() {
    if (this.activeTab) {
      schedule("afterRender", () =>
        this.element.querySelector(".d-editor-input").focus()
      );
    }
  },
});
