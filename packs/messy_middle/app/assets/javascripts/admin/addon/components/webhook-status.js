import Component from "@glimmer/component";
import I18n from "I18n";

export default class WebhookStatus extends Component {
  iconNames = ["far-circle", "times-circle", "circle", "circle"];
  iconClasses = ["text-muted", "text-danger", "text-successful", "text-muted"];

  get status() {
    const lastStatus = this.args.webhook.last_delivery_status;
    return this.args.deliveryStatuses.find((s) => s.id === lastStatus);
  }

  get deliveryStatus() {
    return I18n.t(`admin.web_hooks.delivery_status.${this.status.name}`);
  }

  get iconName() {
    return this.iconNames[this.status.id - 1];
  }

  get iconClass() {
    return this.iconClasses[this.status.id - 1];
  }
}
