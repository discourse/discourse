import Controller from "@ember/controller";
import { action } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { inject as service } from "@ember/service";
import ChatModalEditChannelDescription from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-description";
import ChatModalEditChannelName from "discourse/plugins/chat/discourse/components/chat/modal/edit-channel-name";

export default class ChatChannelInfoAboutController extends Controller.extend(
  ModalFunctionality
) {
  @service modal;

  @action
  onEditChatChannelName() {
    return this.modal.show(ChatModalEditChannelName, {
      model: this.model,
    });
  }

  @action
  onEditChatChannelDescription() {
    return this.modal.show(ChatModalEditChannelDescription, {
      model: this.model,
    });
  }
}
