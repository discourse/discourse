import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import bootbox from "bootbox";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend(ModalFunctionality, {
  userStatusService: service("user-status"),

  emoji: null,
  description: null,
  showDeleteButton: false,

  onShow() {
    const status = this.currentUser.status;
    this.setProperties({
      emoji: status?.emoji,
      description: status?.description,
      showDeleteButton: !!status,
    });
  },

  @discourseComputed("emoji", "description")
  statusIsSet(emoji, description) {
    return !!emoji && !!description;
  },

  @action
  delete() {
    this.userStatusService
      .clear()
      .then(() => this.send("closeModal"))
      .catch((e) => this._handleError(e));
  },

  @action
  saveAndClose() {
    const status = { description: this.description, emoji: this.emoji };
    this.userStatusService
      .set(status)
      .then(() => {
        this.send("closeModal");
      })
      .catch((e) => this._handleError(e));
  },

  _handleError(e) {
    if (typeof e === "string") {
      bootbox.alert(e);
    } else {
      popupAjaxError(e);
    }
  },
});
