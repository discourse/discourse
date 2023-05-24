import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default class ChatThreadSettingsModalController extends Controller.extend(
  ModalFunctionality
) {
  thread = null;
}
