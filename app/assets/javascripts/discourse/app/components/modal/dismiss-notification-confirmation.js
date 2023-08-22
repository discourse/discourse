import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class DismissNotificationConfirmation extends Component {
  @action
  dismiss() {
    this.args.model?.dismissNotifications?.();
    this.args.closeModal();
  }
}
