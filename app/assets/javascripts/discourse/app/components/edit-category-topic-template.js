import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import { observes } from "discourse-common/utils/decorators";
import { schedule } from "@ember/runloop";
import FormTemplate from "admin/models/form-template";
import I18n from "I18n";
import { action, computed } from "@ember/object";
import Yaml from "js-yaml";

export default buildCategoryPanel("topic-template", {
  // Modals are defined using the singleton pattern.
  // Opening the insert link modal will destroy the edit category modal.
  showInsertLinkButton: false,

  init() {
    this._super(...arguments);

    FormTemplate.findAll().then((result) => {
      const sortedTemplates = this._sortTemplatesByName([
        this.freeformTemplate,
        ...result,
      ]);

      this.set("templates", sortedTemplates);
    });
  },

  @computed("category.form_template")
  get selectedTemplate() {
    if (this.category.form_template) {
      return JSON.parse(this.category.form_template).name;
    }

    return this.freeformTemplate.name;
  },

  @computed("selectedTemplate")
  get templateContent() {
    if (this.templates) {
      return this.templates.findBy("name", this.selectedTemplate).template;
    }

    return Yaml.dump(JSON.parse(this.category.form_template).template);
  },

  get freeformTemplate() {
    return {
      id: 0,
      name: I18n.t("admin.form_templates.template_chooser.freeform"),
      template: "",
    };
  },

  _sortTemplatesByName(templates) {
    return templates.sort((a, b) => a.name.localeCompare(b.name));
  },

  @observes("activeTab")
  _activeTabChanged() {
    if (this.activeTab) {
      schedule("afterRender", () =>
        this.element.querySelector(".d-editor-input").focus()
      );
    }
  },

  @action
  changeTemplate(templateName) {
    if (templateName === this.freeformTemplate.name) {
      return this.set("category.form_template", null);
    }

    const template = this.templates.findBy("name", templateName);

    const parsedTemplate = {
      name: template.name,
      template: Yaml.load(template.template),
    };

    return this.set("category.form_template", JSON.stringify(parsedTemplate));
  },
});
