import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Yaml from "js-yaml";

export default class AdminFormTemplateValidationOptions extends Controller.extend(
  ModalFunctionality
) {
  get yaml() {
    return Yaml.load(this.model.content);
  }
}
