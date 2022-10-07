import I18n from "I18n";
import Mixin from "@ember/object/mixin";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { Promise } from "rsvp";
import { extractError } from "discourse/lib/ajax-error";
import { next } from "@ember/runloop";
import { inject as service } from "@ember/service";

export default Mixin.create(ModalFunctionality, {
  dialog: service(),
  errorMessage: null,
  reason: null,
  message: null,
  postEdit: null,
  postAction: null,
  user: null,
  postId: null,
  successCallback: null,
  confirmClose: false,

  resetModal() {
    this.setProperties({
      errorMessage: null,
      reason: null,
      message: null,
      loadingUser: true,
      postId: null,
      postEdit: null,
      postAction: "delete",
      before: null,
      successCallback: null,
      confirmClose: false,
    });
  },

  beforeClose() {
    // prompt a confirmation if we have unsaved content
    if (
      !this.confirmClose &&
      ((this.reason && this.reason.length > 1) ||
        (this.message && this.message.length > 1))
    ) {
      this.send("hideModal");
      this.dialog.confirm({
        message: I18n.t("admin.user.confirm_cancel_penalty"),
        didConfirm: () => {
          next(() => {
            this.set("confirmClose", true);
            this.send("closeModal");
          });
        },
        didCancel: () => this.send("reopenModal"),
      });
      return false;
    }
  },

  penalize(cb) {
    let before = this.before;
    let promise = before ? before() : Promise.resolve();

    return promise
      .then(() => cb())
      .then((result) => {
        this.set("confirmClose", true);
        this.send("closeModal");
        let callback = this.successCallback;
        if (callback) {
          callback(result);
        }
      })
      .catch((error) => {
        this.set("errorMessage", extractError(error));
      });
  },
});
