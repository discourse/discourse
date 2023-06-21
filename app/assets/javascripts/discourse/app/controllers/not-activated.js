import Component from "@ember/component";
import { action } from "@ember/object";
import { resendActivationEmail } from "discourse/lib/user-activation";

export default class NotActivated extends Component {
  @action
  sendActivationEmail() {
    resendActivationEmail(this.username).then(() => {
      const modal = this.showModal("activation-resent", { title: "log_in" });
      modal.set("currentEmail", this.currentEmail);
    });
  }

  @action
  editActivationEmail() {
    const modal = this.showModal("activation-edit", {
      title: "login.change_email",
    });

    const currentEmail = this.currentEmail;
    modal.set("currentEmail", currentEmail);
    modal.set("newEmail", currentEmail);
  }
}
