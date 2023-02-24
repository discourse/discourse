import Modal from "discourse/controllers/modal";
import { resendActivationEmail } from "discourse/lib/user-activation";

export default Modal.extend({
  actions: {
    sendActivationEmail() {
      resendActivationEmail(this.username).then(() => {
        const modal = this.showModal("activation-resent", { title: "log_in" });
        modal.set("currentEmail", this.currentEmail);
      });
    },

    editActivationEmail() {
      const modal = this.showModal("activation-edit", {
        title: "login.change_email",
      });

      const currentEmail = this.currentEmail;
      modal.set("currentEmail", currentEmail);
      modal.set("newEmail", currentEmail);
    },
  },
});
