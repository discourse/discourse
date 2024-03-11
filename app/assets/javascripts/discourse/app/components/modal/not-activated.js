import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { resendActivationEmail } from "discourse/lib/user-activation";
import ActivationEdit from "./activation-edit";
import ActivationResent from "./activation-resent";

export default class NotActivated extends Component {
  @service modal;

  @action
  sendActivationEmail() {
    resendActivationEmail(this.args.model.currentEmail).then(() => {
      this.modal.show(ActivationResent, {
        model: { currentEmail: this.args.model.currentEmail },
      });
    });
  }

  @action
  editActivationEmail() {
    this.modal.show(ActivationEdit, {
      model: {
        currentEmail: this.args.model.currentEmail,
        newEmail: this.args.model.currentEmail,
      },
    });
  }
}
