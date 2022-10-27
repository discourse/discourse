import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import ChatApi from "discourse/plugins/chat/discourse/lib/chat-api";

export default class ChatChannelEditTitleController extends Controller.extend(
  ModalFunctionality
) {
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
    return ChatApi.modifyChatChannel(this.model.id, {
      name: this.editedTitle,
    })
      .then((chatChannel) => {
        this.model.set("title", chatChannel.title);
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
