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
    this.appEvents.on(
      "composer:selected-form-template",
      this,
      this._fetchTemplate
    );

    if (this.args.content) {
      this._loadTemplate(this.args.content);
    } else if (this.args.id) {
      this.appEvents.trigger("composer:selected-form-templates", this.args.id);
    }
  }

  willDestroy() {
    this.appEvents.off(
      "composer:selected-form-templates",
      this,
      this._fetchTemplate
    );
  }

  _loadTemplate(templateContent) {
    try {
      this.parsedTemplate = Yaml.load(templateContent);
    } catch (e) {
      this.error = e;
    }
  }

  async _fetchTemplate(id) {
    const response = await FormTemplate.findById(id);
    const templateContent = await response.form_template.template;
    return this._loadTemplate(templateContent);
  }
}
