import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ActivationEmailForm from "discourse/components/activation-email-form";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { extractError } from "discourse/lib/ajax-error";
import { changeEmail } from "discourse/lib/user-activation";
import i18n from "discourse-common/helpers/i18n";
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

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "login.change_email"}}
      @flash={{this.flash}}
    >
      <:body>
        <ActivationEmailForm
          @email={{@model.newEmail}}
          @updateNewEmail={{this.updateNewEmail}}
        />
      </:body>
      <:footer>
        <DButton
          @action={{this.changeEmail}}
          @label="login.submit_new_email"
          @disabled={{this.submitDisabled}}
          class="btn-primary"
        />
        <DButton @action={{@closeModal}} @label="close" />
      </:footer>
    </DModal>
  </template>
}
