import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Yaml from "js-yaml";
import { tracked } from "@glimmer/tracking";

export default class AdminFormTemplateValidationOptions extends Controller.extend(
  ModalFunctionality
) {
  @tracked error = null;

  get canShowPreview() {
    try {
      const parsedContent = Yaml.load(this.model.content);
      this.parsedContent = parsedContent;
      return true;
    } catch (e) {
      this.error = e;
    }
  }
}
