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
    this.appEvents.on("composer:load-templates", this, this._fetchTemplate);

    if (this.args.content) {
      this._loadTemplate(this.args.content);
    } else if (this.args.ids) {
      this.appEvents.trigger("composer:load-templates", this.args.ids);
    }
  }

  willDestroy() {
    this.appEvents.off("composer:load-templates", this, this._fetchTemplate);
  }

  _loadTemplate(templateContent) {
    try {
      this.parsedTemplate = Yaml.load(templateContent);
    } catch (e) {
      this.error = e;
    }
  }

  async _fetchTemplate(ids) {
    const response = await FormTemplate.findById(ids);
    const templateContent = await response.form_template.template;
    return this._loadTemplate(templateContent);
  }
}
