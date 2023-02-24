import { inject as controller } from "@ember/controller";
import Modal from "discourse/controllers/modal";
import { changeEmail } from "discourse/lib/user-activation";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";

export default Modal.extend({
  login: controller(),

  currentEmail: null,
  newEmail: null,
  password: null,

  @discourseComputed("newEmail", "currentEmail")
  submitDisabled(newEmail, currentEmail) {
    return newEmail === currentEmail;
  },

  actions: {
    changeEmail() {
      const login = this.login;

      changeEmail({
        username: login.get("loginName"),
        password: login.get("loginPassword"),
        email: this.newEmail,
      })
        .then(() => {
          const modal = this.showModal("activation-resent", {
            title: "log_in",
          });
          modal.set("currentEmail", this.newEmail);
        })
        .catch((err) => this.flash(extractError(err), "error"));
    },
  },
});
