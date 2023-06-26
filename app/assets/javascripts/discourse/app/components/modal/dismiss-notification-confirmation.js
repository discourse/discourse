import Component from "@glimmer/component";
import { inject as service } from "@ember/service";

export default class DismissNotificationConfirmation extends Component {
  @service modal;

  @action
  dismiss() {
    console.log(this.dismissNotifications);
    this.args.model?.dismissNotifications();
    this.modal.close();
  }
}
