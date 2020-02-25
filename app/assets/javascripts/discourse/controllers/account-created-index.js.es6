import Controller from "@ember/controller";
import { resendActivationEmail } from "discourse/lib/user-activation";

export default Controller.extend({
  actions: {
    sendActivationEmail() {
      resendActivationEmail(this.get("accountCreated.username")).then(() => {
        this.transitionToRoute("account-created.resent");
      });
    },
    editActivationEmail() {
      this.transitionToRoute("account-created.edit-email");
    }
  }
});
