import Component from "@glimmer/component";
import Yaml from "js-yaml";
import { tracked } from "@glimmer/tracking";
import FormTemplate from "discourse/models/form-template";
import { action } from "@ember/object";

export default class FormTemplateFieldWrapper extends Component {
  @tracked error = null;
  @tracked parsedTemplate = null;

  constructor() {
    super(...arguments);

    if (this.args.content) {
      // Content used when no id exists yet
      // (i.e. previewing while creating a new template)
      this._loadTemplate(this.args.content);
    } else if (this.args.id) {
      this._fetchTemplate(this.args.id);
    }
  }

  _loadTemplate(templateContent) {
    try {
      this.parsedTemplate = Yaml.load(templateContent);
    } catch (e) {
      this.error = e;
    }
  }

  @action
  refreshTemplate() {
    if (Array.isArray(this.args?.id) && this.args?.id.length === 0) {
      return;
    }

    return this._fetchTemplate(this.args.id);
  }

  async _fetchTemplate(id) {
    const response = await FormTemplate.findById(id);
    const templateContent = await response.form_template.template;
    return this._loadTemplate(templateContent);
  }
}
