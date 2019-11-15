import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { resendActivationEmail } from "discourse/lib/user-activation";

export default Controller.extend(ModalFunctionality, {
  actions: {
    sendActivationEmail() {
      resendActivationEmail(this.username).then(() => {
        const modal = this.showModal("activation-resent", { title: "log_in" });
        modal.set("currentEmail", this.currentEmail);
      });
    },

    editActivationEmail() {
      const modal = this.showModal("activation-edit", {
        title: "login.change_email"
      });

      const currentEmail = this.currentEmail;
      modal.set("currentEmail", currentEmail);
      modal.set("newEmail", currentEmail);
    }
  }
});
