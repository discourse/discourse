import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import ChatApi from "discourse/plugins/chat/discourse/lib/chat-api";
import { tracked } from "@glimmer/tracking";

const DESCRIPTION_MAX_LENGTH = 280;

export default class ChatChannelEditDescriptionController extends Controller.extend(
  ModalFunctionality
) {
  @tracked editedDescription = "";

  @computed("model.description", "editedDescription")
  get isSaveDisabled() {
    return (
      this.model.description === this.editedDescription ||
      this.editedDescription?.length > DESCRIPTION_MAX_LENGTH
    );
  }

  get descriptionMaxLength() {
    return DESCRIPTION_MAX_LENGTH;
  }

  onShow() {
    this.set("editedDescription", this.model.description || "");
  }

  onClose() {
    this.set("editedDescription", "");
    this.clearFlash();
  }

  @action
  onSaveChatChannelDescription() {
    return ChatApi.modifyChatChannel(this.model.id, {
      description: this.editedDescription,
    })
      .then((chatChannel) => {
        this.model.set("description", chatChannel.description);
        this.send("closeModal");
      })
      .catch((event) => {
        if (event.jqXHR?.responseJSON?.errors) {
          this.flash(event.jqXHR.responseJSON.errors.join("\n"), "error");
        }
      });
  }

  @action
  onChangeChatChannelDescription(description) {
    this.clearFlash();
    this.set("editedDescription", description);
  }
}
