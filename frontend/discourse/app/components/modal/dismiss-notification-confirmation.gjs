import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";

export default class DismissNotificationConfirmation extends Component {
  @action
  dismiss() {
    this.args.model?.dismissNotifications?.();
    this.args.closeModal();
  }

  <template>
    <DModal
      class="dismiss-notification-confirmation"
      @closeModal={{@closeModal}}
      @headerClass="hidden"
    >
      <:body>
        {{@model.confirmationMessage}}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.dismiss}}
          @icon="check"
          @label="notifications.dismiss_confirmation.dismiss"
        />
        <DButton
          class="btn-default"
          @action={{@closeModal}}
          @label="notifications.dismiss_confirmation.cancel"
        />
      </:footer>
    </DModal>
  </template>
}
