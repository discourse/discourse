import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";
import { changeEmail } from "discourse/lib/user-activation";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  accountCreated: null,
  newEmail: null,

  @discourseComputed("newEmail", "accountCreated.email")
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
