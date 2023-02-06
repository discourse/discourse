import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import { observes } from "discourse-common/utils/decorators";
import { schedule } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { computed } from "@ember/object";

export default buildCategoryPanel("topic-template", {
  // Modals are defined using the singleton pattern.
  // Opening the insert link modal will destroy the edit category modal.
  showInsertLinkButton: false,
  selectedTemplate: "Freeform",

  init() {
    this._super(...arguments);

    //TODO(keegan): Use an better approach to get templates listed here
    ajax(`/admin/customize/form-templates.json`).then((result) => {
      this.set("templates", [
        { id: 0, name: "Freeform" },
        ...result.form_templates,
      ]);
    });
  },

  @computed("selectedTemplate")
  get templateContents() {
    return this.templates.find(
      (template) => template.name === this.selectedTemplate
    ).template;
  },

  @observes("activeTab")
  _activeTabChanged() {
    if (this.activeTab) {
      schedule("afterRender", () =>
        this.element.querySelector(".d-editor-input").focus()
      );
    }
  },
});
