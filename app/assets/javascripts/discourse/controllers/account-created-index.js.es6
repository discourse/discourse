import { resendActivationEmail } from "discourse/lib/user-activation";

export default Ember.Controller.extend({
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
