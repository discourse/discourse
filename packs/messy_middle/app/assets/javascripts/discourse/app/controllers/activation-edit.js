import Controller, { inject as controller } from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { changeEmail } from "discourse/lib/user-activation";
import discourseComputed from "discourse-common/utils/decorators";
import { flashAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
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
        .catch(flashAjaxError(this));
    },
  },
});
