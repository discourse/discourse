import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class WebhookStatus extends Component {
  statusClasses = ["--inactive", "--critical", "--success", "--inactive"];

  get status() {
    const lastStatus = this.args.webhook.get("last_delivery_status");
    return this.args.deliveryStatuses.find((s) => s.id === lastStatus);
  }

  get deliveryStatus() {
    return i18n(`admin.web_hooks.delivery_status.${this.status.name}`);
  }

  get statusClass() {
    return this.statusClasses[this.status.id - 1];
  }

  <template>
    <div role="status" class="status-label {{this.statusClass}}">
      <div class="status-label-indicator">
      </div>
      <div class="status-label-text">
        {{this.deliveryStatus}}
      </div>
    </div>
  </template>
}
