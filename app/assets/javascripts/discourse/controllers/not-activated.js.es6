import ModalFunctionality from "discourse/mixins/modal-functionality";
import { resendActivationEmail } from "discourse/lib/user-activation";

export default Ember.Controller.extend(ModalFunctionality, {
  actions: {
    sendActivationEmail() {
      resendActivationEmail(this.get("username")).then(() => {
        const modal = this.showModal("activation-resent", { title: "log_in" });
        modal.set("currentEmail", this.get("currentEmail"));
      });
    },

    editActivationEmail() {
      const modal = this.showModal("activation-edit", {
        title: "login.change_email"
      });

      const currentEmail = this.get("currentEmail");
      modal.set("currentEmail", currentEmail);
      modal.set("newEmail", currentEmail);
    }
  }
});
