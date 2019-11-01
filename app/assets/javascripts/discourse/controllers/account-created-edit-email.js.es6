import Controller from "@ember/controller";
import { changeEmail } from "discourse/lib/user-activation";
import computed from "ember-addons/ember-computed-decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  accountCreated: null,
  newEmail: null,

  @computed("newEmail", "accountCreated.email")
  submitDisabled(newEmail, currentEmail) {
    return newEmail === currentEmail;
  },

  actions: {
    changeEmail() {
      const email = this.newEmail;
      changeEmail({ email })
        .then(() => {
          this.set("accountCreated.email", email);
          this.transitionToRoute("account-created.resent");
        })
        .catch(popupAjaxError);
    },

    cancel() {
      this.transitionToRoute("account-created.index");
    }
  }
});
