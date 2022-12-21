import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { inject as service } from "@ember/service";
export default class ChatChannelEditTitleController extends Controller.extend(
  ModalFunctionality
) {
  @service chatApi;
  editedTitle = "";

  @computed("model.title", "editedTitle")
  get isSaveDisabled() {
    return (
      this.model.title === this.editedTitle ||
      this.editedTitle?.length > this.siteSettings.max_topic_title_length
    );
  }

  onShow() {
    this.set("editedTitle", this.model.title || "");
  }

  onClose() {
    this.set("editedTitle", "");
    this.clearFlash();
  }

  @action
  onSaveChatChannelTitle() {
    return this.chatApi
      .updateChannel(this.model.id, {
        name: this.editedTitle,
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

  @action
  onChangeChatChannelTitle(title) {
    this.clearFlash();
    this.set("editedTitle", title);
  }
}
