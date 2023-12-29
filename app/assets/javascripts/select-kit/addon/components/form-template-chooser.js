import { computed } from "@ember/object";
import FormTemplate from "discourse/models/form-template";
import MultiSelectComponent from "select-kit/components/multi-select";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["form-template-chooser"],
  classNames: ["form-template-chooser"],
  selectKitOptions: {
    none: "form_template_chooser.select_template",
  },

  init() {
    this._super(...arguments);
    this.triggerSearch();
  },

  didUpdateAttrs() {
    this._super(...arguments);
    this.set("templatesLoaded", false);
    this.triggerSearch();
  },

  @computed("templates")
  get content() {
    return this.templates;
  },

  search(filter) {
    if (this.get("templatesLoaded")) {
      return this._super(filter);
    } else {
      return this._fetchTemplates();
    }
  },

  async _fetchTemplates() {
    if (this.get("loadingTemplates")) {
      return;
    }

    this.set("templatesLoaded", false);
    this.set("loadingTemplates", true);

    const result = await FormTemplate.findAll();

    let sortedTemplates = this._sortTemplatesByName(result);

    if (this.filteredIds) {
      sortedTemplates = sortedTemplates.filter((t) =>
        this.filteredIds.includes(t.id)
      );
    }

    if (sortedTemplates.length === 0) {
      this.set("selectKit.options.disabled", true);
    }

    this.setProperties({
      templates: sortedTemplates,
      loadingTemplates: false,
      templatesLoaded: true,
    });

    return this.templates;
  },

  _sortTemplatesByName(templates) {
    return templates.sort((a, b) => a.name.localeCompare(b.name));
  },
});
