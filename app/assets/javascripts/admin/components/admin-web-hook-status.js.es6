import computed from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";

export default Ember.Component.extend(
  bufferedRender({
    classes: ["text-muted", "text-danger", "text-successful"],
    icons: ["circle-o", "times-circle", "circle"],

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
      buffer.push(iconHTML(this.get("icon"), { class: this.get("class") }));
      buffer.push(
        I18n.t(`admin.web_hooks.delivery_status.${this.get("status.name")}`)
      );
    }
  })
);
