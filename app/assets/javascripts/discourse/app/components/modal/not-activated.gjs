import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ActivationControls from "discourse/components/activation-controls";
import DModal from "discourse/components/d-modal";
import { resendActivationEmail } from "discourse/lib/user-activation";
import { i18n } from "discourse-i18n";
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

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "log_in"}}
      class="not-activated-modal"
    >
      <:body>
        {{htmlSafe (i18n "login.not_activated" sentTo=@model.sentTo)}}
      </:body>
      <:footer>
        <ActivationControls
          @sendActivationEmail={{this.sendActivationEmail}}
          @editActivationEmail={{this.editActivationEmail}}
        />
      </:footer>
    </DModal>
  </template>
}
