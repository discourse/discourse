import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default class SidebarCategoriesForm extends Controller.extend(
  ModalFunctionality
) {}
