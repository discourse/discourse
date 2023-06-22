import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";
import { changeEmail } from "discourse/lib/user-activation";
import { flashAjaxError } from "discourse/lib/ajax-error";
import ActivationResent from "./activation-resent";

export default class ActivationEdit extends Component {
  @service login;
  @service modal;

  @tracked newEmail = this.args.model.newEmail;

  get submitDisabled() {
    return this.newEmail === this.args.model.currentEmail;
  }

  @action
  changeEmail() {
    changeEmail({
      username: this.login?.loginName,
      password: this.login?.loginPassword,
      email: this.args.model.newEmail,
    })
      .then(() => {
        this.modal.show(ActivationResent, {
          model: { currentEmail: this.args.model.newEmail },
        });
      })
      .catch(flashAjaxError(this));
  }

  @action
  updateNewEmail(e) {
    this.newEmail = e.target.value;
  }
}
