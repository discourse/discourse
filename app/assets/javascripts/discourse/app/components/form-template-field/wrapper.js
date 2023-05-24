import Component from "@glimmer/component";
import Yaml from "js-yaml";
import { tracked } from "@glimmer/tracking";
import FormTemplate from "discourse/models/form-template";
import { inject as service } from "@ember/service";

export default class FormTemplateFieldWrapper extends Component {
  @service appEvents;
  @tracked error = null;
  @tracked parsedTemplate = null;

  constructor() {
    super(...arguments);
    this.appEvents.on("composer:load-templates", this, this._reloadTemplate);
    this.appEvents.trigger("composer:load-templates", this.args.ids);
  }

  willDestroy() {
    this.appEvents.off("composer:load-templates", this, this._reloadTemplate);
  }

  loadTemplate(templateContent) {
    try {
      this.parsedTemplate = Yaml.load(templateContent);
    } catch (e) {
      this.error = e;
    }
  }

  async _reloadTemplate(ids) {
    const response = await FormTemplate.findById(ids);
    const templateContent = await response.form_template.template;
    try {
      this.parsedTemplate = Yaml.load(templateContent);
    } catch (e) {
      this.error = e;
    }
  }
}
