/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ActivationEmailForm from "discourse/components/activation-email-form";
import { extractError } from "discourse/lib/ajax-error";
import { changeEmail } from "discourse/lib/user-activation";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
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
      @flash={{this.flash}}
      @title={{i18n "login.change_email"}}
    >
      <:body>
        <ActivationEmailForm
          @email={{@model.newEmail}}
          @updateNewEmail={{this.updateNewEmail}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.changeEmail}}
          @disabled={{this.submitDisabled}}
          @label="login.submit_new_email"
        />
        <DButton @action={{@closeModal}} @label="close" />
      </:footer>
    </DModal>
  </template>
}
