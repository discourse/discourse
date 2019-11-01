import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Component.extend(
  bufferedRender({
    classes: ["text-muted", "text-danger", "text-successful", "text-muted"],
    icons: ["far-circle", "times-circle", "circle", "circle"],

    @computed("deliveryStatuses", "model.last_delivery_status")
    status(deliveryStatuses, lastDeliveryStatus) {
      return deliveryStatuses.find(s => s.id === lastDeliveryStatus);
    },

    @computed("status.id", "icons")
    icon(statusId, icons) {
      return icons[statusId - 1];
    },

    @computed("status.id", "classes")
    class(statusId, classes) {
      return classes[statusId - 1];
    },

    buildBuffer(buffer) {
      buffer.push(iconHTML(this.icon, { class: this.class }));
      buffer.push(
        I18n.t(`admin.web_hooks.delivery_status.${this.get("status.name")}`)
      );
    }
  })
);
