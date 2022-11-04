import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChatChannelToggleController extends Controller.extend(
  ModalFunctionality
) {
  @service chat;

  chatChannel = null;

  @action
  channelStatusChanged(channel) {
    this.send("closeModal");
    this.chat.openChannel(channel);
  }
}
