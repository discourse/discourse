import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { inject as service } from "@ember/service";

export default class ChatChannelEditDescriptionController extends Controller.extend(
  ModalFunctionality
) {
  @service chatApi;
  editedDescription = "";

  @computed("model.description", "editedDescription")
  get isSaveDisabled() {
    return (
      this.model.description === this.editedDescription ||
      this.editedDescription?.length > 280
    );
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
    this.set("editedDescription", description);
  }
}
