import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

const DESCRIPTION_MAX_LENGTH = 280;

export default class ChatChannelEditDescriptionController extends Controller.extend(
  ModalFunctionality
) {
  @service chatApi;
  @tracked editedDescription = this.model.description || "";

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

  onClose() {
    this.clearFlash();
  }

  @action
  onSaveChatChannelDescription() {
    return this.chatApi
      .updateChannel(this.model.id, {
        description: this.editedDescription,
      })
      .then((result) => {
        this.model.set("description", result.channel.description);
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
    this.editedDescription = description;
  }
}
