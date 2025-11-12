import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { changeEmail } from "discourse/lib/user-activation";

export default class AccountCreatedEditEmailController extends Controller {
  @service router;

  accountCreated;
  newEmail;

  @discourseComputed("newEmail", "accountCreated.email")
  submitDisabled(newEmail, currentEmail) {
    return newEmail === currentEmail;
  }

  @action
  updateNewEmail(email) {
    this.set("newEmail", email);
  }

  @action
  async changeEmail() {
    try {
      await changeEmail({ email: this.newEmail });

      this.set("accountCreated.email", this.newEmail);
      this.router.transitionTo("account-created.resent");
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  cancel() {
    this.router.transitionTo("account-created.index");
  }
}
