import MultiSelectComponent from "select-kit/components/multi-select";
import FormTemplate from "discourse/models/form-template";
import { computed } from "@ember/object";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["form-template-chooser"],
  classNames: ["form-template-chooser"],
  selectKitOptions: {
    none: "form_template_chooser.select_template",
  },

  init() {
    this._super(...arguments);

    if (!this.templates) {
      this._fetchTemplates();
    }
  },

  didUpdateAttrs() {
    this._super(...arguments);
    this._fetchTemplates();
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
      let sortedTemplates = this._sortTemplatesByName(result);

      if (this.filteredIds) {
        sortedTemplates = sortedTemplates.filter((t) =>
          this.filteredIds.includes(t.id)
        );
      }

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
