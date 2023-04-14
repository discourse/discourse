import MultiSelectComponent from "select-kit/components/multi-select";
import FormTemplate from "admin/models/form-template";
import { computed } from "@ember/object";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["form-template-chooser"],
  classNames: ["form-template-chooser"],
  selectKitOptions: {
    none: "admin.form_templates.edit_category.select_template",
  },

  init() {
    this._super(...arguments);

    if (!this.templates) {
      this._fetchTemplates();
    }
  },

  @computed("templates")
  get content() {
    if (!this.templates) {
      return this._fetchTemplates();
    }

    return this.templates;
  },

  _fetchTemplates() {
    FormTemplate.findAll().then((result) => {
      const sortedTemplates = this._sortTemplatesByName(result);
      if (sortedTemplates.length > 0) {
        return this.set("templates", sortedTemplates);
      } else {
        this.set("templates", sortedTemplates);
        this.set("selectKit.options.disabled", true);
      }
    });
  },

  _sortTemplatesByName(templates) {
    return templates.sort((a, b) => a.name.localeCompare(b.name));
  },
});
