import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default class SidebarTagsForm extends Controller.extend(
  ModalFunctionality
) {}
