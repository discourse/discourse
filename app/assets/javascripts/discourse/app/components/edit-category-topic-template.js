import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { schedule } from "@ember/runloop";
import FormTemplate from "admin/models/form-template";
import { action } from "@ember/object";
import { notEmpty } from "@ember/object/computed";

export default buildCategoryPanel("topic-template", {
  // Modals are defined using the singleton pattern.
  // Opening the insert link modal will destroy the edit category modal.
  showInsertLinkButton: false,
  showFormTemplate: notEmpty("category.form_template_ids"),

  init() {
    this._super(...arguments);

    FormTemplate.findAll().then((result) => {
      const sortedTemplates = this._sortTemplatesByName(result);
      this.set("templates", sortedTemplates);
    });
  },

  @discourseComputed("showFormTemplate")
  templateTypeToggleLabel(showFormTemplate) {
    if (showFormTemplate) {
      return "admin.form_templates.edit_category.toggle_form_template";
    }

    return "admin.form_templates.edit_category.toggle_freeform";
  },

  @action
  toggleTemplateType() {
    this.toggleProperty("showFormTemplate");

    if (!this.showFormTemplate) {
      // Clear associated form templates if switching to freeform
      this.set("category.form_template_ids", []);
    }
  },

  _sortTemplatesByName(templates) {
    return templates.sort((a, b) => a.name.localeCompare(b.name));
  },

  @observes("activeTab", "showFormTemplate")
  _activeTabChanged() {
    if (this.activeTab && !this.showFormTemplate) {
      schedule("afterRender", () =>
        this.element.querySelector(".d-editor-input").focus()
      );
    }
  },
});
