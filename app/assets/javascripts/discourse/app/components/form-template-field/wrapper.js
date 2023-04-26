import Component from "@glimmer/component";
import Yaml from "js-yaml";
import { tracked } from "@glimmer/tracking";
import FormTemplate from "discourse/models/form-template";

export default class FormTemplateFieldWrapper extends Component {
  @tracked error = null;
  @tracked parsedTemplate = null;

  constructor() {
    super(...arguments);

    // TODO: move this outside the constructor so it can be called
    // when switching categories as well
    FormTemplate.findById(this.args.ids).then((ft) => {
      try {
        this.parsedTemplate = Yaml.load(ft.form_template.template);
      } catch (e) {
        this.error = e;
      }
    });
  }
}
