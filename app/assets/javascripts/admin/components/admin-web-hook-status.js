import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend({
  classes: ["text-muted", "text-danger", "text-successful", "text-muted"],
  icons: ["far-circle", "times-circle", "circle", "circle"],
  circleIcon: null,
  deliveryStatus: null,

  @discourseComputed("deliveryStatuses", "model.last_delivery_status")
  status(deliveryStatuses, lastDeliveryStatus) {
    return deliveryStatuses.find(s => s.id === lastDeliveryStatus);
  },

  @discourseComputed("status.id", "icons")
  icon(statusId, icons) {
    return icons[statusId - 1];
  },

  @discourseComputed("status.id", "classes")
  class(statusId, classes) {
    return classes[statusId - 1];
  },

  didReceiveAttrs() {
    this._super(...arguments);
    this.set(
      "circleIcon",
      iconHTML(this.icon, { class: this.class }).htmlSafe()
    );
    this.set(
      "deliveryStatus",
      I18n.t(`admin.web_hooks.delivery_status.${this.get("status.name")}`)
    );
  }
});
