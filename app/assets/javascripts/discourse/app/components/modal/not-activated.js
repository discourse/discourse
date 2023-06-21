import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { resendActivationEmail } from "discourse/lib/user-activation";
import ActivationResent from "./activation-resent";
import ActivationEdit from "./activation-edit";

export default class NotActivated extends Component {
  @service modal;

  @action
  sendActivationEmail() {
    resendActivationEmail(this.username).then(() => {
      this.modal.show(ActivationResent, {
        model: { currentEmail: this.currentEmail },
      });
    });
  }

  @action
  editActivationEmail() {
    this.modal.show(ActivationEdit, {
      model: { currentEmail: this.currentEmail, newEmail: this.currentEmail },
    });
  }
}
