import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class DismissNotificationConfirmation extends Component {
  @service modal;

  @action
  dismiss() {
    this.args.model.dismissNotifications &&
      this.args.model?.dismissNotifications();
    this.modal.close();
  }
}
