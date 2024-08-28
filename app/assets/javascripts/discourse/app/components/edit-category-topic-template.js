import { action, computed } from "@ember/object";
import { schedule } from "@ember/runloop";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import discourseComputed, { observes } from "discourse-common/utils/decorators";

export default class EditCategoryTopicTemplate extends buildCategoryPanel(
  "topic-template"
) {
  @computed("category.form_template_ids")
  get showFormTemplate() {
    return Boolean(this.category.form_template_ids.length);
  }

  set showFormTemplate(value) {
    // noop
  }

  @discourseComputed("showFormTemplate")
  templateTypeToggleLabel(showFormTemplate) {
    if (showFormTemplate) {
      return "admin.form_templates.edit_category.toggle_form_template";
    }

    return "admin.form_templates.edit_category.toggle_freeform";
  }

  @action
  toggleTemplateType() {
    this.toggleProperty("showFormTemplate");

    if (!this.showFormTemplate) {
      // Clear associated form templates if switching to freeform
      this.set("category.form_template_ids", []);
    }
  }

  @observes("activeTab", "showFormTemplate")
  _activeTabChanged() {
    if (this.activeTab && !this.showFormTemplate) {
      schedule("afterRender", () =>
        this.element.querySelector(".d-editor-input").focus()
      );
    }
  }
}
