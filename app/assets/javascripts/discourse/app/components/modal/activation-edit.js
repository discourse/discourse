import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";
import { changeEmail } from "discourse/lib/user-activation";
import ActivationResent from "./activation-resent";

export default class ActivationEdit extends Component {
  @service login;
  @service modal;

  @tracked newEmail = this.args.model.newEmail;
  @tracked flash;

  get submitDisabled() {
    return this.newEmail === this.args.model.currentEmail;
  }

  @action
  async changeEmail() {
    try {
      await changeEmail({
        username: this.login?.loginName,
        password: this.login?.loginPassword,
        email: this.newEmail,
      });

      this.modal.show(ActivationResent, {
        model: { currentEmail: this.newEmail },
      });
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  @action
  updateNewEmail(email) {
    this.newEmail = email;
  }
}
