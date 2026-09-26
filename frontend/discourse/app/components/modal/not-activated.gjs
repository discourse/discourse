import Component from "@glimmer/component";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import ActivationControls from "discourse/components/activation-controls";
import { service } from "discourse/lib/service";
import { resendActivationEmail } from "discourse/lib/user-activation";
import ModalService from "discourse/services/modal";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class NotActivated extends Component {
  @service(() => ModalService) modal;

  @action
  sendActivationEmail() {
    resendActivationEmail(this.args.model.currentEmail).then(() => {
      this.modal.show(() => import("./activation-resent"), {
        model: { currentEmail: this.args.model.currentEmail },
      });
    });
  }

  @action
  editActivationEmail() {
    this.modal.show(() => import("./activation-edit"), {
      model: {
        currentEmail: this.args.model.currentEmail,
        newEmail: this.args.model.currentEmail,
      },
    });
  }

  <template>
    <DModal
      class="not-activated-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "log_in"}}
    >
      <:body>
        {{trustHTML (i18n "login.not_activated" sentTo=@model.sentTo)}}
      </:body>
      <:footer>
        <ActivationControls
          @editActivationEmail={{this.editActivationEmail}}
          @sendActivationEmail={{this.sendActivationEmail}}
        />
      </:footer>
    </DModal>
  </template>
}
