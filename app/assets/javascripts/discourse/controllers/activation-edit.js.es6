import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { extractError } from "discourse/lib/ajax-error";
import { changeEmail } from "discourse/lib/user-activation";

export default Controller.extend(ModalFunctionality, {
  login: inject(),

  currentEmail: null,
  newEmail: null,
  password: null,

  @computed("newEmail", "currentEmail")
  submitDisabled(newEmail, currentEmail) {
    return newEmail === currentEmail;
  },

  actions: {
    changeEmail() {
      const login = this.login;

      changeEmail({
        username: login.get("loginName"),
        password: login.get("loginPassword"),
        email: this.newEmail
      })
        .then(() => {
          const modal = this.showModal("activation-resent", {
            title: "log_in"
          });
          modal.set("currentEmail", this.newEmail);
        })
        .catch(err => this.flash(extractError(err), "error"));
    }
  }
});
