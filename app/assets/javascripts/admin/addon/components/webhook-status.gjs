import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class WebhookStatus extends Component {
  iconNames = ["far-circle", "circle-xmark", "circle", "circle"];
  iconClasses = ["text-muted", "text-danger", "text-successful", "text-muted"];

  get status() {
    const lastStatus = this.args.webhook.get("last_delivery_status");
    return this.args.deliveryStatuses.find((s) => s.id === lastStatus);
  }

  get deliveryStatus() {
    return i18n(`admin.web_hooks.delivery_status.${this.status.name}`);
  }

  get iconName() {
    return this.iconNames[this.status.id - 1];
  }

  get iconClass() {
    return this.iconClasses[this.status.id - 1];
  }

  <template>
    {{icon this.iconName class=this.iconClass}}
    {{this.deliveryStatus}}
  </template>
}
