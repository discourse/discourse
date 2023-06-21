import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { changeEmail } from "discourse/lib/user-activation";
import { flashAjaxError } from "discourse/lib/ajax-error";
import ActivationResent from "discourse/components/modal/activation-resent";

export default class ActivationEdit extends Component {
  @service login;

  @tracked currentEmail;
  @tracked newEmail;

  get submitDisabled() {
    return this.newEmail === this.currentEmail;
  }

  @action
  changeEmail() {
    changeEmail({
      username: this.login.loginName,
      password: this.login.loginPassword,
      email: this.newEmail,
    })
      .then(() => {
        this.modal.show(ActivationResent, {
          model: { title: "log_in", updateTopic: this.updateTopic },
        });
        const modal = this.showModal("activation-resent", {
          title: "log_in",
        });
        modal.set("currentEmail", this.newEmail);
      })
      .catch(flashAjaxError(this));
  }
}
