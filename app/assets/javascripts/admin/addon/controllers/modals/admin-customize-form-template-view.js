import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
export default class AdminCustomizeFormTemplateView extends Controller.extend(
  ModalFunctionality
) {
  @action
  editTemplate() {
    // TODO send to edit action
  }

  @action
  deleteTemplate() {
    // TODO send to edit action
  }
}
