import { action } from "@ember/object";
import Modal from "discourse/controllers/modal";
import showModal from "discourse/lib/show-modal";

export default class ChatChannelInfoAboutController extends Modal {
  @action
  onEditChatChannelName() {
    showModal("chat-channel-edit-name-slug", { model: this.model });
  }

  @action
  onEditChatChannelDescription() {
    showModal("chat-channel-edit-description", {
      model: this.model,
    });
  }
}
