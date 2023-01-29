import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default class ChatChannelArchiveModalController extends Controller.extend(
  ModalFunctionality
) {
  chatChannel = null;
}
