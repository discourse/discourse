import Component from "@glimmer/component";
import Yaml from "js-yaml";
import { tracked } from "@glimmer/tracking";

export default class FormTemplateFieldWrapper extends Component {
  @tracked error = null;

  get canShowContent() {
    try {
      const parsedContent = Yaml.load(this.args.content);
      this.parsedContent = parsedContent;
      return true;
    } catch (e) {
      this.error = e;
    }
  }
}
