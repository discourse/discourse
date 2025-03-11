import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";

export default class DismissNotificationConfirmation extends Component {
  @action
  dismiss() {
    this.args.model?.dismissNotifications?.();
    this.args.closeModal();
  }

  <template>
    <DModal
      @headerClass="hidden"
      class="dismiss-notification-confirmation"
      @closeModal={{@closeModal}}
    >
      <:body>
        {{@model.confirmationMessage}}
      </:body>
      <:footer>
        <DButton
          @icon="check"
          class="btn-primary"
          @action={{this.dismiss}}
          @label="notifications.dismiss_confirmation.dismiss"
        />
        <DButton
          @action={{@closeModal}}
          @label="notifications.dismiss_confirmation.cancel"
          class="btn-default"
        />
      </:footer>
    </DModal>
  </template>
}
