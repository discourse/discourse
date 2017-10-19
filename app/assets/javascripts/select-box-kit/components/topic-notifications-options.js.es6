import NotificationOptionsComponent from "select-box-kit/components/notifications-button";
import { on } from "ember-addons/ember-computed-decorators";
import { topicLevels } from "discourse/lib/notification-levels";

export default NotificationOptionsComponent.extend({
  classNames: "topic-notifications-options",
  content: topicLevels,
  i18nPrefix: "topic.notifications",
  value: Ember.computed.alias("topic.details.notification_level"),

  @on("didInsertElement")
  _bindGlobalLevelChanged() {
    this.appEvents.on("topic-notifications-button:changed", (msg) => {
      if (msg.type === "notification") {
        if (this.get("computedValue") !== msg.id) {
          this.get("topic.details").updateNotifications(msg.id);
        }
      }
    });
  },

  @on("willDestroyElement")
  _unbindGlobalLevelChanged() {
    this.appEvents.off("topic-notifications-button:changed");
  },

  actions: {
    onSelect(value) {
      if (value !== this.get("computedValue")) {
        this.get("topic.details").updateNotifications(value);
      }

      this.set("value", value);

      this.defaultOnSelect(value);

      this.blur();
    }
  }
});
