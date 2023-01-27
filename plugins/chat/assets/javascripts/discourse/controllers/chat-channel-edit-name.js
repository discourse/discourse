import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class ChatChannelEditTitleController extends Controller.extend(
  ModalFunctionality
) {
  @service chatApi;
  @tracked editedTitle = this.model.title || "";
  onChangeChatChannelTitle = (newTitle) => (this.editedTitle = newTitle);

  @computed("model.title", "editedName")
  get isSaveDisabled() {
    return (
      this.model.title === this.editedName ||
      this.editedName?.length > this.siteSettings.max_topic_title_length
    );
  }

  onShow() {
    this.set("editedName", this.model.title || "");
  }

  onClose() {
    this.set("editedName", "");
    this.clearFlash();
  }

  @action
  onSaveChatChannelName() {
    return this.chatApi
      .updateChannel(this.model.id, {
        name: this.editedName,
      })
      .then((result) => {
        this.model.set("title", result.channel.title);
        this.send("closeModal");
      })
      .catch((event) => {
        if (event.jqXHR?.responseJSON?.errors) {
          this.flash(event.jqXHR.responseJSON.errors.join("\n"), "error");
        }
      });
  }
}
